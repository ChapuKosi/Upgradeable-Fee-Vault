# Deployment Results

**Date:** February 8, 2026  
**Network:** Anvil Local (Chain ID: 31337)

## Addresses

**V1**
```
Implementation: 0x5FbDB2315678afecb367f032d93F642f64180aa3
Proxy:          0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
Owner:          0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Version:        1.0.0
```

**V2 Upgrade**
```
Implementation: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
Proxy:          0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 (unchanged)
Owner:          0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (preserved)
Version:        2.0.0
```

## Verification

- V1 version: 1.0.0 ✓
- V2 version: 2.0.0 ✓
- Owner preserved: ✓
- Withdrawal delay: 86400s ✓
- Max withdraw: 0 (unlimited) ✓
- Paused: false ✓

## Tests

All 7 tests passed:
```
testV1BasicFunctionality
testUpgradePreservesOwnership
testUpgradeAddsV2Features
testUpgradeUnauthorizedReverts
testV2PauseMechanism
testV2WithdrawalDelay
testV2WithdrawalLimit
```

## Gas Usage

### Deployment Costs
| Contract     | Gas       | Cost (1 gwei) |
## Gas Usage

| Contract     | Deployment Gas |
|--------------|----------------|
| FeeVaultV1   | 896,254        |
| FeeVaultV2   | 1,538,627      |
| ERC1967Proxy | 180,501        |

| Function | V1 Gas | V2 Gas | Change |
|----------|--------|--------|--------|
| deposit  | 41,907 | 50,523 | +20%   |
| withdraw | 38,575 | 39,742 | +3%    |

V2 adds ~8.6k gas to deposits for balance tracking, pause checks, and safety validations.

## Quick Commands

```bash
export VAULT=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
export RPC=http://127.0.0.1:8545

# Query
cast call $VAULT "version()(string)" --rpc-url $RPC
cast call $VAULT "owner()(address)" --rpc-url $RPC

# Interact (V2)
cast send $VAULT "pause()" --private-key $PRIVATE_KEY --rpc-url $RPC
```
