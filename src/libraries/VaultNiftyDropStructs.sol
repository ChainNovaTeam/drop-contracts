// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @dev Tightly pack the parameters that define a sale stage
struct StageData {
    uint40 startTime;
    uint40 endTime;
    uint32 mintsPerWallet;
    uint32 phaseLimit;
    uint112 price;
    bytes32 merkleRoot;
}

struct InitERC721Params {
    string name;
    string symbol;
    uint256 maxSupply;
    string tokenBaseURI;
    address royaltyAddress;
    uint96 royaltyPercentage;
    bool isOffsetTokenURI;
    bool isSoulBound;
}
