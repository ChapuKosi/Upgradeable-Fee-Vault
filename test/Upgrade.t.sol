// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/vault/FeeVaultV1.sol";
import "../src/vault/FeeVaultV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockERC20 for testing
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 ether);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract UpgradeTest is Test {
    FeeVaultV1 vaultV1;
    FeeVaultV2 vaultV2;
    ERC1967Proxy proxy;
    MockERC20 token;

    address owner = address(0xA11CE);
    address user = address(0xBEEF);

    function setUp() public {
        // Deploy mock token
        token = new MockERC20();

        // Deploy V1 implementation
        FeeVaultV1 implementationV1 = new FeeVaultV1();

        // Encode initializer
        bytes memory initData = abi.encodeCall(FeeVaultV1.initialize, (owner));

        // Deploy proxy
        proxy = new ERC1967Proxy(address(implementationV1), initData);
        vaultV1 = FeeVaultV1(address(proxy));

        // Fund user with tokens
        token.mint(user, 1000 ether);
    }

    function testUpgradePreservesOwnership() public {
        // Verify V1 owner
        assertEq(vaultV1.owner(), owner, "V1 owner incorrect");

        // Deploy V2 implementation
        FeeVaultV2 implementationV2 = new FeeVaultV2();

        // Upgrade from V1 to V2
        vm.prank(owner);
        vaultV1.upgradeToAndCall(
            address(implementationV2), abi.encodeCall(FeeVaultV2.initializeV2, (100 ether, 1 days))
        );

        // Cast proxy to V2
        vaultV2 = FeeVaultV2(address(proxy));

        // ASSERT: Owner preserved
        assertEq(vaultV2.owner(), owner, "Owner not preserved");

        // ASSERT: Version changed
        assertEq(vaultV2.version(), "2.0.0", "Version not updated");
    }

    function testUpgradeAddsV2Features() public {
        // Deploy V2 and upgrade
        FeeVaultV2 implementationV2 = new FeeVaultV2();

        vm.prank(owner);
        vaultV1.upgradeToAndCall(
            address(implementationV2), abi.encodeCall(FeeVaultV2.initializeV2, (100 ether, 2 days))
        );

        vaultV2 = FeeVaultV2(address(proxy));

        // ASSERT: V2 features initialized
        assertEq(vaultV2.getMaxWithdrawPerTx(), 100 ether, "Max withdraw not set");
        assertEq(vaultV2.getWithdrawalDelay(), 2 days, "Delay not set");
        assertFalse(vaultV2.isPaused(), "Should not be paused");
    }

    function testV2PauseMechanism() public {
        // Upgrade to V2
        FeeVaultV2 implementationV2 = new FeeVaultV2();
        vm.prank(owner);
        vaultV1.upgradeToAndCall(address(implementationV2), abi.encodeCall(FeeVaultV2.initializeV2, (0, 0)));
        vaultV2 = FeeVaultV2(address(proxy));

        // Pause
        vm.prank(owner);
        vaultV2.pause();
        assertTrue(vaultV2.isPaused(), "Pause failed");

        // Try to deposit while paused
        vm.startPrank(user);
        token.approve(address(vaultV2), 50 ether);
        vm.expectRevert("FeeVault: PAUSED");
        vaultV2.deposit(address(token), 50 ether);
        vm.stopPrank();

        // Unpause
        vm.prank(owner);
        vaultV2.unpause();
        assertFalse(vaultV2.isPaused(), "Unpause failed");

        // Now deposit should work
        vm.startPrank(user);
        vaultV2.deposit(address(token), 50 ether);
        vm.stopPrank();

        assertEq(vaultV2.getBalance(address(token)), 50 ether, "Deposit failed");
    }

    function testV2WithdrawalDelay() public {
        // Upgrade to V2 with 1 day delay
        FeeVaultV2 implementationV2 = new FeeVaultV2();
        vm.prank(owner);
        vaultV1.upgradeToAndCall(address(implementationV2), abi.encodeCall(FeeVaultV2.initializeV2, (0, 1 days)));
        vaultV2 = FeeVaultV2(address(proxy));

        // Deposit
        vm.startPrank(user);
        token.approve(address(vaultV2), 100 ether);
        vaultV2.deposit(address(token), 100 ether);
        vm.stopPrank();

        // First withdrawal should work
        vm.prank(owner);
        vaultV2.withdraw(address(token), owner, 10 ether);

        // Second immediate withdrawal should fail
        vm.prank(owner);
        vm.expectRevert("FeeVault: WITHDRAWAL_TOO_SOON");
        vaultV2.withdraw(address(token), owner, 10 ether);

        // Advance time
        vm.warp(block.timestamp + 1 days);

        // Now should work
        vm.prank(owner);
        vaultV2.withdraw(address(token), owner, 10 ether);

        assertEq(vaultV2.getBalance(address(token)), 80 ether, "Withdrawal balance incorrect");
    }

    function testV2WithdrawalLimit() public {
        // Upgrade to V2 with 50 ether limit
        FeeVaultV2 implementationV2 = new FeeVaultV2();
        vm.prank(owner);
        vaultV1.upgradeToAndCall(address(implementationV2), abi.encodeCall(FeeVaultV2.initializeV2, (50 ether, 0)));
        vaultV2 = FeeVaultV2(address(proxy));

        // Deposit
        vm.startPrank(user);
        token.approve(address(vaultV2), 200 ether);
        vaultV2.deposit(address(token), 200 ether);
        vm.stopPrank();

        // Try to withdraw more than limit
        vm.prank(owner);
        vm.expectRevert("FeeVault: EXCEEDS_MAX_WITHDRAW");
        vaultV2.withdraw(address(token), owner, 51 ether);

        // Withdraw within limit
        vm.prank(owner);
        vaultV2.withdraw(address(token), owner, 50 ether);

        assertEq(vaultV2.getBalance(address(token)), 150 ether, "Balance incorrect");
    }

    function testUpgradeUnauthorizedReverts() public {
        FeeVaultV2 implementationV2 = new FeeVaultV2();

        // Non-owner cannot upgrade
        vm.prank(user);
        vm.expectRevert();
        vaultV1.upgradeToAndCall(address(implementationV2), abi.encodeCall(FeeVaultV2.initializeV2, (0, 0)));
    }

    function testV1BasicFunctionality() public {
        // Test V1 works before upgrade
        vm.startPrank(user);
        token.approve(address(vaultV1), 100 ether);
        vaultV1.deposit(address(token), 100 ether);
        vm.stopPrank();

        // Owner can withdraw
        uint256 balanceBefore = token.balanceOf(owner);
        vm.prank(owner);
        vaultV1.withdraw(address(token), owner, 50 ether);

        assertEq(token.balanceOf(owner) - balanceBefore, 50 ether, "Withdrawal failed");
    }
}
