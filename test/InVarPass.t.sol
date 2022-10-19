// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {InVarPass} from "../src/InVarPass.sol";
import {MockERC1155} from "./utils/MockERC1155.sol";

contract InVarPassTest is Test {
    InVarPass internal ipass;
    MockERC1155 internal erc1155;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vm.startPrank(owner);
        ipass = new InVarPass("InVarPass", "IVP", "", 500);
        erc1155 = new MockERC1155();
        emit log_named_address("MockERC1155", address(erc1155));
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
    }
}
