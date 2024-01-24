// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VaultNiftyDrop} from "src/drop/VaultNiftyDrop.sol";
import {ERC721VaultNifty} from "src/tokens/ERC721VaultNifty.sol";
import {StageData, InitERC721Params} from "src/libraries/VaultNiftyDropStructs.sol";
import {TestERC20} from "src/test/TestERC20.sol";

import "forge-std/Test.sol";

// forge test --match-path  test/drop/VaultNiftyDropTest.rsw.sol
contract VaultNiftyDropPaymentTokenAddressTest is Test {
    VaultNiftyDrop private vaultNiftyDrop;
    ERC721VaultNifty private erc721VaultNifty;

    TestERC20 private testERC20;

    // 空签名
    bytes public emptySignature;

    // ----- drop constant ------
    uint128 public constant MAX_TOKEN = 10000;
    uint96 public constant RoyaltyPercentage = 200;

    // ----- definition address ------
    address public constant PrimarySaleReceiver = address(11);
    address public constant RoyaltyReceiver = address(12);
    address public constant PlatformReceiverAddress = address(13);
    uint256 public constant mintFee = 200;

    address public constant owner = address(1);

    function initVaultNiftyDrop() public {
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

        vaultNiftyDrop = new VaultNiftyDrop();
        erc721VaultNifty = new ERC721VaultNifty();
        testERC20 = new TestERC20("test ERC20", "TEST");

        vm.prank(owner);
        erc721VaultNifty.initialize(erc721Params, address(vaultNiftyDrop));
        vm.prank(owner);
        vaultNiftyDrop.initialize(
            PrimarySaleReceiver, PlatformReceiverAddress, mintFee, address(erc721VaultNifty), address(testERC20), stages
        );
    }

    function setUp() public {
        vm.warp(50);
        initVaultNiftyDrop();
    }

    // forge test -vvvv --match-test testMintByPaymentTokenAddress
    function testMintByPaymentTokenAddress() public {
        // 增加区块时间为100，使 stage 0 活跃
        vm.warp(100);

        // 接收地址
        address recip = address(200);
        uint256 mintPrice = vaultNiftyDrop.viewCurrentPrice();
        assertEq(recip.balance, 0);
        assertEq(mintPrice, 1.02 ether);

        // mint 两个nft
        // 给 recip 地址mint PaymentToken
        vm.prank(owner);
        testERC20.mint(recip, 10e18);

        vm.prank(recip);
        testERC20.approve(address(vaultNiftyDrop), 2 * mintPrice);

        vm.prank(recip);
        vaultNiftyDrop.mint(101, 2, recip, 2 * mintPrice, emptySignature);
        assertEq(erc721VaultNifty.numberMinted(recip), 2);
        assertEq(erc721VaultNifty.totalMinted(), 2);

        assertEq(testERC20.balanceOf(recip), 10e18 - 2 * mintPrice);
        assertEq(2, vaultNiftyDrop.stageMintTotal(vaultNiftyDrop.viewCurrentStage()));

        vm.prank(owner);
        (, uint256 offset) = erc721VaultNifty.getOffsetToken();
        assertEq(offset, 50);

        // offset 50
        assertEq(erc721VaultNifty.tokenURI(1), "https://vaultnifty.com/token/51");
        assertEq(erc721VaultNifty.tokenURI(2), "https://vaultnifty.com/token/52");

        vm.prank(owner);
        vaultNiftyDrop.withdraw();
        assertEq(testERC20.balanceOf(address(vaultNiftyDrop)), vaultNiftyDrop.platformRewards());

        uint256 platformRewards = vaultNiftyDrop.platformRewards();
        vaultNiftyDrop.platformWithdraw();
        assertEq(testERC20.balanceOf(vaultNiftyDrop.platformReceiverAddress()), platformRewards);
        assertEq(testERC20.balanceOf(address(vaultNiftyDrop)), 0);
    }
}
