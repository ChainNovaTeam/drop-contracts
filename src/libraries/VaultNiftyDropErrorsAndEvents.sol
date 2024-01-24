// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {StageData} from "src/libraries/VaultNiftyDropStructs.sol";

contract VaultNiftyDropErrorsAndEvents {
    event Airdrop(uint256 tokenCount, address[] recipients);
    event SetSigner(address signer, bool isSign);
    event Mint(address minterAddress, uint256 stage, uint256 mintCount);
    event NewStagesSet(StageData[] stages, uint256 startIndex);
    event UpdatePrimarySaleReceiver(address primarySaleReceiver);

    error ZeroAddress();
    error SameAddress();
    error ZeroReward();
    error TokenLimitPerTx();
    error AddressLimitPerTx();
    error CannotDeleteOngoingStage();
    error CannotEditPastStages();
    error ETHSendFail();
    error ERC20SendFail();
    error RewardInsufficientBalance();
    error EndTimeInThePast();
    error EndTimeLessThanStartTime();
    error IncorrectIndex();
    error InvalidNonce();
    error InvalidStartTime();
    error LessNFTsOnSaleThanBefore();
    error MerkleProofFail();
    error MerkleStage();
    error NotEnoughETH();
    error NotEnoughERC20();
    error ShouldOnlyUseERC20();
    error AllowanceInsufficient(uint256 allowanceAmount);
    error PhaseLimitEnd();
    error PhaseLimitExceedsTokenCount();
    error PhaseStartsBeforePriorPhaseEnd();
    error PublicStage();
    error SaleNotActive();
    error StageDoesNotExist();
    error StageLimitPerTx();
    error StartTimeInThePast();
    error TimeLimit();
    error TokenCountExceedsPhaseLimit();
    error TooManyStagesInTheFuture();
    error InvalidAirdropParams();
    error MintQuantityCannotBeZero();
    error ExceedMaxSupply();
    error ExceedMaxPerTx();
    error ExceedMaxPerWallet();
    error SignatureAlreadyUsed();
    error InvalidSignature();
}
