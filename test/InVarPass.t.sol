// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { InVarPass } from "../src/InVarPass.sol";
import { IPass } from "../src/IPass.sol";
import { Merkle } from "murky/Merkle.sol";
import "openzeppelin-contracts/utils/Strings.sol";
import "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";

contract InVarPassTest is Test {
    using Strings for uint256;

    bytes32 constant FREE_MINT = 0xaca2929d09e74b1bd257acca0d40349ade3291350b31ee1e04b706c764e53859;
    bytes32 constant WHITELIST = 0xc3d232a6c0e2fb343117f17a5ff344a1a84769265318c6d7a8d7d9b2f8bb49e3;
    bytes32 constant TOKEN = 0x1317f51c845ce3bfb7c268e5337a825f12f3d0af9584c2bbfbf4e64e314eaf73;

    InVarPass internal ipass;
    Merkle internal merkle;
    bytes32[100] data;

    bytes32[] mockProof;
    bool[] mockProofFlags;
    bytes32[] mockLeaves;
    bytes32 mockRoot;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        string[] memory inputs = new string[](2);
        inputs[0] = "cat";
        inputs[1] = "test/utils/MockLeaves.txt";
        bytes memory result = vm.ffi(inputs);
        data = abi.decode(result, (bytes32[100]));

        vm.startPrank(owner);
        ipass = new InVarPass("InVarPass", "IVP", "", 500);
        merkle = new Merkle();
        vm.stopPrank();

        mockProof = new bytes32[](17);
        mockProof[0] = 0x9538189ca6eb762597642aec4fde397f64651eb70e9b63bc89d0030da22f7582;
        mockProof[1] = 0x9f48ad18135aa4c5cfeff3416bb25537d3e05b5d72b8f8329e12d866cd124f7b;
        mockProof[2] = 0x7c0a3b107a3dddf93244216d85ec7e5aee12f01a83ae0e294a3bb637ff243f6b;
        mockProof[3] = 0xa10bfbb842daf3344324e261b380b686db43b1346070a6d4bbea36a0e6a9731e;
        mockProof[4] = 0x74d7123f11ae377247ced4df42fba1502ffccb4080aaf30ceebd4580f130d821;
        mockProof[5] = 0x74d7123f11ae377247ced4df42fba1502ffccb4080aaf30ceebd4580f130d821;
        mockProof[6] = 0x97f447fda38791bf20397193931a01c4e5b544bb923cd9e3aa488fbda5244458;
        mockProof[7] = 0x7e54a703c7a4de2603ed47e075dde91eb49286f10efb2486b1a5fe3d5fe7a67c;
        mockProof[8] = 0x8252890dc2bf4ab3bd77cf27c8bae66d140d1c02b62085e8446e42d99420d83e;
        mockProof[9] = 0x8252890dc2bf4ab3bd77cf27c8bae66d140d1c02b62085e8446e42d99420d83e;
        mockProof[10] = 0x3eb2d7b68338f49ce776897758e01de813d37bedfd9bfe485a0eb5e179555f21;
        mockProof[11] = 0x3eb2d7b68338f49ce776897758e01de813d37bedfd9bfe485a0eb5e179555f21;
        mockProof[12] = 0x28ed21c2e726ca6ca8f10a80b5441c1952b7820d3a33f24859e0c3a8d3db7ede;
        mockProof[13] = 0xc8c92a7fc7c66783872b616b458d49980e4f61a74680901703249fd36ef9581a;
        mockProof[14] = 0xf693a8862b55572a1a81f7e9c40ea09e95988eca33fd90cfecf96d3ee79da812;
        mockProof[15] = 0x7a99ccb0697fa5e7586def751fee632014dd2a603449842f3d5802fc44aee6f7;
        mockProof[16] = 0x3269a4fc321cb06d4b2ba6bb28bcbcf88e604f6159c5d5771a4501a16200c9f3;
        
        mockProofFlags = new bool[](18);
        mockProofFlags[0] = false;
        mockProofFlags[1] = false;
        mockProofFlags[2] = false;
        mockProofFlags[3] = false;
        mockProofFlags[4] = false;
        mockProofFlags[5] = false;
        mockProofFlags[6] = false;
        mockProofFlags[7] = false;
        mockProofFlags[8] = false;
        mockProofFlags[9] = false;
        mockProofFlags[10] = false;
        mockProofFlags[11] = false;
        mockProofFlags[12] = false;
        mockProofFlags[13] = false;
        mockProofFlags[14] = false;
        mockProofFlags[15] = false;
        mockProofFlags[16] = true;
        mockProofFlags[17] = false;
        
        mockLeaves = new bytes32[](2);
        mockLeaves[0] = 0x9538189ca6eb762597642aec4fde397f64651eb70e9b63bc89d0030da22f7582;
        mockLeaves[1] = 0x9f48ad18135aa4c5cfeff3416bb25537d3e05b5d72b8f8329e12d866cd124f7b;
        
        mockRoot = 0x25858ea94774555f1347ca19f24f65f9abeeb2352cf87b597055a958b773a188;
    }

    function testSetSaleConfig() public {
        vm.prank(owner);
        ipass.setSaleConfig(true, false, false);
        (
            bool isFreeMint,
            bool isWhitelistMint,
            bool isPublicMint
        ) = ipass.saleConfig();

        assertTrue(isFreeMint);
        assertFalse(isWhitelistMint);
        assertFalse(isPublicMint);
    }

    function testFreeMint() public {
        bytes32[] memory _data = _getData();
        bytes32 root = merkle.getRoot(_data);
        bytes32[] memory proof = merkle.getProof(_data, 99);

        vm.startPrank(owner);
        ipass.setSaleConfig(true, false, false);
        ipass.setMerkleRoot(root, FREE_MINT);
        changePrank(alice);
        ipass.freeMint(proof);
        vm.stopPrank();
        assertEq(ipass.balanceOf(alice), 1);
    }

    function test_RevertFreeMintWithSaleTimeNotReach() public {
        bytes32[] memory _data = _getData();
        bytes32 root = merkle.getRoot(_data);
        bytes32[] memory proof = merkle.getProof(_data, 99);

        vm.startPrank(alice);
        vm.expectRevert(IPass.SaleTimeNotReach.selector);
        ipass.freeMint(proof);

        changePrank(owner);
        ipass.setMerkleRoot(root, FREE_MINT);
        changePrank(alice);
        vm.expectRevert(IPass.SaleTimeNotReach.selector);
        ipass.freeMint(proof);
        vm.stopPrank();
    }

    function test_RevertFreeMintWithAlreadyClaimed() public {
        bytes32[] memory _data = _getData();
        bytes32 root = merkle.getRoot(_data);
        bytes32[] memory proof = merkle.getProof(_data, 99);

        vm.startPrank(owner);
        ipass.setSaleConfig(true, false, false);
        ipass.setMerkleRoot(root, FREE_MINT);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.freeMint(proof);
        vm.expectRevert(IPass.AlreadyClaimed.selector);
        ipass.freeMint(proof);
        vm.stopPrank();
    }

    function test_RevertFreeMintWithInvalidProof() public {
        bytes32[] memory _data = _getData();
        bytes32 root = merkle.getRoot(_data);
        bytes32[] memory proof = merkle.getProof(_data, 99);

        vm.startPrank(owner);
        ipass.setSaleConfig(true, false, false);
        ipass.setMerkleRoot(root, FREE_MINT);
        vm.expectRevert(IPass.InvalidProof.selector);
        ipass.freeMint(proof);
        vm.stopPrank();
    }

    function test_RevertFreeMintWithMintExceedsLimit() public {
        bytes32[] memory _data = _getData();
        bytes32 root = merkle.getRoot(_data);
        bytes32[] memory proof = merkle.getProof(_data, 99);

        vm.startPrank(owner);
        ipass.setSaleConfig(true, false, false);
        ipass.setMerkleRoot(root, FREE_MINT);
        ipass.setSupply(0);
        changePrank(alice);
        vm.expectRevert(IPass.MintExceedsLimit.selector);
        ipass.freeMint(proof);
        vm.stopPrank();
    }

    function testWhitelistMint() public {
        bytes32[] memory _data = _getData();
        bytes32 root = merkle.getRoot(_data);
        bytes32[] memory proof = merkle.getProof(_data, 99);

        vm.startPrank(owner);
        ipass.setSaleConfig(false, true, false);
        ipass.setMerkleRoot(root, WHITELIST);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.whitelistMint{value: 0.05 ether}(proof);
        vm.stopPrank();
        assertEq(ipass.balanceOf(alice), 1);
    }

    function test_RevertWhitelistMintWithSaleTimeNotReach() public {
        bytes32[] memory _data = _getData();
        bytes32 root = merkle.getRoot(_data);
        bytes32[] memory proof = merkle.getProof(_data, 99);

        deal(alice, 1 ether);
        vm.startPrank(alice);
        vm.expectRevert(IPass.SaleTimeNotReach.selector);
        ipass.whitelistMint{value: 0.05 ether}(proof);

        changePrank(owner);
        ipass.setMerkleRoot(root, WHITELIST);
        changePrank(alice);
        vm.expectRevert(IPass.SaleTimeNotReach.selector);
        ipass.whitelistMint{value: 0.05 ether}(proof);
        vm.stopPrank();
    }

    function test_RevertWhitelistMintWithAlreadyClaimed() public {
        bytes32[] memory _data = _getData();
        bytes32 root = merkle.getRoot(_data);
        bytes32[] memory proof = merkle.getProof(_data, 99);

        vm.startPrank(owner);
        ipass.setSaleConfig(false, true, false);
        ipass.setMerkleRoot(root, WHITELIST);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.whitelistMint{value: 0.05 ether}(proof);
        vm.expectRevert(IPass.AlreadyClaimed.selector);
        ipass.whitelistMint{value: 0.05 ether}(proof);
        vm.stopPrank();
    }

    function test_RevertWhitelistMintWithInvalidProof() public {
        bytes32[] memory _data = _getData();
        bytes32 root = merkle.getRoot(_data);
        bytes32[] memory proof = merkle.getProof(_data, 99);

        vm.startPrank(owner);
        ipass.setSaleConfig(false, true, false);
        ipass.setMerkleRoot(root, WHITELIST);
        deal(bob, 1 ether);
        changePrank(bob);
        vm.expectRevert(IPass.InvalidProof.selector);
        ipass.whitelistMint{value: 0.05 ether}(proof);
        vm.stopPrank();
    }

    function test_RevertWhitelistMintWithInsufficientEthers() public {
        bytes32[] memory _data = _getData();
        bytes32 root = merkle.getRoot(_data);
        bytes32[] memory proof = merkle.getProof(_data, 99);

        vm.startPrank(owner);
        ipass.setSaleConfig(false, true, false);
        ipass.setMerkleRoot(root, WHITELIST);
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.InsufficientEthers.selector);
        ipass.whitelistMint{value: 0.04 ether}(proof);
        vm.stopPrank();
    }

    function test_RevertWhitelistMintWithMintExceedsLimit() public {
        bytes32[] memory _data = _getData();
        bytes32 root = merkle.getRoot(_data);
        bytes32[] memory proof = merkle.getProof(_data, 99);

        vm.startPrank(owner);
        ipass.setSaleConfig(false, true, false);
        ipass.setMerkleRoot(root, WHITELIST);
        ipass.setSupply(0);
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.MintExceedsLimit.selector);
        ipass.whitelistMint{value: 0.05 ether}(proof);
        vm.stopPrank();
    }

    function testPublicMint() public {
        vm.prank(owner);
        ipass.setSaleConfig(false, false, true);
        deal(alice, 1 ether);
        vm.prank(alice);
        ipass.publicMint{value: 0.24 ether}(3);
        assertEq(ipass.balanceOf(alice), 3);
    }

    function test_RevertPublicMintWithSaleTimeNotReach() public {
        deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert(IPass.SaleTimeNotReach.selector);
        ipass.publicMint{value: 0.24 ether}(3);
    }

    function test_RevertPublicMintWithInsufficientEthers() public {
        vm.prank(owner);
        ipass.setSaleConfig(false, false, true);
        deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert(IPass.InsufficientEthers.selector);
        ipass.publicMint{value: 0.2 ether}(3);
    }

    function test_RevertPublicMintWithMintExceedsLimit() public {
        vm.startPrank(owner);
        ipass.setSaleConfig(false, false, true);
        ipass.setSupply(0);
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.MintExceedsLimit.selector);
        ipass.publicMint{value: 0.24 ether}(3);
        changePrank(owner);
        ipass.setSupply(500);
        changePrank(alice);
        vm.expectRevert(IPass.MintExceedsLimit.selector);
        ipass.publicMint{value: 0.4 ether}(5);
        vm.stopPrank();
    }

    function testPremiumMint() public {
        vm.startPrank(owner);
        ipass.setSaleConfig(false, false, true);
        ipass.setIsPremiumStart(true);
        ipass.setMerkleRoot(mockRoot, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.publicMint{value: 0.16 ether}(2);
        ipass.premiumMint(mockProof, mockProofFlags, mockLeaves, 1, 2);
        assertEq(ipass.balanceOf(alice), 1);
        vm.stopPrank();
    }

    function test_RevertPremiumMintWithMintNotStart() public {
        vm.startPrank(owner);
        ipass.setSaleConfig(false, false, true);
        ipass.setMerkleRoot(mockRoot, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.publicMint{value: 0.16 ether}(2);
        vm.expectRevert(IPass.MintNotStart.selector);
        ipass.premiumMint(mockProof, mockProofFlags, mockLeaves, 1, 2);
        vm.stopPrank();
    }

    function test_RevertPremiumMintWithInvalidProof() public {
        mockProof[5] = 0x97f447fda38791bf20397193931a01c4e5b544bb923cd9e3aa488fbda5244458;
        
        vm.startPrank(owner);
        ipass.setSaleConfig(false, false, true);
        ipass.setMerkleRoot(mockRoot, TOKEN);
        ipass.setIsPremiumStart(true);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.publicMint{value: 0.16 ether}(2);
        vm.expectRevert(IPass.InvalidProof.selector);
        ipass.premiumMint(mockProof, mockProofFlags, mockLeaves, 1, 2);
        vm.stopPrank();
    }

    function test_RevertPremiumMintWithNotOwner() public {
        vm.startPrank(owner);
        ipass.setSaleConfig(false, false, true);
        ipass.setMerkleRoot(mockRoot, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.publicMint{value: 0.16 ether}(2);
        changePrank(bob);
        vm.expectRevert(IPass.MintNotStart.selector);
        ipass.premiumMint(mockProof, mockProofFlags, mockLeaves, 1, 2);
        vm.stopPrank();
    }

    function _getData() internal view returns (bytes32[] memory) {
        bytes32[] memory _data = new bytes32[](data.length);
        uint length = data.length;
        for (uint i = 0; i < length; ++i) {
            _data[i] = data[i];
        }
        return _data;
    }

    function test_CreateLeaves() public {
        bytes memory result = abi.encodePacked(_createLeaves());
        emit log_named_bytes("Leaves", result);
    }

    function _createLeaves() internal returns (bytes32[] memory) {
        bytes32[] memory leaves = new bytes32[](100);
        for (uint256 i = 0; i < 99; i++) {
            leaves[i] = keccak256(abi.encodePacked(makeAddr(i.toString())));
        }
        leaves[99] = keccak256(abi.encodePacked(makeAddr("alice")));
        return leaves;
    }

}
