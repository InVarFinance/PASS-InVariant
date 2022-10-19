// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { InVarPass } from "../src/InVarPass.sol";
import { IPass } from "../src/IPass.sol";
import { MockERC1155 } from "./utils/MockERC1155.sol";
import { Merkle } from "murky/Merkle.sol";
import "openzeppelin-contracts/utils/Strings.sol";

contract InVarPassTest is Test {
    using stdStorage for StdStorage;
    using Strings for uint256;

    InVarPass internal ipass;
    MockERC1155 internal erc1155;
    Merkle internal merkle;
    bytes32[100] data;

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
        erc1155 = new MockERC1155();
        merkle = new Merkle();
        vm.stopPrank();
    }

    function testSetSaleConfig() public {
        vm.prank(owner);
        ipass.setSaleConfig(
            uint32(block.timestamp),
            uint32(block.timestamp),
            uint64(0.05 ether),
            uint64(0.08 ether),
            uint8(3)
        );
        (
            uint32 freemintSaleStartTime,
            uint32 publicSaleStartTime,
            uint64 whitelistPrice,
            uint64 publicPrice,
            uint8 publicMintQuantity
        ) = ipass.saleConfig();

        assertEq(freemintSaleStartTime, block.timestamp);
        assertEq(publicSaleStartTime, block.timestamp);
        assertEq(whitelistPrice, 0.05 ether);
        assertEq(publicPrice, 0.08 ether);
        assertEq(publicMintQuantity, 3);
    }

    function testFreeMint() public {
        vm.startPrank(owner);
        ipass.setSaleConfig(
            uint32(block.timestamp),
            uint32(block.timestamp),
            uint64(0.05 ether),
            uint64(0.08 ether),
            uint8(3)
        );
        changePrank(alice);
        erc1155.mint(1, 1);
        ipass.freeMint(1);
        vm.stopPrank();
        assertEq(ipass.balanceOf(alice), 1);
    }

    function test_RevertFreeMintWithSaleTimeNotReach() public {
        vm.startPrank(alice);
        vm.expectRevert(IPass.SaleTimeNotReach.selector);
        ipass.freeMint(1);
        vm.stopPrank();
    }

    function test_RevertFreeMintWithOnlyReOwner() public {
        vm.startPrank(owner);
        ipass.setSaleConfig(
            uint32(block.timestamp),
            uint32(block.timestamp),
            uint64(0.05 ether),
            uint64(0.08 ether),
            uint8(3)
        );
        changePrank(alice);
        vm.expectRevert(IPass.OnlyReOwner.selector);
        ipass.freeMint(1);
        vm.stopPrank();
    }

    function test_RevertFreeMintWithMintExceedsLimit() public {
        vm.startPrank(owner);
        ipass.setSaleConfig(
            uint32(block.timestamp),
            uint32(block.timestamp),
            uint64(0.05 ether),
            uint64(0.08 ether),
            uint8(3)
        );
        changePrank(alice);
        erc1155.mint(1, 1);
        vm.expectRevert(IPass.MintExceedsLimit.selector);
        ipass.freeMint(501);
        vm.stopPrank();
    }

    function testWhitelistMint() public {
        bytes32[] memory _data = _getData();
        bytes32 root = merkle.getRoot(_data);
        bytes32[] memory proof = merkle.getProof(_data, 99);

        vm.startPrank(owner);
        ipass.setMerkleRoot(root);
        ipass.setSaleConfig(
            uint32(block.timestamp),
            uint32(block.timestamp),
            uint64(0.05 ether),
            uint64(0.08 ether),
            uint8(3)
        );
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.whitelistMint{value: 0.05 ether}(proof);
        vm.stopPrank();
        assertEq(ipass.balanceOf(alice), 1);
    }

    function test_RevertWhitelistMintWithAlreadyClaimed() public {
        bytes32[] memory _data = _getData();
        bytes32 root = merkle.getRoot(_data);
        bytes32[] memory proof = merkle.getProof(_data, 99);

        vm.startPrank(owner);
        ipass.setMerkleRoot(root);
        ipass.setSaleConfig(
            uint32(block.timestamp),
            uint32(block.timestamp),
            uint64(0.05 ether),
            uint64(0.08 ether),
            uint8(3)
        );
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
        ipass.setMerkleRoot(root);
        ipass.setSaleConfig(
            uint32(block.timestamp),
            uint32(block.timestamp),
            uint64(0.05 ether),
            uint64(0.08 ether),
            uint8(3)
        );
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
        ipass.setMerkleRoot(root);
        ipass.setSaleConfig(
            uint32(block.timestamp),
            uint32(block.timestamp),
            uint64(0.05 ether),
            uint64(0.08 ether),
            uint8(3)
        );
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.InsufficientEthers.selector);
        ipass.whitelistMint{value: 0.04 ether}(proof);
        vm.stopPrank();
    }

    function test_RevertWhitelistMintWithSaleTimeNotReach() public {
        bytes32[] memory _data = _getData();
        bytes32[] memory proof = merkle.getProof(_data, 99);

        vm.startPrank(owner);
        ipass.setSaleConfig(
            uint32(block.timestamp),
            uint32(block.timestamp),
            uint64(0.05 ether),
            uint64(0.08 ether),
            uint8(3)
        );
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.SaleTimeNotReach.selector);
        ipass.whitelistMint{value: 0.05 ether}(proof);
        vm.stopPrank();
    }

    function test_RevertWhitelistMintWithMintExceedsLimit() public {
        bytes32[] memory _data = _getData();
        bytes32 root = merkle.getRoot(_data);
        bytes32[] memory proof = merkle.getProof(_data, 99);

        vm.startPrank(owner);
        ipass.setMerkleRoot(root);
        ipass.setSupply(0);
        ipass.setSaleConfig(
            uint32(block.timestamp),
            uint32(block.timestamp),
            uint64(0.05 ether),
            uint64(0.08 ether),
            uint8(3)
        );
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.MintExceedsLimit.selector);
        ipass.whitelistMint{value: 0.05 ether}(proof);
        vm.stopPrank();
    }

    function testPublicMint() public {
        vm.prank(owner);
        ipass.setSaleConfig(
            uint32(block.timestamp),
            uint32(block.timestamp),
            uint64(0.05 ether),
            uint64(0.08 ether),
            uint8(3)
        );
        deal(alice, 1 ether);
        vm.prank(alice);
        ipass.publicMint{value: 0.24 ether}(3);
        assertEq(ipass.balanceOf(alice), 3);
    }

    function _getData() internal view returns (bytes32[] memory) {
        bytes32[] memory _data = new bytes32[](data.length);
        uint length = data.length;
        for (uint i = 0; i < length; ++i) {
            _data[i] = data[i];
        }
        return _data;
    }

    function testCreateLeaves() public {
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
