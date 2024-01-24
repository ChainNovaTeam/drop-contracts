// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {MerkleProof} from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";

contract MerkleTreeUtil {
    function verifyMerkle(bytes32[] memory merkleProof, bytes32 _merkleRoot, address minterAddress)
        internal
        pure
        returns (bool)
    {
        return MerkleProof.verify(merkleProof, _merkleRoot, keccak256(abi.encode(minterAddress)));
    }
}
