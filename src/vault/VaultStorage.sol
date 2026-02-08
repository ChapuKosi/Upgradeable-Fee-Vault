// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title VaultStorage
/// @notice Diamond storage library for FeeVault upgradeable contracts
/// @dev Uses namespaced storage pattern to prevent storage collisions during upgrades.
///      Storage slot is calculated as keccak256("fee.vault.storage.v1") to ensure
///      isolation from proxy and inherited contract storage.
library VaultStorage {
    /// @notice Storage slot for vault data, calculated via keccak256
    bytes32 internal constant STORAGE_SLOT = keccak256("fee.vault.storage.v1");

    /// @notice Main storage structure for vault state
    /// @dev Fields are append-only: V1 fields first, V2 fields appended.
    ///      Never reorder or remove fields to maintain upgrade safety.
    struct Layout {
        // V1
        address owner;
        mapping(address => uint256) balances;

        // V2 (append only)
        uint256 maxWithdrawPerTx;
        uint256 withdrawalDelay;
        bool paused;
        mapping(address => uint256) lastWithdrawAt;
    }

    /// @notice Returns storage pointer to the vault's diamond storage
    /// @dev Uses inline assembly to set storage pointer to the deterministic slot.
    ///      This function is gas-efficient and ensures consistent storage location.
    /// @return l Storage pointer to Layout struct at the diamond storage slot
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

// Diamond Storage Pattern for Upgradeable Contracts
// All variables live at a consistent, hash-derived location that won't
// conflict with proxy storage or other contracts.
// This enables safe upgrades: V2 appends to V1 structure without collisions.
