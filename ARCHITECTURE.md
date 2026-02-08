# Architecture

Deep dive into the upgradeable proxy architecture, storage patterns, and security considerations.

## Why UUPS Over Transparent Proxy?

| Feature           | UUPS                       | Transparent     |
|-------------------|----------------------------|-----------------|
| Upgrade logic     | Implementation             | Proxy           |
| Gas cost per call | Lower (~2500 gas saved)    | Higher          |
| Proxy size        | Smaller                    | Larger          |
| Upgrade auth      | Custom (onlyOwner)         | Built-in admin  |
| Risk              | Must not remove upgrade fn | Admin confusion |

**Decision**: UUPS chosen for gas efficiency and flexibility. Risk mitigated by comprehensive testing.

## Upgrade Flow

```
V1 Deployment:
  Deploy FeeVaultV1 → Deploy ERC1967Proxy → Initialize
  
  User calls Proxy → delegatecall → V1 Logic

V1 to V2 Upgrade:
  Deploy FeeVaultV2 → upgradeToAndCall(V2, initializeV2)
  
  User calls Proxy → delegatecall → V2 Logic (state preserved)
```

## Storage Pattern

**Wrong Approach (Storage Collision)**
```
Slot 0: Proxy admin
Slot 1: Implementation  
Slot 2: Initializable
Slot 3: Owner
Slot 4: balances  ← V1
Slot 5: newVar    ← V2 might overwrite!
```

**Diamond Storage (Safe)**
```
Slot 0-3: Proxy & inherited contracts
...
Slot keccak256("fee.vault.storage.v1"):
  - balances (V1)
  - maxWithdrawPerTx (V2)
  - withdrawalDelay (V2)
  - paused (V2)
  - lastWithdrawAt (V2)
```

Isolated namespace prevents collisions.

## Call Flow

```
User calls withdraw()
        │
        ▼
┌─────────────────┐
│  Proxy Contract │
│  (Storage)      │
└─────────────────┘
        │ delegatecall
        ▼
┌─────────────────┐
│  FeeVaultV2     │
│  (Logic)        │
└─────────────────┘
        │
        ├─→ Check: onlyOwner ✓
        │
        ├─→ Check: !paused ✓
        │
        ├─→ Check: withdrawal delay ✓
        │
        ├─→ Check: withdrawal limit ✓
        │
        ├─→ Update: balances[token] -= amount
        │
        ├─→ Update: lastWithdrawAt[token] = now
        │
        └─→ SafeERC20.safeTransfer() 💰
```

## Call Flow

```
V2 withdraw():
  1. User → Proxy.withdraw()
  2. Proxy → delegatecall → V2.withdraw()
  3. V2 checks: paused, withdrawal delay, limits
  4. V2 updates: VaultStorage (balances, lastWithdrawAt)
  5. V2 transfers: SafeERC20.transfer()
  6. Event emitted
```

## Upgrade Checklist

Before:
- Owner address confirmed
- V1 state recorded
- V2 deployed and tested

During:
- upgradeToAndCall(v2Address, initData)
- initializeV2 sets new parameters

After:
- version() == "2.0.0"
- owner unchanged
- V1 data preserved
- V2 features working

## Security Analysis

### Attack Vectors & Mitigations

**1. Storage Collision Attack**
- **Risk**: V2 adds variable that overwrites V1 storage
- **Mitigation**: Diamond storage pattern with namespaced slot
- **Verification**: Storage layout tests, Foundry storage inspector

**2. Initialization Front-Running**
- **Risk**: Attacker calls initialize() before deployer
- **Mitigation**: `initializer` modifier (reentrancy-like protection)
- **Pattern**: Deploy + initialize in same transaction

**3. Malicious Upgrade**
- **Risk**: Compromised owner deploys malicious V2
- **Mitigation**: Multi-sig + timelock in production
- **Detection**: Upgrade event monitoring, Tenderly alerts

**4. Selector Clash**
- **Risk**: Proxy function selector matches implementation
- **Mitigation**: UUPS keeps upgrade logic in implementation
- **Note**: Transparent proxy solves this differently (routing)

**5. Delegatecall Context**
- **Risk**: Misunderstanding of `msg.sender` preservation
- **Safe**: msg.sender, msg.value preserved in delegatecall
- **Unsafe**: Storage, balance belong to proxy

### Gas Analysis

**V1 Operations**
```
deposit(): ~46,000 gas
withdraw(): ~38,000 gas
```

**V2 Operations (with checks)**
```
deposit(): ~46,000 gas (unchanged)
withdraw(): ~52,000 gas (+14k for pause/delay/limit checks)
pause(): ~28,000 gas
setWithdrawalDelay(): ~30,000 gas
```

**Upgrade Cost**
```
upgradeToAndCall(): ~1,520,000 gas
  - Deploy V2: ~1,350,000
  - upgradeToAndCall: ~120,000
  - initializeV2: ~50,000
```

### Storage Slots Deep Dive

```solidity
// ERC1967 Standard Slots
Implementation: keccak256("eip1967.proxy.implementation") - 1
Admin: keccak256("eip1967.proxy.admin") - 1

// Our Diamond Storage
VaultStorage: keccak256("fee.vault.storage.v1")
  = 0x1a2b3c...
```

**Why `-1` in ERC1967?**
- Ensures slot is not zero (gas optimization)
- Makes accidental collision nearly impossible
- Standard followed by all major proxies

### Upgrade Safety Checklist

✅ **DO**
- Keep Diamond storage slot constant
- Append new variables to struct
- Use `reinitializer(N)` for Nth upgrade
- Test upgrade on fork before mainnet
- Emit events for all state changes

❌ **DON'T**
- Change variable order in storage struct
- Remove variables (append only)
- Reuse initializer numbers
- Upgrade without testing state preservation
- Forget to increment version number

### Production Deployment Pattern

```solidity
// 1. Deploy V1 implementation
FeeVaultV1 v1 = new FeeVaultV1();

// 2. Encode initialize call
bytes memory initData = abi.encodeWithSelector(
    FeeVaultV1.initialize.selector,
    owner
);

// 3. Deploy proxy with initialization
ERC1967Proxy proxy = new ERC1967Proxy(
    address(v1),
    initData
);

// 4. Interact via proxy interface
FeeVaultV1 vault = FeeVaultV1(address(proxy));
```

## Further Reading

- [EIP-1967: Proxy Storage Slots](https://eips.ethereum.org/EIPS/eip-1967)
- [EIP-1822: UUPS](https://eips.ethereum.org/EIPS/eip-1822)
- [EIP-2535: Diamond Standard](https://eips.ethereum.org/EIPS/eip-2535)
- [OpenZeppelin Proxy Patterns](https://docs.openzeppelin.com/contracts/4.x/api/proxy)
- [Foundry Storage Layout](https://book.getfoundry.sh/reference/forge/forge-inspect)
