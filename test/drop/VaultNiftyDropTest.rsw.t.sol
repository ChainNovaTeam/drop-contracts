// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VaultNiftyDrop} from "src/drop/VaultNiftyDrop.sol";
import {OperatorFilterRegistry} from "src/filter/OperatorFilterRegistry.sol";
import {ERC721VaultNifty} from "src/tokens/ERC721VaultNifty.sol";
import {StageData, InitERC721Params} from "src/libraries/VaultNiftyDropStructs.sol";
import {TestTransferNFT} from "src/test/TestTransferNFT.sol";
import {VaultNiftyDropTestHelper} from "test/drop/VaultNiftyDropTestHelper.sol";

import "forge-std/Test.sol";

// forge test --match-path  test/drop/VaultNiftyDropTest.rsw.sol
contract VaultNiftyDropTest is Test, VaultNiftyDropTestHelper {
    VaultNiftyDrop private vaultNiftyDrop;
    ERC721VaultNifty private erc721VaultNifty;
    OperatorFilterRegistry private operatorFilterRegistry;

    TestTransferNFT private testTransferNFT;

    // 空签名
    bytes public emptySignature;

    // ----- drop constant ------
    uint128 public constant MAX_TOKEN = 10000;
    uint96 public constant RoyaltyPercentage = 200;

    address private Signer;
    uint256 private SignerPK;

    // ----- definition address ------
    address public constant PrimarySaleReceiver = address(11);
    address public constant RoyaltyReceiver = address(12);
    address public constant PlatformReceiverAddress = address(13);
    uint256 public constant mintFee = 200;

    address public constant owner = address(1);
    // address 101-110
    address[] public allowAddress = new address[](10);
    // address 111-120
    address[] public blackAddress = new address[](10);

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

        vm.prank(owner);
        erc721VaultNifty.initialize(erc721Params, address(vaultNiftyDrop));
        vm.prank(owner);
        vaultNiftyDrop.initialize(
            PrimarySaleReceiver, PlatformReceiverAddress, mintFee, address(erc721VaultNifty), address(0), stages
        );

        for (uint160 i = 101; i <= 110; i++) {
            allowAddress[i - 101] = address(i);
        }

        // init signer
        (Signer, SignerPK) = makeAddrAndKey("signer");
    }

    function initOperatorFilterRegistry() public {
        vm.prank(owner);
        operatorFilterRegistry = new OperatorFilterRegistry();

        vm.prank(owner);
        erc721VaultNifty.updateOperatorFilterRegistry(address(operatorFilterRegistry), address(0), false);

        // vaultNiftyDrop 添加黑名单地址
        for (uint160 i = 111; i <= 120; i++) {
            blackAddress[i - 111] = address(i);
        }

        // 开启filter功能
        vm.prank(owner);
        erc721VaultNifty.toggleOperatorFilterEnabled();

        vm.prank(owner);
        operatorFilterRegistry.updateOperators(address(erc721VaultNifty), blackAddress, true);
        vm.prank(owner);
        operatorFilterRegistry.updateOperator(address(erc721VaultNifty), address(testTransferNFT), true);
    }

    function setUp() public {
        vm.prank(owner);
        testTransferNFT = new TestTransferNFT();
        vm.warp(50);
        initVaultNiftyDrop();
        initOperatorFilterRegistry();
    }

    // forge test -vvvv --match-test testERC721ContractMetadata
    function testERC721ContractMetadata() public {
        // test token uri
        vm.expectRevert(abi.encodeWithSignature("URIQueryForNonexistentToken()"));
        erc721VaultNifty.tokenURI(0);

        vm.prank(owner);
        (, uint256 offset) = erc721VaultNifty.getOffsetToken();
        assertEq(offset, 50);

        assertEq(erc721VaultNifty.name(), "VaultNiftyDrop");
        assertEq(erc721VaultNifty.symbol(), "VND");
        assertEq(erc721VaultNifty.baseURI(), "https://vaultnifty.com/token/");
        assertEq(erc721VaultNifty.maxSupply(), MAX_TOKEN);
        assertEq(erc721VaultNifty.totalSupply(), 0);
        assertEq(erc721VaultNifty.royaltyAddress(), RoyaltyReceiver);
        assertEq(erc721VaultNifty.royaltyBasisPoints(), RoyaltyPercentage);
        assertEq(erc721VaultNifty.isSoulBound(), false);

        // test RoyaltyAmount
        (, uint256 royaltyAmount) = erc721VaultNifty.royaltyInfo(0, 1 ether);
        assertEq(royaltyAmount, 2e16);

        vm.prank(owner);
        erc721VaultNifty.setContractURI("https://vaultnifty.com");
        assertEq(erc721VaultNifty.contractURI(), "https://vaultnifty.com");
    }

    // forge test -vvvv --match-test testQueryNonexistentToken
    function testQueryNonexistentToken() public {
        vm.expectRevert(abi.encodeWithSignature("URIQueryForNonexistentToken()"));
        console.log(erc721VaultNifty.tokenURI(1));
    }

    /*///////////////////////////////////////////////////////////////
                            stage test
    //////////////////////////////////////////////////////////////*/

    // forge test -vvvv --match-test testViewStage
    function testViewStage() public {
        StageData memory stage0 = vaultNiftyDrop.viewStageMap(0);
        assertEq(stage0.startTime, 100);
        assertEq(stage0.endTime, 200);
        assertEq(stage0.mintsPerWallet, 3);
        assertEq(stage0.phaseLimit, 100);
        assertEq(stage0.price, 1 ether);
        assertEq(stage0.merkleRoot, bytes32(0));

        StageData memory stage1 = vaultNiftyDrop.viewStageMap(1);
        assertEq(stage1.startTime, 300);
        assertEq(stage1.endTime, 1000);
        assertEq(stage1.mintsPerWallet, 10);
        assertEq(stage1.phaseLimit, MAX_TOKEN);
        assertEq(stage1.price, 1e17 wei);
        assertEq(stage1.merkleRoot, bytes32(0));
    }

    // forge test -vvvv --match-test testStageOffset
    // 随着区块时间的增加，测试销售阶段变化
    function testStageOffset() public {
        // 默认的区块高度为0，第一个销售阶段为100，所以没有活跃的销售阶段
        vm.expectRevert(abi.encodeWithSignature("SaleNotActive()"));
        vaultNiftyDrop.viewCurrentStage();
        vm.expectRevert(abi.encodeWithSignature("SaleNotActive()"));
        vaultNiftyDrop.viewCurrentPrice();
        uint256 initLatestStage = vaultNiftyDrop.viewLatestStage();
        assertEq(initLatestStage, 0);

        // 增加区块时间为100，应当为 stage 0 活跃
        vm.warp(100);
        assertEq(block.timestamp, 100);
        assertEq(vaultNiftyDrop.viewCurrentStage(), 0);
        assertEq(vaultNiftyDrop.viewCurrentPrice(), 1.02 ether);
        assertEq(vaultNiftyDrop.viewLatestStage(), 0);

        // 增加区块时间为300，应当为 stage 1 活跃
        vm.warp(300);
        assertEq(block.timestamp, 300);
        assertEq(vaultNiftyDrop.viewCurrentStage(), 1);
        assertEq(vaultNiftyDrop.viewLatestStage(), 1);

        // 增加区块时间为2e10，超出 stage 1，没有活跃的销售阶段
        vm.warp(1001);
        assertEq(block.timestamp, 1001);
        vm.expectRevert(abi.encodeWithSignature("SaleNotActive()"));
        assertEq(vaultNiftyDrop.viewCurrentStage(), 0);
        vm.expectRevert(abi.encodeWithSignature("SaleNotActive()"));
        assertEq(vaultNiftyDrop.viewCurrentPrice(), 0);
        assertEq(vaultNiftyDrop.viewLatestStage(), 2);
    }

    // forge test -vvvv --match-test testSetStage
    function testSetStage() public {
        // 增加销售阶段 stage2
        StageData memory stage2 = StageData({
            startTime: 1001,
            endTime: 2e10,
            mintsPerWallet: 1000,
            phaseLimit: uint32(MAX_TOKEN),
            price: 0,
            merkleRoot: bytes32(0)
        });

        StageData[] memory addStages = new StageData[](1);
        addStages[0] = stage2;
        uint256 addStageIndex = 2;

        vm.prank(owner);
        vaultNiftyDrop.setStages(addStages, addStageIndex);

        // 查看 stage2
        // 增加区块时间为1e10+1，应当为 stage 2 活跃
        vm.warp(1001);
        assertEq(vaultNiftyDrop.viewCurrentStage(), 2);
        assertEq(vaultNiftyDrop.viewCurrentPrice(), 0);
        assertEq(vaultNiftyDrop.viewLatestStage(), 2);

        // 删除 stage2 不允许 删除活跃的销售阶段
        StageData[] memory delStages = new StageData[](0);
        uint256 delStageIndex = 2;

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("CannotDeleteOngoingStage()"));
        vaultNiftyDrop.setStages(delStages, delStageIndex);

        // 新增 stage3 为了测试
        StageData memory stage3 = StageData({
            startTime: 2e10 + 1,
            endTime: 3e10,
            mintsPerWallet: 1000,
            phaseLimit: uint32(MAX_TOKEN),
            price: 0,
            merkleRoot: bytes32(0)
        });
        StageData[] memory addStages3 = new StageData[](1);
        addStages3[0] = stage3;
        uint256 addStageIndex3 = 3;
        vm.prank(owner);
        vaultNiftyDrop.setStages(addStages3, addStageIndex3);
        // 新增后，最后阶段应为2 活跃阶段为2
        assertEq(vaultNiftyDrop.viewCurrentStage(), 2);
        assertEq(vaultNiftyDrop.viewCurrentPrice(), 0);
        assertEq(vaultNiftyDrop.viewLatestStage(), 2);
        // 查看 stage3
        StageData memory queryStage3 = vaultNiftyDrop.viewStageMap(3);
        assertEq(queryStage3.startTime, 2e10 + 1);
        assertEq(queryStage3.endTime, 3e10);
        assertEq(queryStage3.mintsPerWallet, 1000);

        uint256 delStageIndex3 = 3;
        vm.prank(owner);
        vaultNiftyDrop.setStages(delStages, delStageIndex3);

        // 删除后，最后阶段应为2 活跃阶段为2
        assertEq(vaultNiftyDrop.viewCurrentStage(), 2);
        assertEq(vaultNiftyDrop.viewCurrentPrice(), 0);
        assertEq(vaultNiftyDrop.viewLatestStage(), 2);
    }

    /*///////////////////////////////////////////////////////////////
                        Minting + airdrop test
    //////////////////////////////////////////////////////////////*/

    // forge test -vvvv --match-test testLogAllowList
    function testLogAllowList() public view {
        for (uint160 i = 0; i < allowAddress.length; i++) {
            console.logBytes32(keccak256(abi.encodePacked(allowAddress[i])));
        }
    }

    // forge test -vvvv --match-test testMerkleVerify
    // merkleRoot 生成参看：script/hardhat/VaultNiftyDropMerkleTree.ts
    function testMerkleVerify() public {
        bytes32 root = 0x7753ee10f91c40a4e2f0dcc8dc0bcc074a24ca8df608e50407af203b2b45befb;
        bytes32[] memory proof = new bytes32[](4);
        proof[0] = 0x0023f9f5bc869f8a01704930a5f32546cd410a1b423c29d8c67c83157f056d0d;
        proof[1] = 0x0149ef5591f2fdbbbe593f83970032c7624147c4b8221be345d66e248e439609;
        proof[2] = 0xeff6b3cec91dd677a36ea0563574ac79c0c1fea09bcbcc6289d893fc8e701a1e;
        proof[3] = 0xfb3c5a06a36e971b3f23ca37824439ce241afea1f132ccd6a79acb754c0af82b;

        address minterAddress = address(101);

        for (uint160 i = 0; i < proof.length; i++) {
            console.logBytes32(proof[i]);
        }
        console.log(verifyMerkleAddress(proof, root, minterAddress));
        assertTrue(verifyMerkleAddress(proof, root, minterAddress));
    }

    // forge test -vvvv --match-test testMintQuantityError
    function testMintQuantityError() public {
        // 增加区块时间为100，使 stage 0 活跃
        vm.warp(100);

        // 接收地址
        address recip = address(200);
        vm.deal(recip, 100 ether);
        uint256 mintPrice = vaultNiftyDrop.viewCurrentPrice();
        assertEq(mintPrice, 1.02 ether);

        // 超出销售阶段的每个钱包的数量限制
        StageData memory stage = vaultNiftyDrop.viewStageMap(0);
        assertEq(stage.mintsPerWallet, 3);

        uint256 mintCount = 4;
        uint256 nonce = 101;
        vm.prank(recip);
        vm.expectRevert(abi.encodeWithSignature("ExceedMaxPerWallet()"));
        vaultNiftyDrop.mint{value: mintCount * mintPrice}(nonce, mintCount, recip, 0, emptySignature);
    }

    // forge test -vvvv --match-test testMintWithoutSign
    function testMintWithoutSign() public {
        // 增加区块时间为100，使 stage 0 活跃
        vm.warp(100);

        // 接收地址
        address recip = address(200);
        uint256 mintPrice = vaultNiftyDrop.viewCurrentPrice();
        assertEq(recip.balance, 0);
        assertEq(mintPrice, 1.02 ether);

        // mint 两个nft
        vm.deal(recip, 3 ether);
        vm.prank(recip);
        vaultNiftyDrop.mint{value: 2 * mintPrice}(101, 2, recip, 0, emptySignature);
        assertEq(erc721VaultNifty.numberMinted(recip), 2);
        assertEq(erc721VaultNifty.totalMinted(), 2);
        assertEq(recip.balance, 3 ether - 2 * mintPrice);
        assertEq(2, vaultNiftyDrop.stageMintTotal(vaultNiftyDrop.viewCurrentStage()));

        vm.prank(owner);
        (, uint256 offset) = erc721VaultNifty.getOffsetToken();
        assertEq(offset, 50);

        // offset 50
        assertEq(erc721VaultNifty.tokenURI(1), "https://vaultnifty.com/token/51");
        assertEq(erc721VaultNifty.tokenURI(2), "https://vaultnifty.com/token/52");
    }

    // forge test -vvvv --match-test testMintWithSign
    function testMintWithSign() public {
        // 设置需要签名
        vm.prank(owner);
        vaultNiftyDrop.setSigner(Signer, true);

        // 增加区块时间为100，使 stage 0 活跃
        vm.warp(100);

        uint256 nonce = 101;
        uint256 count = 2;
        address recip = address(200);
        uint256 mintPrice = vaultNiftyDrop.viewCurrentPrice();
        vm.deal(recip, 3 ether);

        // 构造签名
        bytes32 digest = _hashMintParams(recip, count, nonce, address(vaultNiftyDrop));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SignerPK, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(recip);
        vaultNiftyDrop.mint{value: count * mintPrice}(nonce, count, recip, 0, signature);
        assertEq(erc721VaultNifty.numberMinted(recip), count);
        assertEq(erc721VaultNifty.totalMinted(), count);
        assertEq(recip.balance, 3 ether - count * mintPrice);
        assertEq(count, vaultNiftyDrop.stageMintTotal(vaultNiftyDrop.viewCurrentStage()));
    }

    // forge test -vvvv --match-test testMintAllowList
    function testMintAllowList() public {
        // 增加一个带有 merkle root 的销售阶段
        assertEq(vaultNiftyDrop.totalStages(), 2);

        bytes32 root = 0x7753ee10f91c40a4e2f0dcc8dc0bcc074a24ca8df608e50407af203b2b45befb;
        bytes32[] memory proof = new bytes32[](4);
        proof[0] = 0x0023f9f5bc869f8a01704930a5f32546cd410a1b423c29d8c67c83157f056d0d;
        proof[1] = 0x0149ef5591f2fdbbbe593f83970032c7624147c4b8221be345d66e248e439609;
        proof[2] = 0xeff6b3cec91dd677a36ea0563574ac79c0c1fea09bcbcc6289d893fc8e701a1e;
        proof[3] = 0xfb3c5a06a36e971b3f23ca37824439ce241afea1f132ccd6a79acb754c0af82b;

        StageData[] memory stages = new StageData[](1);
        StageData memory stage3 = StageData({
            startTime: 2000,
            endTime: 3000,
            mintsPerWallet: 3,
            phaseLimit: 2000,
            price: 1 ether,
            merkleRoot: root
        });
        stages[0] = stage3;

        vm.warp(1500);
        uint256 addStageIndex = 2;
        vm.prank(owner);
        vaultNiftyDrop.setStages(stages, addStageIndex);

        vm.warp(2001);
        // mint allowList
        uint256 count = 2;
        address recip = address(101);
        uint256 mintPrice = vaultNiftyDrop.viewCurrentPrice();
        vm.deal(recip, 3 ether);

        // 验证销售阶段
        assertEq(vaultNiftyDrop.viewCurrentStage(), 2);
        assertEq(vaultNiftyDrop.viewLatestStage(), 2);

        vm.prank(recip);
        vaultNiftyDrop.mintAllowList{value: count * mintPrice}(count, recip, 0, proof);
        assertEq(erc721VaultNifty.numberMinted(recip), count);
        assertEq(erc721VaultNifty.totalMinted(), count);
        assertEq(recip.balance, 3 ether - count * mintPrice);

        // 如果不在白名单中，报错
        vm.deal(address(11), 3 ether);
        vm.prank(address(11));
        vm.expectRevert(abi.encodeWithSignature("MerkleProofFail()"));
        vaultNiftyDrop.mintAllowList{value: count * mintPrice}(count, address(11), 0, proof);
    }

    // forge test -vvvv --match-test testAirdropMint
    function testAirdropMint() public {
        address[] memory receivers = new address[](3);
        receivers[0] = address(300);
        receivers[1] = address(301);
        receivers[2] = address(302);

        uint256 tokenCount = 30;

        vm.prank(owner);
        vaultNiftyDrop.airdropMint(receivers, tokenCount);

        assertEq(erc721VaultNifty.numberMinted(receivers[0]), tokenCount);
        assertEq(erc721VaultNifty.numberMinted(receivers[1]), tokenCount);
        assertEq(erc721VaultNifty.numberMinted(receivers[2]), tokenCount);
        assertEq(erc721VaultNifty.totalMinted(), tokenCount * receivers.length);
        assertEq(erc721VaultNifty.totalSupply(), tokenCount * receivers.length);
    }

    // forge test -vvvv --match-test testWithdraw
    function testWithdraw() public {
        // 增加区块时间为100，使 stage 0 活跃
        vm.warp(100);

        // 接收地址
        address recip = address(200);
        uint256 mintPrice = vaultNiftyDrop.viewCurrentPrice();
        assertEq(recip.balance, 0);
        assertEq(mintPrice, 1.02 ether);

        // mint 两个nft
        vm.deal(recip, 3 ether);
        vm.prank(recip);
        vaultNiftyDrop.mint{value: 2 * mintPrice}(101, 2, recip, 0, emptySignature);

        assertEq(address(vaultNiftyDrop).balance, 2.04 ether);
        assertEq(PrimarySaleReceiver.balance, 0);

        vm.prank(owner);
        vaultNiftyDrop.withdraw();
        assertEq(PrimarySaleReceiver.balance, 2 ether);
        assertEq(PlatformReceiverAddress.balance, 0 ether);
        assertEq(address(vaultNiftyDrop).balance, 0.04 ether);

        vaultNiftyDrop.platformWithdraw();
        assertEq(PlatformReceiverAddress.balance, 0.04 ether);
        assertEq(address(vaultNiftyDrop).balance, 0 ether);
    }

    // forge test -vvvv --match-test testOperatorFilter
    function testOperatorFilter() public {
        assertTrue(operatorFilterRegistry.isOperatorFiltered(address(erc721VaultNifty), address(testTransferNFT)));
        assertTrue(operatorFilterRegistry.isOperatorFiltered(address(erc721VaultNifty), address(111)));
        assertFalse(operatorFilterRegistry.isOperatorFiltered(address(erc721VaultNifty), address(1)));

        vm.expectRevert(abi.encodeWithSignature("AddressFiltered(address)", address(111)));
        operatorFilterRegistry.isOperatorAllowed(address(erc721VaultNifty), address(111));
        vm.expectRevert(abi.encodeWithSignature("AddressFiltered(address)", address(testTransferNFT)));
        operatorFilterRegistry.isOperatorAllowed(address(erc721VaultNifty), address(testTransferNFT));
        assertTrue(operatorFilterRegistry.isOperatorAllowed(address(erc721VaultNifty), address(1)));

        // 黑名单地址mint
        // 增加区块时间为100，使 stage 0 活跃
        vm.warp(100);
        address recip = address(111);
        uint256 mintPrice = vaultNiftyDrop.viewCurrentPrice();
        assertEq(recip.balance, 0);
        assertEq(mintPrice, 1.02 ether);

        // mint 两个nft
        vm.deal(recip, 3 ether);
        vm.prank(recip);
        vaultNiftyDrop.mint{value: 2 * mintPrice}(101, 2, recip, 0, emptySignature);
        assertEq(erc721VaultNifty.numberMinted(recip), 2);
        assertEq(erc721VaultNifty.totalMinted(), 2);
        assertEq(recip.balance, 3 ether - 2 * mintPrice);

        // 黑名单地址 transfer
        // transfer 需要approved
        vm.prank(recip);
        erc721VaultNifty.transferFrom(recip, address(1), 1);

        // user 调用黑名单地址合约 需要approved
        address user = address(200);
        vm.deal(user, 3 ether);
        vm.prank(user);
        vaultNiftyDrop.mint{value: 2 * mintPrice}(101, 2, user, 0, emptySignature);
        assertEq(erc721VaultNifty.ownerOf(3), user);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("NotApprove()"));
        testTransferNFT.transferNFT(address(erc721VaultNifty), 3, address(1));

        vm.prank(user);
        // approve 黑名单 不能转移
        vm.expectRevert(abi.encodeWithSignature("AddressFiltered(address)", address(testTransferNFT)));
        erc721VaultNifty.approve(address(testTransferNFT), 3);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("NotApprove()"));
        testTransferNFT.transferNFT(address(erc721VaultNifty), 3, address(1));
    }
}
