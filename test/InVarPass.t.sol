// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {InVarPass} from "../src/InVarPass.sol";
import {IPass} from "../src/IPass.sol";
import {IPassConstants} from "../src/IPassConstants.sol";
import {Merkle} from "murky/Merkle.sol";
import "openzeppelin-contracts/utils/Strings.sol";
import "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";

contract InVarPassTest is Test, IPassConstants {
    InVarPass internal ipass;
    Merkle internal merkle;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vm.startPrank(owner);
        ipass = new InVarPass("InVarPass", "IVP", 500, 4, "");
        merkle = new Merkle();
        vm.stopPrank();
    }

    function testSetSaleConfig() public {
        vm.prank(owner);
        ipass.setSaleConfig(true, false, false, false);
        (
            bool isFreeMint,
            bool isWhitelistMint,
            bool isPublicMint,
            bool isPremiumMint
        ) = ipass.saleConfig();

        assertTrue(isFreeMint);
        assertFalse(isWhitelistMint);
        assertFalse(isPublicMint);
        assertFalse(isPremiumMint);
    }

    function testFreeMint(bytes32[] memory _freeMintLeave, uint256 node) public {
        vm.assume(_freeMintLeave.length > 1);
        vm.assume(node < _freeMintLeave.length);

        // free mint proof
        _freeMintLeave[0] = keccak256(bytes.concat(keccak256(abi.encode(alice))));
        bytes32 freeMintRoot = merkle.getRoot(_freeMintLeave);
        bytes32[] memory freeMintProof = merkle.getProof(_freeMintLeave, 0);

        vm.startPrank(owner);
        ipass.setSaleConfig(true, false, false, false);
        ipass.setMerkleRoot(freeMintRoot, FREE_MINT);
        changePrank(alice);
        ipass.freeMint(freeMintProof);
        vm.stopPrank();
        assertEq(ipass.balanceOf(alice), 1);
    }

    function test_RevertFreeMintWithMintNotStart(bytes32[] memory _freeMintLeave, uint256 node) public {
        vm.assume(_freeMintLeave.length > 1);
        vm.assume(node < _freeMintLeave.length);
        // free mint proof
        bytes32 freeMintRoot = merkle.getRoot(_freeMintLeave);
        bytes32[] memory freeMintProof = merkle.getProof(_freeMintLeave, node);

        vm.startPrank(alice);
        vm.expectRevert(IPass.MintNotStart.selector);
        ipass.freeMint(freeMintProof);

        changePrank(owner);
        ipass.setMerkleRoot(freeMintRoot, FREE_MINT);
        changePrank(alice);
        vm.expectRevert(IPass.MintNotStart.selector);
        ipass.freeMint(freeMintProof);
        vm.stopPrank();
    }

    function test_RevertFreeMintWithAlreadyClaimed(bytes32[] memory _freeMintLeave, uint256 node) public {
        vm.assume(_freeMintLeave.length > 1);
        vm.assume(node < _freeMintLeave.length);
        // free mint proof
        _freeMintLeave[node] = keccak256(bytes.concat(keccak256(abi.encode(alice))));
        bytes32 freeMintRoot = merkle.getRoot(_freeMintLeave);
        bytes32[] memory freeMintProof = merkle.getProof(_freeMintLeave, node);

        vm.startPrank(owner);
        ipass.setSaleConfig(true, false, false, false);
        ipass.setMerkleRoot(freeMintRoot, FREE_MINT);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.freeMint(freeMintProof);
        vm.expectRevert(IPass.AlreadyClaimed.selector);
        ipass.freeMint(freeMintProof);
        vm.stopPrank();
    }

    function test_RevertFreeMintWithInvalidProof(bytes32[] memory _freeMintLeave, uint256 node) public {
        vm.assume(_freeMintLeave.length > 1);
        vm.assume(node < _freeMintLeave.length);
        // free mint proof
        bytes32 freeMintRoot = merkle.getRoot(_freeMintLeave);
        bytes32[] memory freeMintProof = merkle.getProof(_freeMintLeave, node);

        vm.startPrank(owner);
        ipass.setSaleConfig(true, false, false, false);
        ipass.setMerkleRoot(freeMintRoot, FREE_MINT);
        changePrank(alice);
        vm.expectRevert(IPass.InvalidProof.selector);
        ipass.freeMint(freeMintProof);
        vm.stopPrank();
    }

    function test_RevertFreeMintWithMintExceedsLimit(bytes32[] memory _freeMintLeave, uint256 node) public {
        vm.assume(_freeMintLeave.length > 1);
        vm.assume(node < _freeMintLeave.length);
        // free mint proof
        _freeMintLeave[node] = keccak256(bytes.concat(keccak256(abi.encode(alice))));
        bytes32 freeMintRoot = merkle.getRoot(_freeMintLeave);
        bytes32[] memory freeMintProof = merkle.getProof(_freeMintLeave, node);

        vm.startPrank(owner);
        ipass.setSaleConfig(true, false, false, false);
        ipass.setMerkleRoot(freeMintRoot, FREE_MINT);
        ipass.setMaxSupply(0);
        changePrank(alice);
        vm.expectRevert(IPass.MintExceedsLimit.selector);
        ipass.freeMint(freeMintProof);
        vm.stopPrank();
    }

    function testWhitelistMint(bytes32[] memory _whiteListLeave, uint256 node) public {
        vm.assume(_whiteListLeave.length > 1);
        vm.assume(node < _whiteListLeave.length);
        // white list proof
        _whiteListLeave[node] = keccak256(bytes.concat(keccak256(abi.encode(alice))));
        bytes32 whiteListRoot = merkle.getRoot(_whiteListLeave);
        bytes32[] memory whiteListProof = merkle.getProof(_whiteListLeave, node);

        vm.startPrank(owner);
        ipass.setSaleConfig(false, true, false, false);
        ipass.setMerkleRoot(whiteListRoot, WHITELIST);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.whitelistMint{value: 0.05 ether}(whiteListProof);
        vm.stopPrank();
        assertEq(ipass.balanceOf(alice), 1);
    }

    function test_RevertWhitelistMintWithMintNotStart(bytes32[] memory _whiteListLeave, uint256 node) public {
        vm.assume(_whiteListLeave.length > 1);
        vm.assume(node < _whiteListLeave.length);
        // white list proof
        bytes32 whiteListRoot = merkle.getRoot(_whiteListLeave);
        bytes32[] memory whiteListProof = merkle.getProof(_whiteListLeave, node);

        deal(alice, 1 ether);
        vm.startPrank(alice);
        vm.expectRevert(IPass.MintNotStart.selector);
        ipass.whitelistMint{value: 0.05 ether}(whiteListProof);

        changePrank(owner);
        ipass.setMerkleRoot(whiteListRoot, WHITELIST);
        changePrank(alice);
        vm.expectRevert(IPass.MintNotStart.selector);
        ipass.whitelistMint{value: 0.05 ether}(whiteListProof);
        vm.stopPrank();
    }

    function test_RevertWhitelistMintWithAlreadyClaimed(bytes32[] memory _whiteListLeave, uint256 node) public {
        vm.assume(_whiteListLeave.length > 1);
        vm.assume(node < _whiteListLeave.length);
        // white list proof
        _whiteListLeave[node] = keccak256(bytes.concat(keccak256(abi.encode(alice))));
        bytes32 whiteListRoot = merkle.getRoot(_whiteListLeave);
        bytes32[] memory whiteListProof = merkle.getProof(_whiteListLeave, node);

        vm.startPrank(owner);
        ipass.setSaleConfig(false, true, false, false);
        ipass.setMerkleRoot(whiteListRoot, WHITELIST);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.whitelistMint{value: 0.05 ether}(whiteListProof);
        vm.expectRevert(IPass.AlreadyClaimed.selector);
        ipass.whitelistMint{value: 0.05 ether}(whiteListProof);
        vm.stopPrank();
    }

    function test_RevertWhitelistMintWithInvalidProof(bytes32[] memory _whiteListLeave, uint256 node) public {
        vm.assume(_whiteListLeave.length > 1);
        vm.assume(node < _whiteListLeave.length);
        // white list proof
        bytes32 whiteListRoot = merkle.getRoot(_whiteListLeave);
        bytes32[] memory whiteListProof = merkle.getProof(_whiteListLeave, node);

        vm.startPrank(owner);
        ipass.setSaleConfig(false, true, false, false);
        ipass.setMerkleRoot(whiteListRoot, WHITELIST);
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.InvalidProof.selector);
        ipass.whitelistMint{value: 0.05 ether}(whiteListProof);
        vm.stopPrank();
    }

    function test_RevertWhitelistMintWithInsufficientEthers(bytes32[] memory _whiteListLeave, uint256 node) public {
        vm.assume(_whiteListLeave.length > 1);
        vm.assume(node < _whiteListLeave.length);
        // white list proof
        _whiteListLeave[node] = keccak256(bytes.concat(keccak256(abi.encode(alice))));
        bytes32 whiteListRoot = merkle.getRoot(_whiteListLeave);
        bytes32[] memory whiteListProof = merkle.getProof(_whiteListLeave, node);

        vm.startPrank(owner);
        ipass.setSaleConfig(false, true, false, false);
        ipass.setMerkleRoot(whiteListRoot, WHITELIST);
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.InsufficientEthers.selector);
        ipass.whitelistMint{value: 0.04 ether}(whiteListProof);
        vm.stopPrank();
    }

    function test_RevertWhitelistMintWithMintExceedsLimit(bytes32[] memory _whiteListLeave, uint256 node) public {
        vm.assume(_whiteListLeave.length > 1);
        vm.assume(node < _whiteListLeave.length);
        // white list proof
        _whiteListLeave[node] = keccak256(bytes.concat(keccak256(abi.encode(alice))));
        bytes32 whiteListRoot = merkle.getRoot(_whiteListLeave);
        bytes32[] memory whiteListProof = merkle.getProof(_whiteListLeave, node);

        vm.startPrank(owner);
        ipass.setSaleConfig(false, true, false, false);
        ipass.setMerkleRoot(whiteListRoot, WHITELIST);
        ipass.setMaxSupply(0);
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.MintExceedsLimit.selector);
        ipass.whitelistMint{value: 0.05 ether}(whiteListProof);
        vm.stopPrank();
    }

    function testPublicMint() public {
        vm.startPrank(owner);
        ipass.setSaleConfig(false, false, true, false);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.publicMint{value: 0.3 ether}(3);
        vm.stopPrank();
        assertEq(ipass.balanceOf(alice), 3);
    }

    function test_RevertPublicMintWithMintNotStart() public {
        vm.startPrank(owner);
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.MintNotStart.selector);
        ipass.publicMint{value: 0.3 ether}(3);
        vm.stopPrank();
    }

    function test_RevertPublicMintWithInsufficientEthers() public {
        vm.startPrank(owner);
        ipass.setSaleConfig(false, false, true, false);
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.InsufficientEthers.selector);
        ipass.publicMint{value: 0.2 ether}(3);
        vm.stopPrank();
    }

    function test_RevertPublicMintWithMintExceedsLimit() public {
        vm.startPrank(owner);
        ipass.setSaleConfig(false, false, true, false);
        ipass.setMaxSupply(0);
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.MintExceedsLimit.selector);
        ipass.publicMint{value: 0.3 ether}(3);
        changePrank(owner);
        ipass.setMaxSupply(500);
        changePrank(alice);
        vm.expectRevert(IPass.MintExceedsLimit.selector);
        ipass.publicMint{value: 0.5 ether}(5);
        vm.stopPrank();
    }

    // oz/merkle-tree hash pair func is not the same as murkey/Merkle
    // use dummy data to test instead
    function testPremiumMint() public {
        // token root
        bytes32 root = 0x4ed6fa3d623b003df23ff953a1ddd60616ca26c43b06ad2ff06b6a139ee2fe2f;
        
        // multi proof & flags
        bytes32[] memory multiProof = new bytes32[](2);
        multiProof[0] = 0x6f5a07349193d4faac44fd1ad6e052fe3cb9dd746c454b73cba5ebc975a6e7bb;
        multiProof[1] = 0x9fb575fc6758f041f5002e350be6a79058626fe3f9dabb9ea2d9ea355c509958;
        bool[] memory flags = new bool[](3);
        flags[0] = false;
        flags[1] = true;
        flags[2] = false;

        uint256[] memory tokens = new uint256[](2);
        tokens[0] = 1;
        tokens[1] = 2;

        vm.startPrank(owner);
        // public sale & premium mint
        ipass.setSaleConfig(false, false, true, true);
        ipass.setMerkleRoot(root, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.publicMint{value: 0.2 ether}(2);
        ipass.premiumMint(multiProof, flags, tokens);
        assertEq(ipass.balanceOf(alice), 1);
        vm.stopPrank();
    }

    function test_RevertPremiumMintWithNotOwner() public {
        // token root
        bytes32 root = 0x4ed6fa3d623b003df23ff953a1ddd60616ca26c43b06ad2ff06b6a139ee2fe2f;

        // multi proof & flags
        bytes32[] memory multiProof = new bytes32[](2);
        multiProof[0] = 0x6f5a07349193d4faac44fd1ad6e052fe3cb9dd746c454b73cba5ebc975a6e7bb;
        multiProof[1] = 0x9fb575fc6758f041f5002e350be6a79058626fe3f9dabb9ea2d9ea355c509958;
        bool[] memory flags = new bool[](3);
        flags[0] = false;
        flags[1] = true;
        flags[2] = false;

        uint256[] memory tokens = new uint256[](2);
        tokens[0] = 1;
        tokens[1] = 2;

        vm.startPrank(owner);
        ipass.setSaleConfig(false, false, true, true);
        ipass.setMerkleRoot(root, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.publicMint{value: 0.2 ether}(2);
        changePrank(bob);
        vm.expectRevert(IPass.NotOwner.selector);
        ipass.premiumMint(multiProof, flags, tokens);
        vm.stopPrank();
    }

    function test_RevertPremiumMintWithInvalidProof() public {
        // token root
        bytes32 root = 0x4ed6fa3d623b003df23ff953a1ddd60616ca26c43b06ad2ff06b6a139ee2fe2f;

        // multi proof & flags
        bytes32[] memory multiProof = new bytes32[](2);
        multiProof[0] = 0x6f5a07349193d4faac44fd1ad6e052fe3cb9dd746c454b73cba5ebc975a6e7bb;
        multiProof[1] = hex"6515";
        bool[] memory flags = new bool[](3);
        flags[0] = false;
        flags[1] = true;
        flags[2] = false;

        uint256[] memory tokens = new uint256[](2);
        tokens[0] = 1;
        tokens[1] = 2;

        vm.startPrank(owner);
        ipass.setSaleConfig(false, false, true, true);
        ipass.setMerkleRoot(root, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.publicMint{value: 0.2 ether}(2);
        changePrank(alice);
        vm.expectRevert(IPass.InvalidProof.selector);
        ipass.premiumMint(multiProof, flags, tokens);
        vm.stopPrank();
    }

    function testVerifyToken(bytes32[] memory _tokenLeave) public {
        vm.assume(_tokenLeave.length > 3);
        // token proof
        _tokenLeave[0] = keccak256(bytes.concat(keccak256(abi.encode(1, EARTH))));
        bytes32 tokenRoot = merkle.getRoot(_tokenLeave);
        bytes32[][] memory tokenProofs = new bytes32[][](1);
        tokenProofs[0] = merkle.getProof(_tokenLeave, 0);

        vm.startPrank(owner);
        ipass.setSaleConfig(false, false, true, false);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.publicMint{value: 0.1 ether}(1);
        vm.stopPrank();
        bool result = ipass.verifyToken(tokenProofs[0], 1, EARTH, alice);
        assertTrue(result);
    }
}