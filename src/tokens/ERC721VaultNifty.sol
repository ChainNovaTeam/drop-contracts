// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721ContractMetadata} from "src/tokens/ERC721ContractMetadata.sol";
import {IVaultNiftyTokenContractMetadata, RoyaltyInfo} from "src/interfaces/IVaultNiftyTokenContractMetadata.sol";
import {SoulBound} from "src/libraries/SoulBound.sol";
import {InitERC721Params} from "src/libraries/VaultNiftyDropStructs.sol";
import {OperatorFilterer} from "src/filter/OperatorFilterer.sol";

import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {
    ERC721AQueryableUpgradeable,
    ERC721AUpgradeable,
    IERC721AUpgradeable
} from "ERC721A-Upgradeable/extensions/ERC721AQueryableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

contract ERC721VaultNifty is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC721ContractMetadata,
    SoulBound,
    OperatorFilterer
{
    event SetDropAddress(address drop);

    error OnlyVaultNiftyDrop();
    error ZeroAddress();
    error MintQuantityExceedsMaxSupply(uint256 total, uint256 maxSupply);

    /// @dev Whether to set the offset token URI
    bool internal _isOffsetTokenURI;

    /// @dev drop contract address
    address public drop;

    /// @dev token URI offset
    uint256 internal _randomOffset;

    modifier onlyVaultNiftyDrop() {
        if (msg.sender != drop) revert OnlyVaultNiftyDrop();
        _;
    }

    function initialize(InitERC721Params calldata initParams, address _drop) external initializer initializerERC721A {
        if (_drop == address(0)) revert ZeroAddress();
        __ReentrancyGuard_init();
        __ERC721ContractMetadata_init(initParams.name, initParams.symbol, initParams.tokenBaseURI);
        _setMaxSupply(initParams.maxSupply);
        _offsetToken(initParams.isOffsetTokenURI);
        __SoulBound_init(initParams.isSoulBound);
        _setRoyaltyInfo(
            RoyaltyInfo({royaltyAddress: initParams.royaltyAddress, royaltyBps: initParams.royaltyPercentage})
        );
        __Ownable_init();
        drop = _drop;
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
        override(ERC721ContractMetadata)
        returns (bool)
    {
        return interfaceId == type(IVaultNiftyTokenContractMetadata).interfaceId
        // ERC721ContractMetadata returns supportsInterface true for
        //     EIP-2981
        // ERC721A returns supportsInterface true for
        //     ERC165, ERC721, ERC721Metadata
        || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Overrides the `_startTokenId` function from ERC721A
     *      to start at token id `1`.
     *
     *      This is to avoid future possible problems since `0` is usually
     *      used to signal values that have not been set or have been removed.
     */
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    /**
     * @dev set tokenURI's offset
     */
    function _offsetToken(bool _applyRandomReveal) private {
        if (_applyRandomReveal) {
            _randomOffset = (block.timestamp + block.prevrandao) % maxSupply();
            _isOffsetTokenURI = true;
        } else {
            _randomOffset = 0;
            _isOffsetTokenURI = false;
        }
    }

    /**
     * @dev return The offset setting of the token URI can only be viewed by the owner
     */
    function getOffsetToken() public view returns (bool, uint256) {
        return (_isOffsetTokenURI, _randomOffset);
    }

    /**
     * @dev Overrides the `tokenURI()` function from ERC721A
     *      to return just the base URI if it is implied to not be a directory.
     *
     *      This is to help with ERC721 contracts in which the same token URI
     *      is desired for each token, such as when the tokenURI is 'unrevealed'.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(IERC721AUpgradeable, ERC721AUpgradeable)
        returns (string memory)
    {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _baseURI();

        // Exit early if the baseURI is empty.
        if (bytes(baseURI).length == 0) {
            return "";
        }

        // Check if the last character in baseURI is a slash.
        if (bytes(baseURI)[bytes(baseURI).length - 1] != bytes("/")[0]) {
            return baseURI;
        }

        if (_isOffsetTokenURI) {
            uint256 shiftedTokenId = (tokenId + _randomOffset) % maxSupply();
            return string(abi.encodePacked(baseURI, _toString(shiftedTokenId)));
        } else {
            return string(abi.encodePacked(baseURI, _toString(tokenId)));
        }
    }

    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function totalMinted() public view returns (uint256) {
        return _totalMinted();
    }

    function totalBurned() public view returns (uint256) {
        return _totalBurned();
    }

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom}
     * for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     * - The `operator` must be allowed.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved)
        public
        override(IERC721AUpgradeable, ERC721AUpgradeable)
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the
     * zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     * - The `operator` mut be allowed.
     *
     * Emits an {Approval} event.
     */
    function approve(address operator, uint256 tokenId)
        public
        payable
        override(IERC721AUpgradeable, ERC721AUpgradeable)
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     * - The operator must be allowed.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId)
        public
        payable
        override(IERC721AUpgradeable, ERC721AUpgradeable)
        onlyAllowedOperator(from)
    {
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @dev Equivalent to `safeTransferFrom(from, to, tokenId, '')`.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId)
        public
        payable
        override(IERC721AUpgradeable, ERC721AUpgradeable)
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     * - The operator must be allowed.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        payable
        override(IERC721AUpgradeable, ERC721AUpgradeable)
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function mintVaultNiftyDrop(address to, uint256 quantity) external onlyVaultNiftyDrop {
        if (_totalMinted() + quantity > maxSupply()) {
            revert MintQuantityExceedsMaxSupply(_totalMinted() + quantity, maxSupply());
        }
        _safeMint(to, quantity);
    }

    /**
     * @dev Inheriting contract is responsible for implementation
     * By default, it is the owner's permission, and the sub-contract can override it
     */
    function _isOperatorFilterAdmin(address operator) internal view virtual override returns (bool) {
        return operator == owner();
    }

    function _beforeTokenTransfers(address from, address to, uint256, uint256) internal view override {
        _limitMintForSoulBound(from, to);
    }
}
