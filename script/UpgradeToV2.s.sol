// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { FeeVaultV1 } from "../src/vault/FeeVaultV1.sol";
import { FeeVaultV2 } from "../src/vault/FeeVaultV2.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title UpgradeToV2
/// @notice Upgrades an existing FeeVaultV1 proxy to FeeVaultV2
/// @dev Demonstrates UUPS upgrade process with state preservation
contract UpgradeToV2 is Script {
    function run() external returns (address newImplementation) {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("VAULT_PROXY");
        
        // V2 configuration
        uint256 maxWithdrawPerTx = vm.envOr("MAX_WITHDRAW_PER_TX", uint256(0)); // 0 = unlimited
        uint256 withdrawalDelay = vm.envOr("WITHDRAWAL_DELAY", uint256(1 days));

        // Validation
        require(proxyAddress != address(0), "UpgradeToV2: ZERO_PROXY");

        console2.log("\n=== FeeVault V1 -> V2 Upgrade ===");
        console2.log("Proxy address:", proxyAddress);
        
        // Verify current version
        FeeVaultV1 currentVault = FeeVaultV1(proxyAddress);
        string memory currentVersion = currentVault.version();
        console2.log("Current version:", currentVersion);
        require(
            keccak256(bytes(currentVersion)) == keccak256(bytes("1.0.0")),
            "Not V1"
        );

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy V2 implementation
        FeeVaultV2 implementationV2 = new FeeVaultV2();
        console2.log("V2 Implementation deployed:", address(implementationV2));

        // 2. Encode initializeV2 call
        bytes memory initV2Data = abi.encodeCall(
            FeeVaultV2.initializeV2,
            (maxWithdrawPerTx, withdrawalDelay)
        );

        // 3. Upgrade and initialize V2
        currentVault.upgradeToAndCall(address(implementationV2), initV2Data);

        vm.stopBroadcast();

        // 4. Verify upgrade
        FeeVaultV2 upgradedVault = FeeVaultV2(proxyAddress);
        string memory newVersion = upgradedVault.version();
        
        console2.log("\n=== Upgrade Successful ===");
        console2.log("New version:", newVersion);
        console2.log("Max withdraw per tx:", upgradedVault.getMaxWithdrawPerTx());
        console2.log("Withdrawal delay:", upgradedVault.getWithdrawalDelay());
        console2.log("Is paused:", upgradedVault.isPaused());
        
        console2.log("\nVerify V2 implementation:");
        console2.log("forge verify-contract", address(implementationV2), "src/vault/FeeVaultV2.sol:FeeVaultV2");

        return address(implementationV2);
    }
}
