# Upgradeable Fee Vault

[![CI](https://github.com/ChapuKosi/Upgradeable-Fee-Vault/actions/workflows/test.yml/badge.svg)](https://github.com/ChapuKosi/Upgradeable-Fee-Vault/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.30-blue.svg)](https://docs.soliditylang.org)

UUPS upgradeable smart contract using namespaced storage layout for safe state preservation across upgrades.

## Overview

This project demonstrates upgrading smart contract logic while preserving state. An ERC20 fee vault is deployed as V1 with basic deposit/withdraw functionality, then upgraded to V2 which adds withdrawal delays, pause functionality, and per-transaction limits.

### Technical Objectives

This implementation demonstrates:

- **UUPS Proxy Mechanics**: Upgrade authorization in implementation contract using ERC1967 standard
- **Explicit Storage Layout Management**: Namespaced storage slot (`keccak256("fee.vault.storage.v1")`) prevents collisions across upgrades
- **Safe Upgrade Authorization**: Owner-only upgrade function with OpenZeppelin's `UUPSUpgradeable`
- **State Continuity**: V2 does not reorder or remove existing storage fields; it strictly appends new fields to preserve slot alignment
- **Initialization Patterns**: Separate initializers for each version (`initializer`, `reinitializer(2)`)
- **Testing Upgrade Lifecycle**: 7 tests covering deployment, upgrade, authorization, and state preservation

**Note**: This uses namespaced storage slots, not the EIP-2535 Diamond Standard (which involves multiple facets).

## Architecture

**V1 - Basic Vault**
- Public deposits (any ERC20)
- Owner-only withdrawals
- No rate limiting

**V2 - Enhanced Security**
- Withdrawal delays (configurable)
- Per-transaction limits
- Pause mechanism
- Balance tracking in namespaced storage
- All V1 state preserved

## Key Implementation Details

### 1. UUPS Proxy Pattern
- Upgrade logic resides in implementation contract
- Uses ERC1967 storage slots for proxy metadata
- Authorization via `_authorizeUpgrade()` override

### 2. Namespaced Storage Layout
```solidity
library VaultStorage {
    bytes32 constant STORAGE_SLOT = keccak256("fee.vault.storage.v1");
    
    struct Layout {
        // V1 fields
        mapping(address => uint256) balances;
        
        // V2 fields (appended)
        uint256 maxWithdrawPerTx;
        uint256 withdrawalDelay;
        bool paused;
        mapping(address => uint256) lastWithdrawAt;
    }
}
```

Explicit storage slot placement prevents collisions with proxy metadata and inherited contract storage.

### 3. Version-Specific Initialization
```solidity
function initialize(address owner) external initializer { }
function initializeV2(uint256 limit, uint256 delay) external reinitializer(2) { }
```

- Proxies cannot use constructors
- `initializer` modifier prevents re-initialization of V1
- `reinitializer(2)` allows V2 migration once

### 4. SafeERC20 for Token Operations
- Handles non-standard ERC20 implementations
- Wraps transfer calls to prevent silent failures

---

## Upgrade Scenario Demonstrated

The test suite (`test/Upgrade.t.sol`) demonstrates the following upgrade flow:

1. **Deploy V1**: Implementation and proxy deployed, proxy initialized with owner
2. **User Deposits**: ERC20 tokens deposited into vault via proxy
3. **Upgrade to V2**: Owner calls `upgradeToAndCall()` with V2 implementation and initialization data
4. **State Continuity Verified**: Balances and owner address unchanged after upgrade
5. **New Restrictions Enforced**: V2 pause and withdrawal delay mechanisms functional
6. **Unauthorized Upgrade Fails**: Non-owner cannot upgrade proxy

All upgrade lifecycle tests pass, validating state continuity and access control enforcement.

## Project Structure

```
src/
  mocks/
    MockERC20.sol        # Test token
  vault/
    FeeVaultV1.sol       # V1 implementation
    FeeVaultV2.sol       # V2 implementation
    VaultStorage.sol     # Storage library

script/
  DeployFeeVault.s.sol   # Deploy V1
  UpgradeToV2.s.sol      # Upgrade to V2

test/
  Upgrade.t.sol          # 7 upgrade tests
```

## Setup

```bash
forge install
forge build
forge test -vv
```

## Tests

7 tests covering V1 functionality, upgrade mechanics, and V2 features:
- Basic V1 operations (deposit/withdraw)
- Ownership preservation across upgrade
- V2 initialization
- Pause mechanism
- Withdrawal delays and limits
- Unauthorized upgrade rejection

## Deployment

**Local (Anvil)**
```bash
# Terminal 1
anvil

# Terminal 2
PRIVATE_KEY=0x... VAULT_OWNER=0x... \
  forge script script/DeployFeeVault.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

PRIVATE_KEY=0x... VAULT_PROXY=0x... \
  forge script script/UpgradeToV2.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

**Testnet**
```bash
forge script script/DeployFeeVault.s.sol --rpc-url $RPC_URL --broadcast --verify
```

## Security Considerations

**Implemented**
- SafeERC20 for token transfers (handles non-standard ERC20s)
- CEI pattern in withdraw functions
- Owner-only upgrades via `_authorizeUpgrade()` override
- Namespaced storage prevents collisions with proxy storage
- Input validation on external functions
- OpenZeppelin audited contracts (`UUPSUpgradeable`, `OwnableUpgradeable`)

**Not Implemented (Production Requirements)**
- Timelock on upgrades (allows community review)
- Multi-signature ownership
- Comprehensive event emission
- Formal verification or third-party audit

**Known Limitations**
- No explicit reentrancy guard (relies on CEI pattern)
- Single owner (centralization risk)
- No upgrade delay mechanism

## Threat Model Considerations

Key attack vectors considered in this implementation:

- **Malicious upgrade attempt**: Mitigated by `onlyOwner` modifier on `_authorizeUpgrade()`
- **Storage collision during upgrade**: Prevented by namespaced storage slot (isolated from proxy metadata)
- **Bypass of withdrawal limits after upgrade**: V2 initialization enforces limits; tests verify enforcement
- **Improper initialization ordering**: `reinitializer(2)` ensures V2 init runs exactly once after V1
- **Front-running initialization**: Initializer modifiers prevent re-initialization attacks

## Future Improvements

- [ ] Comprehensive event emission for all state changes
- [ ] Role-based access control (RBAC) via `AccessControlUpgradeable`
- [ ] Per-user withdrawal limits (not just per-transaction)
- [ ] Time-weighted average limits
- [ ] Timelock for upgrades
- [ ] Multi-signature ownership

## Tech Stack

- Solidity 0.8.30
- Foundry
- OpenZeppelin Upgradeable Contracts
- ERC1967 Proxy

## Disclaimer

This is a portfolio demonstration project. Not audited. Not intended for production use with real funds.

## License

MIT

## Contact

**GitHub**: [github.com/ChapuKosi](https://github.com/ChapuKosi)  
**Email**: bhanujangid0212@gmail.com
