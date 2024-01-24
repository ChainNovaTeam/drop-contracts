// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IVaultNiftyTokenContractMetadata, RoyaltyInfo} from "src/interfaces/IVaultNiftyTokenContractMetadata.sol";
import {ERC721ContractMetadataStorage} from "src/libraries/ERC721ContractMetadataStorage.sol";
import {ERC721ContractMetadataStorage} from "src/libraries/ERC721ContractMetadataStorage.sol";

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    ERC721AQueryableUpgradeable,
    ERC721AUpgradeable,
    IERC721AUpgradeable
} from "ERC721A-Upgradeable/extensions/ERC721AQueryableUpgradeable.sol";
import {IERC2981} from "openzeppelin-contracts/interfaces/IERC2981.sol";
import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";

/**
 * @title  ERC721ContractMetadataUpgradeable
 * @notice ERC721ContractMetadataUpgradeable is a token contract that extends ERC721A
 *         with additional metadata and ownership capabilities.
 */
contract ERC721ContractMetadata is OwnableUpgradeable, ERC721AQueryableUpgradeable, IVaultNiftyTokenContractMetadata {
    using ERC721ContractMetadataStorage for ERC721ContractMetadataStorage.Layout;

    /**
     * @notice Deploy the token contract with its name and symbol.
     */
    function __ERC721ContractMetadata_init(string memory name, string memory symbol, string memory tokenBaseURI)
        internal
        onlyInitializing
    {
        __Ownable_init();
        __ERC721A_init(name, symbol);
        __ERC721ContractMetadata_init_unchained(name, symbol, tokenBaseURI);
    }

    function __ERC721ContractMetadata_init_unchained(string memory, string memory, string memory tokenBaseURI)
        internal
        onlyInitializing
    {
        if (bytes(tokenBaseURI).length != 0) {
            ERC721ContractMetadataStorage.layout()._tokenBaseURI = tokenBaseURI;
        }
    }

    /**
     * @notice Sets the base URI for the token metadata and emits an event.
     *
     * @param newBaseURI The new base URI to set.
     */
    function setBaseURI(string calldata newBaseURI) external override onlyOwner {
        if (bytes(newBaseURI).length == 0) {}

        // Set the new base URI.
        ERC721ContractMetadataStorage.layout()._tokenBaseURI = newBaseURI;

        // Emit an event with the update.
        if (totalSupply() != 0) {
            emit BatchMetadataUpdate(1, _nextTokenId() - 1);
        }
    }

    /**
     * @notice Sets the contract URI for contract metadata.
     *
     * @param newContractURI The new contract URI.
     */
    function setContractURI(string calldata newContractURI) external override onlyOwner {
        // Set the new contract URI.
        ERC721ContractMetadataStorage.layout()._contractURI = newContractURI;

        // Emit an event with the update.
        emit ContractURIUpdated(newContractURI);
    }

    /**
     * @notice Emit an event notifying metadata updates for
     *         a range of token ids, according to EIP-4906.
     *
     * @param fromTokenId The start token id.
     * @param toTokenId   The end token id.
     */
    function emitBatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId) external onlyOwner {
        // Emit an event with the update.
        emit BatchMetadataUpdate(fromTokenId, toTokenId);
    }

    /**
     * @notice Sets the max token supply and emits an event.
     *
     * @param newMaxSupply The new max supply to set.
     */
    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {
        _setMaxSupply(newMaxSupply);
    }

    function _setMaxSupply(uint256 newMaxSupply) internal {
        // Ensure the max supply does not exceed the maximum value of uint64.
        if (newMaxSupply > 2 ** 64 - 1) {
            revert CannotExceedMaxSupplyOfUint64(newMaxSupply);
        }

        // Set the new max supply.
        ERC721ContractMetadataStorage.layout()._maxSupply = newMaxSupply;

        // Emit an event with the update.
        emit MaxSupplyUpdated(newMaxSupply);
    }

    /**
     * @notice Sets the provenance hash and emits an event.
     *
     *         The provenance hash is used for random reveals, which
     *         is a hash of the ordered metadata to show it has not been
     *         modified after mint has started.
     *
     *         This function will revert after the first item has been minted.
     *
     * @param newProvenanceHash The new provenance hash to set.
     */
    function setProvenanceHash(bytes32 newProvenanceHash) external onlyOwner {
        // Revert if any items have been minted.
        if (_totalMinted() > 0) {
            revert ProvenanceHashCannotBeSetAfterMintStarted();
        }

        // Keep track of the old provenance hash for emitting with the event.
        bytes32 oldProvenanceHash = ERC721ContractMetadataStorage.layout()._provenanceHash;

        // Set the new provenance hash.
        ERC721ContractMetadataStorage.layout()._provenanceHash = newProvenanceHash;

        // Emit an event with the update.
        emit ProvenanceHashUpdated(oldProvenanceHash, newProvenanceHash);
    }

    /**
     * @notice Sets the address and basis points for royalties.
     *
     * @param newInfo The struct to configure royalties.
     */
    function setRoyaltyInfo(RoyaltyInfo calldata newInfo) external onlyOwner {
        _setRoyaltyInfo(newInfo);
    }

    function _setRoyaltyInfo(RoyaltyInfo memory newInfo) internal {
        // Revert if the new royalty address is the zero address.
        if (newInfo.royaltyAddress == address(0)) {
            revert RoyaltyAddressCannotBeZeroAddress();
        }

        // Revert if the new basis points is greater than 10_000.
        if (newInfo.royaltyBps > 10_000) {
            revert InvalidRoyaltyBasisPoints(newInfo.royaltyBps);
        }

        // Set the new royalty info.
        ERC721ContractMetadataStorage.layout()._royaltyInfo = newInfo;

        // Emit an event with the updated params.
        emit RoyaltyInfoUpdated(newInfo.royaltyAddress, newInfo.royaltyBps);
    }

    /**
     * @notice Returns the base URI for token metadata.
     */
    function baseURI() external view override returns (string memory) {
        return _baseURI();
    }

    /**
     * @notice Returns the base URI for the contract, which ERC721A uses
     *         to return tokenURI.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return ERC721ContractMetadataStorage.layout()._tokenBaseURI;
    }

    /**
     * @notice Returns the contract URI for contract metadata.
     */
    function contractURI() external view override returns (string memory) {
        return ERC721ContractMetadataStorage.layout()._contractURI;
    }

    /**
     * @notice Returns the max token supply.
     */
    function maxSupply() public view returns (uint256) {
        return ERC721ContractMetadataStorage.layout()._maxSupply;
    }

    /**
     * @notice Returns the provenance hash.
     *         The provenance hash is used for random reveals, which
     *         is a hash of the ordered metadata to show it is unmodified
     *         after mint has started.
     */
    function provenanceHash() external view override returns (bytes32) {
        return ERC721ContractMetadataStorage.layout()._provenanceHash;
    }

    /**
     * @notice Returns the address that receives royalties.
     */
    function royaltyAddress() external view returns (address) {
        return ERC721ContractMetadataStorage.layout()._royaltyInfo.royaltyAddress;
    }

    /**
     * @notice Returns the royalty basis points out of 10_000.
     */
    function royaltyBasisPoints() external view returns (uint256) {
        return ERC721ContractMetadataStorage.layout()._royaltyInfo.royaltyBps;
    }

    /**
     * @notice Called with the sale price to determine how much royalty
     *         is owed and to whom.
     *
     * @ param  _tokenId     The NFT asset queried for royalty information.
     * @param  _salePrice    The sale price of the NFT asset specified by
     *                       _tokenId.
     *
     * @return receiver      Address of who should be sent the royalty payment.
     * @return royaltyAmount The royalty payment amount for _salePrice.
     */
    function royaltyInfo(uint256, /* _tokenId */ uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        // Put the royalty info on the stack for more efficient access.
        RoyaltyInfo storage info = ERC721ContractMetadataStorage.layout()._royaltyInfo;

        // Set the royalty amount to the sale price times the royalty basis
        // points divided by 10_000.
        royaltyAmount = (_salePrice * info.royaltyBps) / 10_000;

        // Set the receiver of the royalty.
        receiver = info.royaltyAddress;
    }

    /**
     * @notice Returns whether the interface is supported.
     *
     * @param interfaceId The interface id to check against.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC721AUpgradeable, IERC721AUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId || interfaceId == 0x49064906 // ERC-4906
            || super.supportsInterface(interfaceId);
    }
}
