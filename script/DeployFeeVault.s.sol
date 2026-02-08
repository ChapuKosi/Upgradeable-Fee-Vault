// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { FeeVaultV1 } from "../src/vault/FeeVaultV1.sol";
import { ERC1967Proxy } from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title DeployFeeVault
/// @notice Deploys FeeVaultV1 behind an ERC1967 UUPS proxy
contract DeployFeeVault is Script {
    function run() external returns (address implementationAddr, address proxyAddr) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("VAULT_OWNER");

        // Validation
        require(owner != address(0), "DeployFeeVault: ZERO_OWNER");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy implementation
        FeeVaultV1 implementation = new FeeVaultV1();

        // 2. Encode initializer call
        bytes memory initData =
            abi.encodeCall(FeeVaultV1.initialize, (owner));

        // 3. Deploy proxy pointing to implementation
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(implementation), initData);

        vm.stopBroadcast();

        // Logging
        console2.log("\n=== FeeVault V1 Deployment ===");
        console2.log("Implementation:", address(implementation));
        console2.log("Proxy (use this):", address(proxy));
        console2.log("Owner:", owner);
        console2.log("\nVerify implementation:");
        console2.log("forge verify-contract", address(implementation), "src/vault/FeeVaultV1.sol:FeeVaultV1");

        return (address(implementation), address(proxy));
    }
}
