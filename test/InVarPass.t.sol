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
    using Strings for uint256;

    string constant EARTH = "Earth";
    string constant OCEAN = "Ocean";
    string constant SKY = "Skyline";

    InVarPass internal ipass;
    Merkle internal merkle;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vm.startPrank(owner);
        ipass = new InVarPass("InVarPass", "IVP", 500, 4);
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

    function testFreeMint(
        bytes32[] memory _freeMintLeave,
        bytes32[] memory _tokenLeave,
        uint256 node
    ) public {
        vm.assume(_freeMintLeave.length > 1);
        vm.assume(_tokenLeave.length > 1);
        vm.assume(node < _freeMintLeave.length);

        // free mint proof
        _freeMintLeave[0] = keccak256(
            bytes.concat(keccak256(abi.encode(alice)))
        );
        bytes32 freeMintRoot = merkle.getRoot(_freeMintLeave);
        bytes32[] memory freeMintProof = merkle.getProof(_freeMintLeave, 0);

        // token proof
        _tokenLeave[0] = keccak256(bytes.concat(keccak256(abi.encode(1, EARTH))));
        bytes32 tokenRoot = merkle.getRoot(_tokenLeave);
        bytes32[] memory tokenProof = merkle.getProof(_tokenLeave, 0);

        vm.startPrank(owner);
        ipass.setSaleConfig(true, false, false, false);
        ipass.setMerkleRoot(freeMintRoot, FREE_MINT);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        changePrank(alice);
        ipass.freeMint(freeMintProof, tokenProof, EARTH);
        vm.stopPrank();
        assertEq(ipass.balanceOf(alice), 1);
    }

    function test_RevertFreeMintWithMintNotStart(
        bytes32[] memory _freeMintLeave,
        bytes32[] memory _tokenLeave,
        uint256 node
    ) public {
        vm.assume(_freeMintLeave.length > 1);
        vm.assume(_tokenLeave.length > 1);
        vm.assume(node < _freeMintLeave.length);
        vm.assume(node < _tokenLeave.length);
        // free mint proof
        bytes32 freeMintRoot = merkle.getRoot(_freeMintLeave);
        bytes32[] memory freeMintProof = merkle.getProof(_freeMintLeave, node);

        // token proof
        bytes32[] memory tokenProof = merkle.getProof(_tokenLeave, node);

        vm.startPrank(alice);
        vm.expectRevert(IPass.MintNotStart.selector);
        ipass.freeMint(freeMintProof, tokenProof, EARTH);

        changePrank(owner);
        ipass.setMerkleRoot(freeMintRoot, FREE_MINT);
        changePrank(alice);
        vm.expectRevert(IPass.MintNotStart.selector);
        ipass.freeMint(freeMintProof, tokenProof, EARTH);
        vm.stopPrank();
    }

    function test_RevertFreeMintWithAlreadyClaimed(
        bytes32[] memory _freeMintLeave,
        bytes32[] memory _tokenLeave,
        uint256 node
    ) public {
        vm.assume(_freeMintLeave.length > 1);
        vm.assume(_tokenLeave.length > 1);
        vm.assume(node < _freeMintLeave.length);
        // free mint proof
        _freeMintLeave[node] = keccak256(bytes.concat(keccak256(abi.encode(alice))));
        bytes32 freeMintRoot = merkle.getRoot(_freeMintLeave);
        bytes32[] memory freeMintProof = merkle.getProof(_freeMintLeave, node);

        // token proof
        _tokenLeave[0] = keccak256(bytes.concat(keccak256(abi.encode(1, EARTH))));
        bytes32 tokenRoot = merkle.getRoot(_tokenLeave);
        bytes32[] memory tokenProof = merkle.getProof(_tokenLeave, 0);

        vm.startPrank(owner);
        ipass.setSaleConfig(true, false, false, false);
        ipass.setMerkleRoot(freeMintRoot, FREE_MINT);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.freeMint(freeMintProof, tokenProof, EARTH);
        vm.expectRevert(IPass.AlreadyClaimed.selector);
        ipass.freeMint(freeMintProof, tokenProof, EARTH);
        vm.stopPrank();
    }

    function test_RevertFreeMintWithInvalidProof(
        bytes32[] memory _freeMintLeave,
        bytes32[] memory _tokenLeave,
        uint256 node
    ) public {
        vm.assume(_freeMintLeave.length > 1);
        vm.assume(_tokenLeave.length > 1);
        vm.assume(node < _freeMintLeave.length);
        vm.assume(node < _tokenLeave.length);
        // free mint proof
        bytes32 freeMintRoot = merkle.getRoot(_freeMintLeave);
        bytes32[] memory freeMintProof = merkle.getProof(_freeMintLeave, node);

        // token proof
        bytes32 tokenRoot = merkle.getRoot(_tokenLeave);
        bytes32[] memory tokenProof = merkle.getProof(_tokenLeave, node);

        vm.startPrank(owner);
        ipass.setSaleConfig(true, false, false, false);
        ipass.setMerkleRoot(freeMintRoot, FREE_MINT);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        changePrank(alice);
        vm.expectRevert(IPass.InvalidProof.selector);
        ipass.freeMint(freeMintProof, tokenProof, EARTH);
        vm.stopPrank();
    }

    function test_RevertFreeMintWithMintExceedsLimit(
        bytes32[] memory _freeMintLeave,
        bytes32[] memory _tokenLeave,
        uint256 node
    ) public {
        vm.assume(_freeMintLeave.length > 1);
        vm.assume(_tokenLeave.length > 1);
        vm.assume(node < _freeMintLeave.length);
        vm.assume(node < _tokenLeave.length);
        // free mint proof
        _freeMintLeave[node] = keccak256(bytes.concat(keccak256(abi.encode(alice))));
        bytes32 freeMintRoot = merkle.getRoot(_freeMintLeave);
        bytes32[] memory freeMintProof = merkle.getProof(_freeMintLeave, node);

        // token proof
        bytes32 tokenRoot = merkle.getRoot(_tokenLeave);
        bytes32[] memory tokenProof = merkle.getProof(_tokenLeave, node);

        vm.startPrank(owner);
        ipass.setSaleConfig(true, false, false, false);
        ipass.setMerkleRoot(freeMintRoot, FREE_MINT);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        ipass.setMaxSupply(0);
        changePrank(alice);
        vm.expectRevert(IPass.MintExceedsLimit.selector);
        ipass.freeMint(freeMintProof, tokenProof, EARTH);
        vm.stopPrank();
    }

    function testWhitelistMint(
        bytes32[] memory _whiteListLeave,
        bytes32[] memory _tokenLeave,
        uint256 node
    ) public {
        vm.assume(_whiteListLeave.length > 1);
        vm.assume(_tokenLeave.length > 1);
        vm.assume(node < _whiteListLeave.length);
        // white list proof
        _whiteListLeave[node] = keccak256(bytes.concat(keccak256(abi.encode(alice))));
        bytes32 whiteListRoot = merkle.getRoot(_whiteListLeave);
        bytes32[] memory whiteListProof = merkle.getProof(_whiteListLeave, node);

        // token proof
        _tokenLeave[0] = keccak256(bytes.concat(keccak256(abi.encode(1, EARTH))));
        bytes32 tokenRoot = merkle.getRoot(_tokenLeave);
        bytes32[] memory tokenProof = merkle.getProof(_tokenLeave, 0);

        vm.startPrank(owner);
        ipass.setSaleConfig(false, true, false, false);
        ipass.setMerkleRoot(whiteListRoot, WHITELIST);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.whitelistMint{value: 0.05 ether}(whiteListProof, tokenProof, EARTH);
        vm.stopPrank();
        assertEq(ipass.balanceOf(alice), 1);
    }

    function test_RevertWhitelistMintWithMintNotStart(
        bytes32[] memory _whiteListLeave,
        bytes32[] memory _tokenLeave,
        uint256 node
    ) public {
        vm.assume(_whiteListLeave.length > 1);
        vm.assume(_tokenLeave.length > 1);
        vm.assume(node < _whiteListLeave.length);
        vm.assume(node < _tokenLeave.length);
        // white list proof
        bytes32 whiteListRoot = merkle.getRoot(_whiteListLeave);
        bytes32[] memory whiteListProof = merkle.getProof(_whiteListLeave, node);

        // token proof
        bytes32[] memory tokenProof = merkle.getProof(_tokenLeave, node);

        deal(alice, 1 ether);
        vm.startPrank(alice);
        vm.expectRevert(IPass.MintNotStart.selector);
        ipass.whitelistMint{value: 0.05 ether}(whiteListProof, tokenProof, EARTH);

        changePrank(owner);
        ipass.setMerkleRoot(whiteListRoot, WHITELIST);
        changePrank(alice);
        vm.expectRevert(IPass.MintNotStart.selector);
        ipass.whitelistMint{value: 0.05 ether}(whiteListProof, tokenProof, EARTH);
        vm.stopPrank();
    }

    function test_RevertWhitelistMintWithAlreadyClaimed(
        bytes32[] memory _whiteListLeave,
        bytes32[] memory _tokenLeave,
        uint256 node
    ) public {
        vm.assume(_whiteListLeave.length > 1);
        vm.assume(_tokenLeave.length > 1);
        vm.assume(node < _whiteListLeave.length);
        // white list proof
        _whiteListLeave[node] = keccak256(bytes.concat(keccak256(abi.encode(alice))));
        bytes32 whiteListRoot = merkle.getRoot(_whiteListLeave);
        bytes32[] memory whiteListProof = merkle.getProof(_whiteListLeave, node);

        // token proof
        _tokenLeave[0] = keccak256(bytes.concat(keccak256(abi.encode(1, EARTH))));
        bytes32 tokenRoot = merkle.getRoot(_tokenLeave);
        bytes32[] memory tokenProof = merkle.getProof(_tokenLeave, 0);

        vm.startPrank(owner);
        ipass.setSaleConfig(false, true, false, false);
        ipass.setMerkleRoot(whiteListRoot, WHITELIST);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.whitelistMint{value: 0.05 ether}(whiteListProof, tokenProof, EARTH);
        vm.expectRevert(IPass.AlreadyClaimed.selector);
        ipass.whitelistMint{value: 0.05 ether}(whiteListProof, tokenProof, EARTH);
        vm.stopPrank();
    }

    function test_RevertWhitelistMintWithInvalidProof(
        bytes32[] memory _whiteListLeave,
        bytes32[] memory _tokenLeave,
        uint256 node
    ) public {
        vm.assume(_whiteListLeave.length > 1);
        vm.assume(_tokenLeave.length > 1);
        vm.assume(node < _whiteListLeave.length);
        vm.assume(node < _tokenLeave.length);
        // white list proof
        bytes32 whiteListRoot = merkle.getRoot(_whiteListLeave);
        bytes32[] memory whiteListProof = merkle.getProof(_whiteListLeave, node);

        // token proof
        bytes32 tokenRoot = merkle.getRoot(_tokenLeave);
        bytes32[] memory tokenProof = merkle.getProof(_tokenLeave, node);

        vm.startPrank(owner);
        ipass.setSaleConfig(false, true, false, false);
        ipass.setMerkleRoot(whiteListRoot, WHITELIST);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.InvalidProof.selector);
        ipass.whitelistMint{value: 0.05 ether}(whiteListProof, tokenProof, EARTH);
        vm.stopPrank();
    }

    function test_RevertWhitelistMintWithInsufficientEthers(
        bytes32[] memory _whiteListLeave,
        bytes32[] memory _tokenLeave,
        uint256 node
    ) public {
        vm.assume(_whiteListLeave.length > 1);
        vm.assume(_tokenLeave.length > 1);
        vm.assume(node < _whiteListLeave.length);
        // white list proof
        _whiteListLeave[node] = keccak256(bytes.concat(keccak256(abi.encode(alice))));
        bytes32 whiteListRoot = merkle.getRoot(_whiteListLeave);
        bytes32[] memory whiteListProof = merkle.getProof(_whiteListLeave, node);

        // token proof
        _tokenLeave[0] = keccak256(bytes.concat(keccak256(abi.encode(1, EARTH))));
        bytes32 tokenRoot = merkle.getRoot(_tokenLeave);
        bytes32[] memory tokenProof = merkle.getProof(_tokenLeave, 0);

        vm.startPrank(owner);
        ipass.setSaleConfig(false, true, false, false);
        ipass.setMerkleRoot(whiteListRoot, WHITELIST);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.InsufficientEthers.selector);
        ipass.whitelistMint{value: 0.04 ether}(whiteListProof, tokenProof, EARTH);
        vm.stopPrank();
    }

    function test_RevertWhitelistMintWithMintExceedsLimit(
        bytes32[] memory _whiteListLeave,
        bytes32[] memory _tokenLeave,
        uint256 node
    ) public {
        vm.assume(_whiteListLeave.length > 1);
        vm.assume(_tokenLeave.length > 1);
        vm.assume(node < _whiteListLeave.length);
        // white list proof
        _whiteListLeave[node] = keccak256(bytes.concat(keccak256(abi.encode(alice))));
        bytes32 whiteListRoot = merkle.getRoot(_whiteListLeave);
        bytes32[] memory whiteListProof = merkle.getProof(_whiteListLeave, node);

        // token proof
        _tokenLeave[0] = keccak256(bytes.concat(keccak256(abi.encode(1, EARTH))));
        bytes32 tokenRoot = merkle.getRoot(_tokenLeave);
        bytes32[] memory tokenProof = merkle.getProof(_tokenLeave, 0);

        vm.startPrank(owner);
        ipass.setSaleConfig(false, true, false, false);
        ipass.setMerkleRoot(whiteListRoot, WHITELIST);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        ipass.setMaxSupply(0);
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.MintExceedsLimit.selector);
        ipass.whitelistMint{value: 0.05 ether}(whiteListProof, tokenProof, EARTH);
        vm.stopPrank();
    }

    function testPublicMint(bytes32[] memory _tokenLeave) public {
        vm.assume(_tokenLeave.length > 3);
        // token proof
        _tokenLeave[0] = keccak256(bytes.concat(keccak256(abi.encode(1, EARTH))));
        _tokenLeave[1] = keccak256(bytes.concat(keccak256(abi.encode(2, OCEAN))));
        _tokenLeave[2] = keccak256(bytes.concat(keccak256(abi.encode(3, EARTH))));
        bytes32 tokenRoot = merkle.getRoot(_tokenLeave);

        bytes32[][] memory tokenProofs = new bytes32[][](3);
        tokenProofs[0] = merkle.getProof(_tokenLeave, 0);
        tokenProofs[1] = merkle.getProof(_tokenLeave, 1);
        tokenProofs[2] = merkle.getProof(_tokenLeave, 2);

        string[] memory types = new string[](3);
        types[0] = EARTH;
        types[1] = OCEAN;
        types[2] = EARTH;

        vm.startPrank(owner);
        ipass.setSaleConfig(false, false, true, false);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.publicMint{value: 0.3 ether}(3, tokenProofs, types);
        vm.stopPrank();
        assertEq(ipass.balanceOf(alice), 3);
    }

    function test_RevertPublicMintWithMintNotStart(bytes32[] memory _tokenLeave) public {
        vm.assume(_tokenLeave.length > 3);
        // token proof
        bytes32 tokenRoot = merkle.getRoot(_tokenLeave);
        bytes32[] memory tokenProof1 = merkle.getProof(_tokenLeave, 0);
        bytes32[] memory tokenProof2 = merkle.getProof(_tokenLeave, 1);
        bytes32[] memory tokenProof3 = merkle.getProof(_tokenLeave, 2);
        bytes32[][] memory tokenProofs = new bytes32[][](3);
        tokenProofs[0] = tokenProof1;
        tokenProofs[1] = tokenProof2;
        tokenProofs[2] = tokenProof3;

        string[] memory types = new string[](3);
        types[0] = EARTH;
        types[1] = OCEAN;
        types[2] = EARTH;

        vm.startPrank(owner);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.MintNotStart.selector);
        ipass.publicMint{value: 0.3 ether}(3, tokenProofs, types);
        vm.stopPrank();
    }

    function test_RevertPublicMintWithInsufficientEthers(bytes32[] memory _tokenLeave) public {
        vm.assume(_tokenLeave.length > 3);
        // token proof
        _tokenLeave[0] = keccak256(bytes.concat(keccak256(abi.encode(1, EARTH))));
        _tokenLeave[1] = keccak256(bytes.concat(keccak256(abi.encode(2, OCEAN))));
        _tokenLeave[2] = keccak256(bytes.concat(keccak256(abi.encode(3, EARTH))));
        bytes32 tokenRoot = merkle.getRoot(_tokenLeave);

        bytes32[][] memory tokenProofs = new bytes32[][](3);
        tokenProofs[0] = merkle.getProof(_tokenLeave, 0);
        tokenProofs[1] = merkle.getProof(_tokenLeave, 1);
        tokenProofs[2] = merkle.getProof(_tokenLeave, 2);

        string[] memory types = new string[](3);
        types[0] = EARTH;
        types[1] = OCEAN;
        types[2] = EARTH;

        vm.startPrank(owner);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        ipass.setSaleConfig(false, false, true, false);
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.InsufficientEthers.selector);
        ipass.publicMint{value: 0.2 ether}(3, tokenProofs, types);
        vm.stopPrank();
    }

    function test_RevertPublicMintWithMintExceedsLimit(bytes32[] memory _tokenLeave) public {
        vm.assume(_tokenLeave.length > 3);
        // token proof
        _tokenLeave[0] = keccak256(bytes.concat(keccak256(abi.encode(1, EARTH))));
        _tokenLeave[1] = keccak256(bytes.concat(keccak256(abi.encode(2, OCEAN))));
        _tokenLeave[2] = keccak256(bytes.concat(keccak256(abi.encode(3, EARTH))));
        bytes32 tokenRoot = merkle.getRoot(_tokenLeave);

        bytes32[][] memory tokenProofs = new bytes32[][](3);
        tokenProofs[0] = merkle.getProof(_tokenLeave, 0);
        tokenProofs[1] = merkle.getProof(_tokenLeave, 1);
        tokenProofs[2] = merkle.getProof(_tokenLeave, 2);

        string[] memory types = new string[](3);
        types[0] = EARTH;
        types[1] = OCEAN;
        types[2] = EARTH;

        vm.startPrank(owner);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        ipass.setSaleConfig(false, false, true, false);
        ipass.setMaxSupply(0);
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.MintExceedsLimit.selector);
        ipass.publicMint{value: 0.3 ether}(3, tokenProofs, types);
        changePrank(owner);
        ipass.setMaxSupply(500);
        changePrank(alice);
        vm.expectRevert(IPass.MintExceedsLimit.selector);
        ipass.publicMint{value: 0.5 ether}(5, tokenProofs, types);
        vm.stopPrank();
    }

    // oz/merkle-tree hash pair func is not the same as murkey/Merkle
    // use dummy data to test instead
    function testPremiumMint() public {
        // token root
        bytes32 root = 0x4ed6fa3d623b003df23ff953a1ddd60616ca26c43b06ad2ff06b6a139ee2fe2f;
        
        // token proof
        bytes32[] memory tokenProof1 = new bytes32[](3);
        tokenProof1[0] = 0x6f5a07349193d4faac44fd1ad6e052fe3cb9dd746c454b73cba5ebc975a6e7bb;
        tokenProof1[1] = 0xbe255fc0017f66c041158214c95717b5c3bfb631a9fefcd7e559a11d14cd9257;
        tokenProof1[2] = 0x9fb575fc6758f041f5002e350be6a79058626fe3f9dabb9ea2d9ea355c509958;
        
        bytes32[] memory tokenProof2 = new bytes32[](2);
        tokenProof2[0] = 0xb814bb74808efc8cd4df64b5dd7489c7e074dd276676ea3e585de0f301be55ae;
        tokenProof2[1] = 0x9fb575fc6758f041f5002e350be6a79058626fe3f9dabb9ea2d9ea355c509958;

        bytes32[][] memory tokenProofs = new bytes32[][](2);
        tokenProofs[0] = tokenProof1;
        tokenProofs[1] = tokenProof2;

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

        string[] memory types = new string[](2);
        types[0] = EARTH;
        types[1] = OCEAN;

        vm.startPrank(owner);
        // public sale & premium mint
        ipass.setSaleConfig(false, false, true, true);
        ipass.setMerkleRoot(root, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.publicMint{value: 0.2 ether}(2, tokenProofs, types);
        ipass.premiumMint(multiProof, flags, tokens, types);
        assertEq(ipass.balanceOf(alice), 1);
        vm.stopPrank();
    }

    function test_RevertPremiumMintWithNotOwner() public {
        // token root
        bytes32 root = 0x4ed6fa3d623b003df23ff953a1ddd60616ca26c43b06ad2ff06b6a139ee2fe2f;
        
        // token proof
        bytes32[] memory tokenProof1 = new bytes32[](3);
        tokenProof1[0] = 0x6f5a07349193d4faac44fd1ad6e052fe3cb9dd746c454b73cba5ebc975a6e7bb;
        tokenProof1[1] = 0xbe255fc0017f66c041158214c95717b5c3bfb631a9fefcd7e559a11d14cd9257;
        tokenProof1[2] = 0x9fb575fc6758f041f5002e350be6a79058626fe3f9dabb9ea2d9ea355c509958;
        
        bytes32[] memory tokenProof2 = new bytes32[](2);
        tokenProof2[0] = 0xb814bb74808efc8cd4df64b5dd7489c7e074dd276676ea3e585de0f301be55ae;
        tokenProof2[1] = 0x9fb575fc6758f041f5002e350be6a79058626fe3f9dabb9ea2d9ea355c509958;

        bytes32[][] memory tokenProofs = new bytes32[][](2);
        tokenProofs[0] = tokenProof1;
        tokenProofs[1] = tokenProof2;

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

        string[] memory types = new string[](2);
        types[0] = EARTH;
        types[1] = OCEAN;

        vm.startPrank(owner);
        ipass.setSaleConfig(false, false, true, true);
        ipass.setMerkleRoot(root, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.publicMint{value: 0.2 ether}(2, tokenProofs, types);
        changePrank(bob);
        vm.expectRevert(IPass.NotOwner.selector);
        ipass.premiumMint(multiProof, flags, tokens, types);
        vm.stopPrank();
    }

    function testVerifyToken(bytes32[] memory _tokenLeave) public {
        vm.assume(_tokenLeave.length > 3);
        // token proof
        _tokenLeave[0] = keccak256(bytes.concat(keccak256(abi.encode(1, EARTH))));
        bytes32 tokenRoot = merkle.getRoot(_tokenLeave);
        bytes32[][] memory tokenProofs = new bytes32[][](1);
        tokenProofs[0] = merkle.getProof(_tokenLeave, 0);

        string[] memory types = new string[](1);
        types[0] = EARTH;

        vm.startPrank(owner);
        ipass.setSaleConfig(false, false, true, false);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.publicMint{value: 0.1 ether}(1, tokenProofs, types);
        vm.stopPrank();
        bool result = ipass.verifyToken(tokenProofs[0], 1, EARTH, alice);
        assertTrue(result);
    }

    function testSetMetadata(bytes32[] memory _tokenLeave) public {
        vm.assume(_tokenLeave.length > 3);

        IPass.Metadata memory metadata = IPass.Metadata({
            imgUrl: "https://test.png",
            tokenNamePrefix: "TEST",
            description: "Test",
            properties: '{"Type":"Utility","Element":"Earth"}'
        });

        // token proof
        _tokenLeave[0] = keccak256(bytes.concat(keccak256(abi.encode(1, EARTH))));
        bytes32 tokenRoot = merkle.getRoot(_tokenLeave);

        bytes32[][] memory tokenProofs = new bytes32[][](1);
        tokenProofs[0] = merkle.getProof(_tokenLeave, 0);

        string[] memory types = new string[](1);
        types[0] = EARTH;

        vm.startPrank(owner);
        ipass.setMetadata(EARTH, metadata);
        ipass.setSaleConfig(false, false, true, false);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.publicMint{value: 0.3 ether}(1, tokenProofs, types);
        emit log_named_string("Token URI", ipass.tokenURI(1));
    }
}