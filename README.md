# Upgradeable Fee Vault

[![CI](https://github.com/ChapuKosi/Upgradeable-Fee-Vault/actions/workflows/test.yml/badge.svg)](https://github.com/ChapuKosi/Upgradeable-Fee-Vault/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.30-blue.svg)](https://docs.soliditylang.org)

UUPS upgradeable smart contract with Diamond storage pattern for safe state preservation across upgrades.

## Overview

An ERC20 fee vault that demonstrates production-ready upgrade patterns. The contract starts simple (V1) with basic deposit/withdraw, then upgrades to V2 adding withdrawal delays, pause functionality, and per-transaction limits - all while preserving existing state.

### Why This Matters

Smart contracts are immutable, but requirements change. This project solves a real problem: how to upgrade contract logic without losing user funds or state. Used in production DeFi protocols managing millions in TVL (Uniswap, Aave, Compound all use upgradeable patterns).

### Skills Demonstrated

- **Proxy Patterns**: UUPS implementation with ERC1967 storage slots
- **Storage Management**: Diamond storage pattern preventing collisions
- **Security**: CEI pattern, reentrancy protection, access control
- **Testing**: 7 comprehensive tests covering upgrade lifecycle
- **Gas Optimization**: UUPS vs transparent proxy (saves ~2500 gas per call)
- **Best Practices**: OpenZeppelin standards, SafeERC20, initializers

### What's Included

- UUPS proxy pattern implementation
- Diamond storage for collision-free upgrades
- Comprehensive test suite (7 tests)
- Deployment scripts for V1 and V2
- Full upgrade lifecycle demonstration

## Architecture

## Architecture

**V1 - Basic Vault**
- Public deposits (any ERC20)
- Owner-only withdrawals
- No rate limiting

**V2 - Enhanced Security**
- Withdrawal delays (configurable per token)
- Per-transaction limits
- Pause mechanism
- Balance tracking in Diamond storage
- All V1 state preserved

## Key Patterns

**UUPS Proxy**
- Upgrade logic in implementation
- Gas efficient vs transparent proxy
- Owner-only authorization
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

- Prevents storage collisions
- Allows safe upgrades
- V2 appends to V1 structure

### 3. Proper Initialization
```solidity
function initialize(address owner) external initializer { }
function initializeV2(uint256 limit, uint256 delay) external reinitializer(2) { }
```

- No constructors (proxy pattern)
- `initializer` prevents re-initialization
- `reinitializer(2)` for V2 migration

### 4. SafeERC20
- Handles non-standard tokens
- Prevents return value issues
- Industry best practice

---

## Project Structure

```
src/
  mocks/
    MockERC20.sol        # Test token
  vault/
    FeeVaultV1.sol       # V1 implementation
    FeeVaultV2.sol       # V2 with Diamond storage
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
- SafeERC20 for all token transfers (handles non-standard tokens)
- CEI pattern in withdraw functions (reentrancy prevention)
- Owner-only upgrades via UUPS authorization
- No storage collisions (Diamond pattern with namespaced slots)
- Input validation on all external functions
- OpenZeppelin battle-tested contracts

**Production Recommendations**
- Add timelock for upgrade delays (community review period)
- Multi-sig ownership (prevent single point of failure)
- Formal audit (Certora, Trail of Bits, OpenZeppelin)
- Bug bounty program
- Emergency pause mechanism with governance

## Gas Optimization

- **UUPS over Transparent Proxy**: Saves ~2500 gas per delegatecall
- **Diamond Storage**: Single SLOAD for entire struct vs multiple slots
- **SafeERC20**: Only when needed, normal ERC20s use standard interface
- **Storage Packing**: Could pack `bool paused` with `uint96 delay` (future optimization)

## Future Improvements

- [ ] Add events for all state changes (better indexing)
- [ ] Implement EIP-2535 (full Diamond pattern with facets)
- [ ] Add role-based access control (RBAC)
- [ ] Per-user withdrawal limits (not just per-tx)
- [ ] Time-weighted average limits (prevent gaming delays)
- [ ] Emergency withdrawal with governance vote

## Tech Stack

- Solidity 0.8.30
- Foundry
- OpenZeppelin Upgradeable Contracts
- ERC1967 Proxy

## License

MIT

## 📫 Contact & Portfolio

**Built by**: [Bhanu Jangid]  
**GitHub**: [github.com/ChapuKosi](https://github.com/ChapuKosi)  
**Email**: bhanujangid0212@gmail.com


## ⚠️ Disclaimer

This project is a portfolio demonstration of smart contract development skills. It is not audited and is not intended for production deployment with real funds.

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
