// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC721} from "openzeppelin-contracts/interfaces/IERC721.sol";

/**
 * @title  TestTransferNFT
 * @notice Test contract to test transfer NFT
 */
contract TestTransferNFT {
    error NotApprove();

    function transferNFT(address nftContract, uint256 tokenId, address to) external {
        address approveAddress = IERC721(nftContract).getApproved(tokenId);
        if (approveAddress != address(this)) revert NotApprove();

        IERC721(nftContract).transferFrom(msg.sender, to, tokenId);
    }
}
