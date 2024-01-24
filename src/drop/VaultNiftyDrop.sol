// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC721VaultNifty} from "src/interfaces/IERC721VaultNifty.sol";
import {VaultNiftyDropErrorsAndEvents} from "src/libraries/VaultNiftyDropErrorsAndEvents.sol";
import {StageData, InitERC721Params} from "src/libraries/VaultNiftyDropStructs.sol";

import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {MerkleProof} from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

contract VaultNiftyDrop is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    VaultNiftyDropErrorsAndEvents
{
    using ECDSA for bytes32;

    // @dev stage limit
    uint128 internal constant stageLengthLimit = 20;

    // @dev Platform mint fee Basis Points
    uint128 public constant mintFeeBasisPoints = 10000;

    /// @dev EIP-712 signatures
    bytes32 constant EIP712_NAME_HASH = keccak256("VaultNifty");
    bytes32 constant EIP712_VERSION_HASH = keccak256("1.0");
    bytes32 constant EIP712_DOMAIN_TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 constant EIP712_MINT_TYPE_HASH =
        keccak256("Mint(address recipient,uint256 quantity,uint256 nonce,uint256 maxMintsPerWallet)");
    bytes32 constant EIP712_URICHANGE_TYPE_HASH = keccak256("URIChange(address sender,string newPathURI,string newURI)");

    /// @dev If the value is true, signature is required for mint
    bool public isSignature;

    /// @dev Total number of sale stages
    uint256 public totalStages;

    // mint Platform commission fee
    uint256 public mintFee;

    // mint, if `paymentTokenAddress == address(0)`, then ETH will be used for payment by default.
    address public paymentTokenAddress;

    /// @dev mint If you are signing, you need to verify the signing address
    address public signer;

    /// @dev Sale information - this tells the contract where the proceeds from the primary sale should go to
    address public primarySaleReceiver;

    /// @dev platform fee recipient address
    address public platformReceiverAddress;

    // @dev Platform reward, which can be withdrawn via `platformWithdraw`
    uint256 public platformRewards;

    // @dev collection contract
    IERC721VaultNifty public erc721VaultNifty;

    /// @dev Mapping a stage ID to its corresponding StageData struct
    mapping(uint256 => StageData) internal stageMap;

    /// @dev Mapping to keep track of the number of mints a given wallet has done on a specific stage
    mapping(uint256 => mapping(address => uint256)) public stageMints;

    /// @dev Keep track of signatures that have already been used
    mapping(bytes => bool) private usedSignatures;

    /// @dev Keep track of the total number of each stage mint
    mapping(uint256 => uint256) public stageMintTotal;

    function initialize(
        address _primarySaleReceiver,
        address _platformReceiverAddress,
        uint256 _mintFee,
        address tokenContract,
        address _paymentTokenAddress,
        StageData[] calldata stages
    ) external initializer {
        if (_primarySaleReceiver == address(0)) revert ZeroAddress();
        __Ownable_init();
        __ReentrancyGuard_init();
        erc721VaultNifty = IERC721VaultNifty(tokenContract);
        primarySaleReceiver = _primarySaleReceiver;
        mintFee = _mintFee;
        if (_platformReceiverAddress != address(0)) platformReceiverAddress = _platformReceiverAddress;
        if (_paymentTokenAddress != address(0)) paymentTokenAddress = _paymentTokenAddress;
        if (stages.length > 0) _setStages(stages, 0);
    }

    /*///////////////////////////////////////////////////////////////
                            Sale stages logic
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev View sale parameters corresponding to a given stage
     */
    function viewStageMap(uint256 stageId) external view returns (StageData memory) {
        if (stageId >= totalStages) revert StageDoesNotExist();

        return stageMap[stageId];
    }

    /**
     * @dev View the current active sale stage for a sale based on being within the
     * time bounds for the start time and end time for the considered stage
     */
    function viewCurrentStage() public view returns (uint256) {
        for (uint256 i = totalStages; i > 0;) {
            unchecked {
                --i;
            }

            if (block.timestamp >= stageMap[i].startTime && block.timestamp <= stageMap[i].endTime) {
                return i;
            }
        }

        revert SaleNotActive();
    }

    /**
     * @dev Get the price for the current active sale stage
     * reverts if there is no current active stage
     */
    function viewCurrentPrice() public view returns (uint256) {
        uint256 mintPrice = stageMap[viewCurrentStage()].price;
        uint256 price = mintPrice + mintPrice * mintFee / mintFeeBasisPoints;
        return price;
    }

    /**
     * @dev Returns the earliest stage which has not closed yet
     */
    function viewLatestStage() public view returns (uint256) {
        for (uint256 i = totalStages; i > 0;) {
            unchecked {
                --i;
            }

            if (block.timestamp > stageMap[i].endTime) {
                return i + 1;
            }
        }

        return 0;
    }

    /**
     * @dev See _setStages
     */
    function setStages(StageData[] calldata stages, uint256 startId) external onlyOwner {
        _setStages(stages, startId);
    }

    /**
     * @dev Set the parameters for a list of sale stages, starting from startId onwards
     */
    function _setStages(StageData[] calldata stages, uint256 startId) internal returns (uint256) {
        uint256 stagesLength = stages.length;

        uint256 latestStage = viewLatestStage();

        // Cannot set more than the stage length limit stages per transaction
        if (stagesLength > stageLengthLimit) revert StageLimitPerTx();

        uint256 currentTotalStages = totalStages;

        // Check that the stage the user is overriding from onwards is not a closed stage
        if (currentTotalStages > 0 && startId < latestStage) {
            revert CannotEditPastStages();
        }

        // The startId cannot be an arbitrary number, it must follow a sequential order based on the current number of stages
        if (startId > currentTotalStages) revert IncorrectIndex();

        // There can be no more than 20 sale stages (stageLengthLimit) between the most recent active stage and the last possible stage
        if (startId + stagesLength > latestStage + stageLengthLimit) {
            revert TooManyStagesInTheFuture();
        }

        uint256 initialStageStartTime = stageMap[startId].startTime;

        // In order to delete a stage, calldata of length 0 must be provided. The stage referenced by the startIndex
        // and all stages after that will no longer be considered for the drop
        if (stagesLength == 0) {
            // The stage cannot have started at any point for it to be deleted
            if (initialStageStartTime <= block.timestamp) {
                revert CannotDeleteOngoingStage();
            }

            // The new length of total stages is startId, as everything from there onwards is now disregarded
            totalStages = startId;
            emit NewStagesSet(stages, startId);
            return startId;
        }

        StageData memory newStage = stages[0];

        if (newStage.phaseLimit < erc721VaultNifty.totalMinted()) {
            revert TokenCountExceedsPhaseLimit();
        }

        if (initialStageStartTime <= block.timestamp && initialStageStartTime != 0 && startId < totalStages) {
            // If the start time of the stage being replaced is in the past and exists
            // the new stage start time must match it
            if (initialStageStartTime != newStage.startTime) {
                revert InvalidStartTime();
            }

            // The end time for a stage cannot be in the past
            if (newStage.endTime <= block.timestamp) revert EndTimeInThePast();
        } else {
            // the start time of the stage being replaced is in the future or doesn't exist
            // the new stage start time can't be in the past
            if (newStage.startTime <= block.timestamp) {
                revert StartTimeInThePast();
            }
        }

        unchecked {
            uint256 i = startId;
            uint256 stageCount = startId + stagesLength;

            do {
                if (i != startId) {
                    newStage = stages[i - startId];
                }

                // The number of tokens the user can mint up to in a stage cannot exceed the total supply available
                if (newStage.phaseLimit > erc721VaultNifty.maxSupply()) {
                    revert PhaseLimitExceedsTokenCount();
                }

                // The end time cannot be less than the start time for a sale
                if (newStage.endTime <= newStage.startTime) {
                    revert EndTimeLessThanStartTime();
                }

                if (i > 0) {
                    uint256 previousStageEndTime = stageMap[i - 1].endTime;
                    // The number of total NFTs on sale cannot decrease below the total for a stage which has not ended
                    if (newStage.phaseLimit < stageMap[i - 1].phaseLimit) {
                        if (previousStageEndTime >= block.timestamp) {
                            revert LessNFTsOnSaleThanBefore();
                        }
                    }

                    // A sale can only start after the previous one has closed
                    if (newStage.startTime <= previousStageEndTime) {
                        revert PhaseStartsBeforePriorPhaseEnd();
                    }
                }

                // Update the variables in a given stage's stageMap with the correct indexing within the stages function input
                stageMap[i] = newStage;

                ++i;
            } while (i < stageCount);

            // The total number of stages is updated to be the startId + the length of stages added from there onwards
            totalStages = stageCount;

            emit NewStagesSet(stages, startId);
            return stageCount;
        }
    }

    /*///////////////////////////////////////////////////////////////
                                Withdraw
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Set up the fee recipient for the primary minting
     */
    function setPrimarySaleReceiver(address _primarySaleReceiver) external onlyOwner {
        if (_primarySaleReceiver == address(0)) revert ZeroAddress();
        if (_primarySaleReceiver == primarySaleReceiver) revert SameAddress();
        primarySaleReceiver = _primarySaleReceiver;
        emit UpdatePrimarySaleReceiver(_primarySaleReceiver);
    }

    /**
     * @dev Withdraw creator earnings (in addition to platform earnings)
     */
    function withdraw() external payable onlyOwner nonReentrant {
        if (paymentTokenAddress == address(0)) {
            uint256 withdrawValue = address(this).balance - platformRewards;
            (bool sent,) = primarySaleReceiver.call{value: withdrawValue}("");
            if (!sent) revert ETHSendFail();
        } else {
            uint256 withdrawValue = IERC20(paymentTokenAddress).balanceOf(address(this)) - platformRewards;
            bool sent = IERC20(paymentTokenAddress).transfer(primarySaleReceiver, withdrawValue);
            if (!sent) revert ERC20SendFail();
        }
    }

    /**
     * @dev Withdraw the earnings of the platform
     */
    function platformWithdraw() external payable nonReentrant {
        if (platformReceiverAddress == address(0)) revert ZeroAddress();
        if (platformRewards == 0) revert ZeroReward();
        if (paymentTokenAddress == address(0)) {
            (bool sent_,) = platformReceiverAddress.call{value: platformRewards}("");
            if (!sent_) revert ETHSendFail();
        } else {
            uint256 balance = IERC20(paymentTokenAddress).balanceOf(address(this));
            if (balance < platformRewards) revert RewardInsufficientBalance();
            bool sent = IERC20(paymentTokenAddress).transfer(platformReceiverAddress, platformRewards);
            if (!sent) revert ERC20SendFail();
        }
    }

    /*///////////////////////////////////////////////////////////////
                        Minting + airdrop logic
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Set the signature address and whether to sign it
     */
    function setSigner(address newSigner, bool isSign) external onlyOwner {
        if (isSign && newSigner == address(0)) revert ZeroAddress();

        isSignature = isSign;
        signer = newSigner;
        emit SetSigner(newSigner, isSign);
    }

    /**
     * @dev Mint token(s) for public sales
     */
    function mint(
        uint256 nonce,
        uint256 numberOfTokens,
        address recipient,
        uint256 paymentAmount,
        bytes calldata signature
    ) external payable {
        // Check the active stage - reverts if no stage is active
        uint256 presentStage = viewCurrentStage();

        // Load the minting parameters for this stage
        StageData memory dropData = stageMap[presentStage];
        uint256 userMintedAmount = stageMints[presentStage][msg.sender];

        _checkMintQuantity(
            numberOfTokens,
            dropData.mintsPerWallet,
            20,
            erc721VaultNifty.totalMinted(),
            userMintedAmount,
            dropData.phaseLimit
        );

        // Check that enough ETH is sent for the minting quantity
        uint256 mintPrice = dropData.price;
        uint256 costPerToken = mintPrice + mintPrice * mintFee / mintFeeBasisPoints;
        _checkCorrectPayment(numberOfTokens, costPerToken, paymentAmount);

        // If a Merkle Root is defined for the stage, then this is an allowlist stage. Thus the function merkleMint
        // must be used instead
        if (dropData.merkleRoot != bytes32(0)) revert MerkleStage();

        // Nonce = 0 is reserved for airdrop mints, to distinguish them from other mints in the _mint function on ERC721
        if (nonce == 0) revert InvalidNonce();

        // signature
        _checkValidSignature(recipient, numberOfTokens, nonce, signature);
        usedSignatures[signature] = true;

        _mintAndPay(recipient, numberOfTokens, presentStage, userMintedAmount, mintPrice, costPerToken);
    }

    function mintAllowList(
        uint256 numberOfTokens,
        address recipient,
        uint256 paymentAmount,
        bytes32[] calldata _merkleProof
    ) external payable {
        // Check the active stage - reverts if no stage is active
        uint256 presentStage = viewCurrentStage();

        // Load the minting parameters for this stage
        StageData memory dropData = stageMap[presentStage];
        uint256 userMintedAmount = stageMints[presentStage][msg.sender];

        _checkMintQuantity(
            numberOfTokens,
            dropData.mintsPerWallet,
            20,
            erc721VaultNifty.totalMinted(),
            userMintedAmount,
            dropData.phaseLimit
        );

        // Check that enough ETH is sent for the minting quantity
        uint256 mintPrice = dropData.price;
        uint256 costPerToken = mintPrice + mintPrice * mintFee / mintFeeBasisPoints;
        _checkCorrectPayment(numberOfTokens, costPerToken, paymentAmount);

        // If a Merkle Root is defined for the stage, then this is an allowlist stage. Thus the function merkleMint
        // must be used instead
        if (dropData.merkleRoot == bytes32(0)) revert PublicStage();

        // Verify the Merkle Proof for the recipient address and the maximum number of mints the wallet has been assigned on the allowlist
        if (!verifyMerkleAddress(_merkleProof, dropData.merkleRoot, recipient)) {
            revert MerkleProofFail();
        }

        _mintAndPay(recipient, numberOfTokens, presentStage, userMintedAmount, mintPrice, costPerToken);
    }

    function airdropMint(address[] calldata receivers, uint256 tokenCount) external onlyOwner {
        if (receivers.length == 0) revert InvalidAirdropParams();
        if (tokenCount == 0) revert TokenLimitPerTx();
        if (receivers.length > 20 || receivers.length == 0) revert AddressLimitPerTx();

        unchecked {
            for (uint256 i; i < receivers.length;) {
                erc721VaultNifty.mintVaultNiftyDrop(receivers[i], tokenCount);
                ++i;
            }
            emit Airdrop(tokenCount, receivers);
        }
        if (erc721VaultNifty.totalMinted() > erc721VaultNifty.maxSupply()) revert ExceedMaxSupply();
    }

    function _mintAndPay(
        address recipient,
        uint256 numberOfTokens,
        uint256 presentStage,
        uint256 userMintedAmount,
        uint256 mintPrice,
        uint256 costPerToken
    ) internal nonReentrant {
        // Mint the NFTs
        erc721VaultNifty.mintVaultNiftyDrop(recipient, numberOfTokens);

        uint256 platformPrice = (mintPrice * mintFee / mintFeeBasisPoints) * numberOfTokens;

        if (platformReceiverAddress != address(0)) {
            platformRewards = platformRewards + platformPrice;
        }

        // if use erc20 payment
        if (paymentTokenAddress != address(0)) {
            bool sent =
                IERC20(paymentTokenAddress).transferFrom(msg.sender, address(this), costPerToken * numberOfTokens);
            if (!sent) revert ERC20SendFail();
        }

        stageMints[presentStage][recipient] = numberOfTokens + userMintedAmount;
        stageMintTotal[presentStage] = stageMintTotal[presentStage] + numberOfTokens;
        emit Mint(recipient, presentStage, numberOfTokens);
    }

    function _checkMintQuantity(
        uint256 quantity,
        uint256 maxPerWallet,
        uint256 maxPerTx,
        uint256 currentMintedTokens,
        uint256 userMintedAmount,
        uint256 phaseLimit
    ) internal view {
        if (quantity == 0) {
            revert MintQuantityCannotBeZero();
        }

        if (quantity + currentMintedTokens > erc721VaultNifty.maxSupply()) {
            revert ExceedMaxSupply();
        }

        if (maxPerTx > 0 && quantity > maxPerTx) {
            revert ExceedMaxPerTx();
        }

        if ((userMintedAmount + quantity) > maxPerWallet) {
            revert ExceedMaxPerWallet();
        }

        //The number of tokens minted cannot exceed the phaseLimit of the NFTs on sale at this stage
        if (currentMintedTokens >= phaseLimit) revert PhaseLimitEnd();
    }

    function _checkCorrectPayment(uint256 quantity, uint256 costPerToken, uint256 paymentAmount) internal view {
        // use eth
        if (paymentTokenAddress == address(0)) {
            if (costPerToken > 0 && msg.value < quantity * costPerToken) {
                revert NotEnoughETH();
            }
        } else {
            if (msg.value > 0) revert ShouldOnlyUseERC20();
            uint256 allowanceAmount = IERC20(paymentTokenAddress).allowance(msg.sender, address(this));
            if (allowanceAmount < paymentAmount) revert AllowanceInsufficient(allowanceAmount);
            // use erc20
            if (costPerToken > 0 && paymentAmount < quantity * costPerToken) {
                revert NotEnoughERC20();
            }
        }
    }

    function _checkValidSignature(address _recipient, uint256 _numberOfTokens, uint256 _nonce, bytes memory _signature)
        internal
        view
    {
        // If the contract is released from signature minting, skips this signature verification
        if (isSignature && signer != address(0)) {
            if (usedSignatures[_signature]) {
                revert SignatureAlreadyUsed();
            }

            // Hash the variables
            bytes32 messageHash = _hashMintParams(_recipient, _numberOfTokens, _nonce);

            // Ensure the recovered address from the signature is the Fair.xyz signer address
            if (messageHash.recover(_signature) != signer) {
                revert InvalidSignature();
            }

            // Set a time limit of 40 blocks for the signature
            if (block.number > _nonce + 40) revert TimeLimit();
        }
    }

    /**
     * @dev Hash transaction data for minting
     */
    function _hashMintParams(address recipient, uint256 quantity, uint256 nonce) private view returns (bytes32) {
        bytes32 digest = _hashTypedData(keccak256(abi.encode(EIP712_MINT_TYPE_HASH, recipient, quantity, nonce)));
        return digest;
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     */
    function _hashTypedData(bytes32 structHash) internal view virtual returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(EIP712_DOMAIN_TYPE_HASH, EIP712_NAME_HASH, EIP712_VERSION_HASH, block.chainid, address(this))
        );

        return ECDSA.toTypedDataHash(domainSeparator, structHash);
    }

    /**
     * @notice Verify merkle proof for address and address minting limit
     */
    function verifyMerkleAddress(bytes32[] calldata merkleProof, bytes32 _merkleRoot, address minterAddress)
        private
        pure
        returns (bool)
    {
        return
            MerkleProof.verify(merkleProof, _merkleRoot, keccak256(bytes.concat(keccak256(abi.encode(minterAddress)))));
    }
}
