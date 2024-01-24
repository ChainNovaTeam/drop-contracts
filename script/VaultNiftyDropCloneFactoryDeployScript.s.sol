// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/utils/DeployProxy.sol";
import {VaultNiftyDrop} from "src/drop/VaultNiftyDrop.sol";
import {VaultNiftyDropCloneFactory} from "src/drop/VaultNiftyDropCloneFactory.sol";
import {ERC721VaultNifty} from "src/tokens/ERC721VaultNifty.sol";
import {StageData, InitERC721Params} from "src/libraries/VaultNiftyDropStructs.sol";
import {TestERC20} from "src/test/TestERC20.sol";

import "forge-std/Script.sol";
import "forge-std/console.sol";

// forge script script/VaultNiftyDropCloneFactoryDeployScript.s.sol:DeployScript  --rpc-url $url --broadcast --verify --retries 10 --delay 30
contract DeployScript is Script {
    VaultNiftyDropCloneFactory private vaultNiftyDropFactory;
    /// @dev platform fee recipient address
    address public platformReceiverAddress = address(0);

    // mint Platform commission fee
    uint256 public mintFee = 0;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        VaultNiftyDrop dropImpl = new VaultNiftyDrop();
        ERC721VaultNifty tokenImpl = new ERC721VaultNifty();
        address dropImplAddress = address(dropImpl);
        address tokenImplAddress = address(tokenImpl);

        vaultNiftyDropFactory =
            new VaultNiftyDropCloneFactory(dropImplAddress, tokenImplAddress, platformReceiverAddress, mintFee);
        console.log("dropImplAddress:", address(dropImplAddress));
        console.log("tokenImplAddress:", address(tokenImplAddress));
        console.log("vaultNiftyDropFactory:", address(vaultNiftyDropFactory));

        vm.stopBroadcast();
    }
}

// forge script script/VaultNiftyDropCloneFactoryDeployScript.s.sol:FactoryCreateCollectionScript  --rpc-url $url --broadcast --verify --retries 10 --delay 30
contract FactoryCreateCollectionScript is Script {
    VaultNiftyDropCloneFactory private vaultNiftyDropFactory;

    address public constant owner = 0x892e7c8C5E716e17891ABf9395a0de1f2fc84786;

    uint128 public constant MAX_TOKEN = 10000;
    uint96 public constant RoyaltyPercentage = 200;

    address public constant PrimarySaleReceiver = 0x892e7c8C5E716e17891ABf9395a0de1f2fc84786;
    address public constant RoyaltyReceiver = 0x892e7c8C5E716e17891ABf9395a0de1f2fc84786;

    function setUp() public {
        // modify for address
        vaultNiftyDropFactory = VaultNiftyDropCloneFactory(0x5eAd2372fc25b48cc25087a8eFa29C20A03605D6);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // params
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

        StageData[] memory stages = new StageData[](1);
        StageData memory publicStage = StageData({
            startTime: 1705979400,
            endTime: 1804956449,
            mintsPerWallet: 10,
            phaseLimit: 10000,
            price: 1e16,
            merkleRoot: bytes32(0)
        });
        stages[0] = publicStage;

        (address vaultDropAddress, address collectionAddress) =
            vaultNiftyDropFactory.createClone(erc721Params, PrimarySaleReceiver, address(0), stages);
        console.log("vaultDropProxyAddress:", vaultDropAddress);
        console.log("collectionProxyAddress:", collectionAddress);

        vm.stopBroadcast();
    }
}

// forge script script/VaultNiftyDropCloneFactoryDeployScript.s.sol:MintScript  --rpc-url $url --broadcast --verify --retries 10 --delay 30
contract MintScript is Script {
    // 空签名
    bytes public emptySignature;
    uint256 numberOfTokens =3;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        VaultNiftyDrop dropProxy = VaultNiftyDrop(0x9308bd695c230c9e1Aa0dD4c3B4182648E8bcAa4);

        dropProxy.mint{value: dropProxy.viewCurrentPrice() * numberOfTokens}(
            block.number + 2,
            numberOfTokens,
            0x892e7c8C5E716e17891ABf9395a0de1f2fc84786,
            0,
            emptySignature
        );

        vm.stopBroadcast();
    }
}
