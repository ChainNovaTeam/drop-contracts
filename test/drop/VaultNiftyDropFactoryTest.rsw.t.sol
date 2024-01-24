// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721VaultNifty} from "src/tokens/ERC721VaultNifty.sol";
import {VaultNiftyDrop} from "src/drop/VaultNiftyDrop.sol";
import {VaultNiftyDropCloneFactory} from "src/drop/VaultNiftyDropCloneFactory.sol";
import {StageData, InitERC721Params} from "src/libraries/VaultNiftyDropStructs.sol";

import "forge-std/Test.sol";
import {UpgradeableBeacon} from "openzeppelin-contracts/proxy/beacon/UpgradeableBeacon.sol";

// forge test --match-path  test/drop/VaultNiftyDropFactoryTest.rsw.sol
contract VaultNiftyDropFactoryTest is Test {
    VaultNiftyDropCloneFactory public factory;
    VaultNiftyDrop public dropImpl;
    ERC721VaultNifty public erc721Impl;

    address public constant owner = address(1);
    uint128 public constant MAX_TOKEN = 10000;
    uint96 public constant RoyaltyPercentage = 200;
    uint256 public constant mintFee = 200;

    address public constant PrimarySaleReceiver = address(11);
    address public constant RoyaltyReceiver = address(12);
    address public constant PlatformReceiverAddress = address(13);

    function setUp() public {
        dropImpl = new VaultNiftyDrop();
        erc721Impl = new ERC721VaultNifty();
        factory =
            new VaultNiftyDropCloneFactory(address(dropImpl), address(erc721Impl), PlatformReceiverAddress, mintFee);
    }

    // forge test -vvvv --match-test testCreateVaultNiftyDropContract
    function testCreateVaultNiftyDropContract() public {
        InitERC721Params memory erc721Params = InitERC721Params({
            name: "VaultNiftyDrop",
            symbol: "VND",
            maxSupply: MAX_TOKEN,
            isOffsetTokenURI: true,
            tokenBaseURI: "https://vaultnifty.com/token/",
            royaltyAddress: RoyaltyReceiver,
            royaltyPercentage: RoyaltyPercentage,
            isSoulBound: false
        });

        StageData[] memory stages = new StageData[](2);
        StageData memory preStage = StageData({
            startTime: 100,
            endTime: 200,
            mintsPerWallet: 3,
            phaseLimit: 100,
            price: 1 ether,
            merkleRoot: bytes32(0)
        });
        StageData memory publicStage = StageData({
            startTime: 300,
            endTime: 1000,
            mintsPerWallet: 10,
            phaseLimit: uint32(MAX_TOKEN),
            price: 1e17 wei,
            merkleRoot: bytes32(0)
        });
        stages[0] = preStage;
        stages[1] = publicStage;

        (address vaultDropAddress, address collectionAddress) =
            factory.createClone(erc721Params, PrimarySaleReceiver, address(0), stages);
        console.log("vaultDropAddress:", vaultDropAddress);
        console.log("collectionAddress:", collectionAddress);
    }
}
