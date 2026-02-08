# Foundry Deployment Guide

## Quick Start

```bash
# Terminal 1
anvil

# Terminal 2 - Deploy V1
PRIVATE_KEY=0x... VAULT_OWNER=0x... \
forge script script/DeployFeeVault.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

# Upgrade to V2
PRIVATE_KEY=0x... VAULT_PROXY=0xe7f17... \
forge script script/UpgradeToV2.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

## Testing

```bash
# Run all tests
forge test -vv

# Specific tests
forge test --match-test testUpgrade -vvv

# Gas report
forge test --gas-report

# Coverage
forge coverage
```

## Local Deployment

### Step 1: Start Anvil

```bash
anvil
```

Gives you 10 funded accounts. Copy the first private key.

### Step 2: Set Environment Variables

```bash
# In a new terminal
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export RPC_URL=http://127.0.0.1:8545
### Step 2: Set Environment

```bash
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export RPC_URL=http://127.0.0.1:8545
export VAULT_OWNER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```

### Step 3: Deploy V1

```bash
forge script script/DeployFeeVault.s.sol --rpc-url $RPC_URL --broadcast
```

Save the proxy address from output.

### Step 4: Verify V1

```bash
export VAULT_PROXY=0xe7f17...  # from deploy output
cast call $VAULT_PROXY "version()(string)" --rpc-url $RPC_URL
cast call $VAULT_PROXY "owner()(address)" --rpc-url $RPC_URL
```

### Step 5: Upgrade to V2

```bash
forge script script/UpgradeToV2.s.sol --rpc-url $RPC_URL --broadcast
```

### Step 6: Verify V2

```bash
cast call $VAULT_PROXY "version()(string)" --rpc-url $RPC_URL
cast call $VAULT_PROXY "getWithdrawalDelay()(uint256)" --rpc-url $RPC_URL
```

## Testnet Deployment

```bash
# Get Sepolia ETH from faucet
export SEPOLIA_RPC_URL=https://eth-sepolia...
export PRIVATE_KEY=your_key
export ETHERSCAN_API_KEY=your_api_key

# Deploy with verification
forge script script/DeployFeeVault.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

## Useful Commands
  --broadcast \
  --verify
```

---

## 🔍 Verification

## Useful Commands

```bash
# Query state
cast call $VAULT_PROXY "version()(string)" --rpc-url $RPC_URL
cast call $VAULT_PROXY "owner()(address)" --rpc-url $RPC_URL

# Pause/unpause (V2 only)
cast send $VAULT_PROXY "pause()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL
cast send $VAULT_PROXY "unpause()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# Test specific functions
forge test --match-test testUpgrade -vvv
forge test --match-test testV2 -vvv

# Gas analysis
forge test --gas-report
forge snapshot
```

## Troubleshooting

**Insufficient funds**: Check balance with `cast balance $ADDRESS --rpc-url $RPC_URL`

**Nonce issues**: Restart Anvil with `pkill -9 anvil && anvil`

**Contract not found**: Verify deployment with `-vvv` flag for full output
