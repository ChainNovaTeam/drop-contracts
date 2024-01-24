// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract SoulBound is Initializable {
    error TokenIsSoulBound();

    /// @dev Whether it's soul bound mode or not
    bool public isSoulBound;

    /// @dev Once isSoulBound is initialized, it cannot be changed
    function __SoulBound_init(bool _isSoulBound) internal onlyInitializing {
        isSoulBound = _isSoulBound;
    }

    /**
     * @dev Toggle the soul bound state for NFTs in the contract.
     * The child contract needs to override the `_beforeTokenTransfers` method of the parent contract and call the `_limitMintForSoulBound`.
     *
     * eg：
     *      function _beforeTokenTransfers(address from, address to, uint256, uint256)
     *         internal
     *         view
     *         override
     *     {
     *         _limitMintForSoulBound(from, to);
     *     }
     */
    function _limitMintForSoulBound(address from, address to) internal view {
        if (from != address(0) && to != address(0)) {
            if (isSoulBound) revert TokenIsSoulBound();
        }
    }
}
