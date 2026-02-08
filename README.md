# Upgradeable Fee Vault

UUPS upgradeable smart contract with Diamond storage pattern for safe state preservation across upgrades.

## Overview

An ERC20 fee vault that demonstrates production-ready upgrade patterns. The contract starts simple (V1) with basic deposit/withdraw, then upgrades to V2 adding withdrawal delays, pause functionality, and per-transaction limits - all while preserving existing state.

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

## Security Notes

- SafeERC20 for all token transfers
- CEI pattern in withdraw functions  
- Owner-only upgrades via UUPS
- No storage collisions (Diamond pattern)
- Input validation on all external functions

For production: add timelock, multisig, and formal audit.

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
