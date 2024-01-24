// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {StageData, InitERC721Params} from "src/libraries/VaultNiftyDropStructs.sol";
import {VaultNiftyDrop} from "src/drop/VaultNiftyDrop.sol";
import {ERC721VaultNifty} from "src/tokens/ERC721VaultNifty.sol";

import {Clones} from "openzeppelin-contracts/proxy/Clones.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

contract VaultNiftyDropCloneFactory is Ownable {
    event DropDeploy(address indexed dropAddress, address indexed collectionAddress, address _owner, string symbol);
    event UpdatePlatformSetting(address platformReceiverAddress, uint256 mintFee);
    event UpdateDropImplAddress(address platformReceiverAddress);
    event UpdateTokenImplAddress(address platformReceiverAddress);

    error InvalidMintFee();

    address public dropImplAddress;
    address public tokenImplAddress;

    /// @dev platform fee recipient address
    address public platformReceiverAddress;

    // mint Platform commission fee
    uint256 public mintFee;

    constructor(address _dropImplAddress, address _tokenImplAddress, address _platformReceiverAddress, uint256 _mintFee)
        Ownable()
    {
        dropImplAddress = _dropImplAddress;
        tokenImplAddress = _tokenImplAddress;

        if (_platformReceiverAddress != address(0)) platformReceiverAddress = _platformReceiverAddress;
        if (_mintFee > 10000) revert InvalidMintFee();
        mintFee = _mintFee;
    }

    function updatePlatformSetting(address newPlatformReceiverAddress, uint256 newMintFee) external onlyOwner {
        mintFee = newMintFee;
        platformReceiverAddress = newPlatformReceiverAddress;
        emit UpdatePlatformSetting(newPlatformReceiverAddress, newMintFee);
    }

    function setDropImplAddress(address newImplAddress) external onlyOwner {
        dropImplAddress = newImplAddress;
        emit UpdateDropImplAddress(newImplAddress);
    }

    function setTokenImplAddress(address newImplAddress) external onlyOwner {
        tokenImplAddress = newImplAddress;
        emit UpdateTokenImplAddress(newImplAddress);
    }

    function createClone(
        InitERC721Params calldata init721Params,
        address primarySaleReceiver,
        address paymentTokenAddress,
        StageData[] calldata stages
    ) external returns (address, address) {
        address dropInstance = Clones.clone(dropImplAddress);
        address tokenInstance = Clones.clone(tokenImplAddress);

        ERC721VaultNifty(tokenInstance).initialize(init721Params, dropInstance);
        VaultNiftyDrop(dropInstance).initialize(
            primarySaleReceiver, platformReceiverAddress, mintFee, tokenInstance, paymentTokenAddress, stages
        );
        ERC721VaultNifty(tokenInstance).transferOwnership(msg.sender);
        VaultNiftyDrop(dropInstance).transferOwnership(msg.sender);

        emit DropDeploy(dropInstance, tokenInstance, msg.sender, init721Params.symbol);
        return (dropInstance, tokenInstance);
    }
}
