# Architecture

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
