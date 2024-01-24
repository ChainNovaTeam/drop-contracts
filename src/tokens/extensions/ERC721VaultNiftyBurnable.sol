// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721VaultNifty} from "src/tokens/ERC721VaultNifty.sol";

contract ERC721VaultNiftyBurnable is ERC721VaultNifty {
    event BurnableSet(bool burnState);

    error BurningOff();
    error BurnerIsNotApproved();

    /// @dev Burnable token bool
    bool public burnable;

    /// @dev Once isSoulBound is initialized, it cannot be changed
    function __ERC721VaultNiftyBurnable_init(bool burnable_) internal onlyInitializing {
        __ERC721VaultNiftyBurnable_init_unchained(burnable_);
    }

    function __ERC721VaultNiftyBurnable_init_unchained(bool burnable_) internal onlyInitializing {
        burnable = burnable_;
    }

    /**
     * @dev Toggle the burn state for NFTs in the contract
     */
    function toggleBurnable() external onlyOwner {
        burnable = !burnable;
        emit BurnableSet(burnable);
    }

    /**
     * @dev Burn a token. Requires being an approved operator or the owner of an NFT
     */
    function burn(uint256 tokenId) external returns (uint256) {
        if (!burnable) revert BurningOff();
        if (
            !(
                isApprovedForAll(ownerOf(tokenId), msg.sender) || msg.sender == ownerOf(tokenId)
                    || getApproved(tokenId) == msg.sender
            )
        ) revert BurnerIsNotApproved();
        _burn(tokenId);
        return tokenId;
    }
}
