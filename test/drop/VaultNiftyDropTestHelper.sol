// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {MerkleProof} from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";

contract VaultNiftyDropTestHelper is Test {
    address constant DEFAULT_OPERATOR_FILTER_REGISTRY = 0x000000000000AAeB6D7670E522A718067333cd4E;
    address constant DEFAULT_OPERATOR_FILTER_SUBSCRIPTION = 0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6;

    /// @dev EIP-712 signatures
    bytes32 constant EIP712_NAME_HASH = keccak256("VaultNifty");
    bytes32 constant EIP712_VERSION_HASH = keccak256("1.0");
    bytes32 constant EIP712_DOMAIN_TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 constant EIP712_MINT_TYPE_HASH =
        keccak256("Mint(address recipient,uint256 quantity,uint256 nonce,uint256 maxMintsPerWallet)");
    bytes32 constant EIP712_URICHANGE_TYPE_HASH = keccak256("URIChange(address sender,string newPathURI,string newURI)");

    /**
     * @dev Hash transaction data for minting
     */
    function _hashMintParams(address recipient, uint256 quantity, uint256 nonce, address vaultDropAddress)
        internal
        view
        returns (bytes32)
    {
        bytes32 digest =
            _hashTypedData(keccak256(abi.encode(EIP712_MINT_TYPE_HASH, recipient, quantity, nonce)), vaultDropAddress);
        return digest;
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     */
    function _hashTypedData(bytes32 structHash, address vaultDropAddress) internal view virtual returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(EIP712_DOMAIN_TYPE_HASH, EIP712_NAME_HASH, EIP712_VERSION_HASH, block.chainid, vaultDropAddress)
        );

        return ECDSA.toTypedDataHash(domainSeparator, structHash);
    }

    function verifyMerkleAddress(bytes32[] memory merkleProof, bytes32 _merkleRoot, address minterAddress)
        internal
        pure
        returns (bool)
    {
        return
            MerkleProof.verify(merkleProof, _merkleRoot, keccak256(bytes.concat(keccak256(abi.encode(minterAddress)))));
    }
}
