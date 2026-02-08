// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title FeeVaultV1
/// @notice Upgradeable vault for holding protocol fees (ERC20)
/// @dev V1 supports deposits + immediate withdrawals by owner only
contract FeeVaultV1 is
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

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the vault with an owner
    /// @dev Replaces constructor for proxy pattern. Can only be called once.
    ///      Initializes Ownable and UUPS upgrade functionality.
    /// @param initialOwner The address that will own the vault (cannot be zero address)
    function initialize(address initialOwner) external initializer {
        require(initialOwner != address(0), "FeeVault: ZERO_OWNER");

        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    /*//////////////////////////////////////////////////////////////
                        CORE VAULT LOGIC (V1)
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit ERC20 tokens into the vault
    /// @dev Requires prior token approval. Uses SafeERC20 for non-standard tokens.
    ///      Anyone can deposit, making it suitable for protocol fee collection.
    /// @param token The ERC20 token address to deposit
    /// @param amount The amount of tokens to deposit (must be > 0)
    function deposit(address token, uint256 amount) external {
        require(token != address(0), "FeeVault: ZERO_TOKEN");
        require(amount > 0, "FeeVault: ZERO_AMOUNT");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(token, msg.sender, amount);
    }

    /// @notice Withdraw ERC20 fees from the vault
    /// @dev Owner-only with no rate limiting. Owner can withdraw any amount, any time.
    /// @param token The ERC20 token address to withdraw
    /// @param to The recipient address
    /// @param amount The amount to withdraw
    function withdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(token != address(0), "FeeVault: ZERO_TOKEN");
        require(to != address(0), "FeeVault: ZERO_TO");
        require(amount > 0, "FeeVault: ZERO_AMOUNT");

        IERC20(token).safeTransfer(to, amount);

        emit Withdrawn(token, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        UPGRADE AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function to authorize contract upgrades
    /// @dev Required by UUPS pattern. Only owner can authorize upgrades.
    ///      Override this to add custom upgrade authorization logic.
    /// @param newImplementation Address of the new implementation contract
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    /*//////////////////////////////////////////////////////////////
                        VERSION TRACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the version of this implementation
    /// @dev Useful for verification and upgrade testing
    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}

// V1 Design: Simple and Secure Access Control
// ✅ HAS: Owner-only withdrawals (access control)
// ✅ HAS: SafeERC20 (security)
// ❌ MISSING: Withdrawal delays (rate limiting)
// ❌ MISSING: Per-transaction limits (amount limiting)
// ❌ MISSING: Emergency pause mechanism
// ❌ MISSING: Balance tracking in diamond storage
// V2 will add these rate-limiting features while keeping owner-only access