// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { VaultStorage } from "./VaultStorage.sol";

/// @title FeeVaultV2
/// @notice Upgradeable vault for holding protocol fees with enhanced security
/// @dev V2 adds: withdrawal delays, per-tx limits, pause mechanism, and balance tracking
/// @custom:security-contact For resume demonstration - shows upgrade-safe storage patterns
contract FeeVaultV2 is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposited(address indexed token, address indexed from, uint256 amount);
    event Withdrawn(address indexed token, address indexed to, uint256 amount);
    event WithdrawalDelayUpdated(uint256 oldDelay, uint256 newDelay);
    event MaxWithdrawUpdated(uint256 oldMax, uint256 newMax);
    event Paused(address indexed by);
    event Unpaused(address indexed by);

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize V1 - called during initial deployment
    /// @dev This function exists for compatibility but should use FeeVaultV1 for initial deploy
    function initialize(address initialOwner) external initializer {
        require(initialOwner != address(0), "FeeVault: ZERO_OWNER");

        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    /// @notice Initialize V2 features after upgrading from V1
    /// @dev Must be called via upgradeToAndCall() during V1→V2 upgrade.
    ///      Uses reinitializer(2) to ensure it only runs once.
    ///      Owner from V1 is preserved in inherited OwnableUpgradeable storage.
    /// @param _maxWithdrawPerTx Maximum withdrawal per transaction in wei (0 = unlimited)
    /// @param _withdrawalDelay Minimum seconds between withdrawals per token (0 = no delay)
    function initializeV2(
        uint256 _maxWithdrawPerTx,
        uint256 _withdrawalDelay
    ) external reinitializer(2) {
        VaultStorage.Layout storage s = VaultStorage.layout();
        
        s.maxWithdrawPerTx = _maxWithdrawPerTx;
        s.withdrawalDelay = _withdrawalDelay;
        s.paused = false;
        
        // Owner is already set from V1, preserved in OwnableUpgradeable storage
    }

    /*//////////////////////////////////////////////////////////////
                        CORE VAULT LOGIC (V2)
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit ERC20 tokens into the vault
    /// @dev Requires prior token approval. Uses SafeERC20 for non-standard tokens.
    ///      Tracks balances in diamond storage for V2 withdrawal validation.
    ///      Reverts if contract is paused.
    /// @param token The ERC20 token address to deposit (cannot be zero address)
    /// @param amount The amount of tokens to deposit (must be > 0)
    function deposit(address token, uint256 amount) external {
        VaultStorage.Layout storage s = VaultStorage.layout();
        
        require(token != address(0), "FeeVault: ZERO_TOKEN");
        require(amount > 0, "FeeVault: ZERO_AMOUNT");
        require(!s.paused, "FeeVault: PAUSED");

        // SafeERC20 handles tokens that don't return bool
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // V2: Track balance in diamond storage
        s.balances[token] += amount;

        emit Deposited(token, msg.sender, amount);
    }

    /// @notice Withdraw ERC20 tokens from the vault with V2 safety checks
    /// @dev Owner-only. Enforces withdrawal delay, per-tx limits, and pause state.
    ///      Uses CEI pattern: checks, effects (state updates), interactions (transfer).
    ///      Updates lastWithdrawAt timestamp to enforce delay on next withdrawal.
    /// @param token The ERC20 token address to withdraw (cannot be zero address)
    /// @param to The recipient address (cannot be zero address)
    /// @param amount The amount to withdraw (must be > 0 and <= balance)
    function withdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        VaultStorage.Layout storage s = VaultStorage.layout();

        require(token != address(0), "FeeVault: ZERO_TOKEN");
        require(to != address(0), "FeeVault: ZERO_TO");
        require(amount > 0, "FeeVault: ZERO_AMOUNT");
        require(!s.paused, "FeeVault: PAUSED");

        // V2 Feature: Withdrawal delay
        uint256 lastWithdraw = s.lastWithdrawAt[token];
        // Only enforce delay if there was a previous withdrawal
        if (lastWithdraw > 0) {
            require(
                block.timestamp >= lastWithdraw + s.withdrawalDelay,
                "FeeVault: WITHDRAWAL_TOO_SOON"
            );
        }

        // V2 Feature: Per-transaction limit (0 = unlimited)
        if (s.maxWithdrawPerTx > 0) {
            require(
                amount <= s.maxWithdrawPerTx,
                "FeeVault: EXCEEDS_MAX_WITHDRAW"
            );
        }

        // V2 Feature: Balance tracking
        require(
            s.balances[token] >= amount,
            "FeeVault: INSUFFICIENT_BALANCE"
        );

        // CEI pattern: Update state before external call
        s.balances[token] -= amount;
        s.lastWithdrawAt[token] = block.timestamp;

        // SafeERC20 prevents reentrancy issues
        IERC20(token).safeTransfer(to, amount);

        emit Withdrawn(token, to, amount);
    }

    /// @notice Emergency withdrawal bypassing time delay
    /// @dev Owner-only. Bypasses withdrawal delay but still respects:
    ///      - Pause state (must be unpaused)
    ///      - Per-transaction limits
    ///      - Balance validation
    ///      Use only in critical situations (security incidents, urgent moves).
    /// @param token The ERC20 token address to withdraw
    /// @param to The recipient address
    /// @param amount The amount to withdraw
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        VaultStorage.Layout storage s = VaultStorage.layout();

        require(token != address(0), "FeeVault: ZERO_TOKEN");
        require(to != address(0), "FeeVault: ZERO_TO");
        require(amount > 0, "FeeVault: ZERO_AMOUNT");
        require(!s.paused, "FeeVault: PAUSED");
        
        // Check limits
        if (s.maxWithdrawPerTx > 0) {
            require(amount <= s.maxWithdrawPerTx, "FeeVault: EXCEEDS_MAX_WITHDRAW");
        }
        
        require(s.balances[token] >= amount, "FeeVault: INSUFFICIENT_BALANCE");

        // Update state (skip delay check)
        s.balances[token] -= amount;
        s.lastWithdrawAt[token] = block.timestamp;

        IERC20(token).safeTransfer(to, amount);

        emit Withdrawn(token, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            V2 ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set withdrawal delay between withdrawals
    /// @param newDelay Delay in seconds
    function setWithdrawalDelay(uint256 newDelay) external onlyOwner {
        VaultStorage.Layout storage s = VaultStorage.layout();
        
        uint256 oldDelay = s.withdrawalDelay;
        s.withdrawalDelay = newDelay;

        emit WithdrawalDelayUpdated(oldDelay, newDelay);
    }

    /// @notice Set maximum withdrawal per transaction
    /// @param newMax Maximum amount (0 = unlimited)
    function setMaxWithdrawPerTx(uint256 newMax) external onlyOwner {
        VaultStorage.Layout storage s = VaultStorage.layout();
        
        uint256 oldMax = s.maxWithdrawPerTx;
        s.maxWithdrawPerTx = newMax;

        emit MaxWithdrawUpdated(oldMax, newMax);
    }

    /// @notice Pause deposits and withdrawals
    /// @dev Emergency circuit breaker
    function pause() external onlyOwner {
        VaultStorage.Layout storage s = VaultStorage.layout();
        require(!s.paused, "FeeVault: ALREADY_PAUSED");
        
        s.paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Unpause deposits and withdrawals
    function unpause() external onlyOwner {
        VaultStorage.Layout storage s = VaultStorage.layout();
        require(s.paused, "FeeVault: NOT_PAUSED");
        
        s.paused = false;
        emit Unpaused(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get tracked balance for a token
    function getBalance(address token) external view returns (uint256) {
        return VaultStorage.layout().balances[token];
    }

    /// @notice Get last withdrawal timestamp for a token
    function getLastWithdrawAt(address token) external view returns (uint256) {
        return VaultStorage.layout().lastWithdrawAt[token];
    }

    /// @notice Get withdrawal delay setting
    function getWithdrawalDelay() external view returns (uint256) {
        return VaultStorage.layout().withdrawalDelay;
    }

    /// @notice Get max withdrawal per transaction
    function getMaxWithdrawPerTx() external view returns (uint256) {
        return VaultStorage.layout().maxWithdrawPerTx;
    }

    /// @notice Check if contract is paused
    function isPaused() external view returns (bool) {
        return VaultStorage.layout().paused;
    }

    /// @notice Calculate when next withdrawal is available for a token
    /// @return timestamp when withdrawal becomes available
    function nextWithdrawalAvailable(address token) external view returns (uint256) {
        VaultStorage.Layout storage s = VaultStorage.layout();
        uint256 lastWithdraw = s.lastWithdrawAt[token];
        
        if (lastWithdraw == 0) {
            return block.timestamp; // Never withdrawn, available now
        }
        
        uint256 nextAvailable = lastWithdraw + s.withdrawalDelay;
        return nextAvailable > block.timestamp ? nextAvailable : block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                        UPGRADE AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize upgrade to new implementation
    /// @dev Only owner can upgrade. This is the UUPS security gate.
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
    
    /*//////////////////////////////////////////////////////////////
                        VERSION TRACKING
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Returns the version of this implementation
    /// @dev Useful for verification that upgrade succeeded
    function version() external pure returns (string memory) {
        return "2.0.0";
    }
}