// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {InVarPass} from "../src/InVarPass.sol";
import {IPass} from "../src/IPass.sol";
import {IPassConstants} from "../src/IPassConstants.sol";
import {Merkle} from "murky/Merkle.sol";

contract InVarPassTest is Test, IPassConstants {
    using stdStorage for StdStorage;

    InVarPass internal ipass;
    Merkle internal merkle;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vm.startPrank(owner);
        ipass = new InVarPass("InVarPass", "IVP", 500, "");
        merkle = new Merkle();
        vm.stopPrank();
    }

    function testSetSaleStage() public {
        vm.prank(owner);
        ipass.setSaleStage(IPass.Stage.Whitelist);
        IPass.Stage currentStage = ipass.currentStage();
        assertEq(uint8(currentStage), uint8(IPass.Stage.Whitelist));
    }

    function test_RevertSetSaleStageWithInvalidStage() public {
        vm.prank(owner);
        vm.expectRevert(IPass.InvalidStage.selector);
        ipass.setSaleStage(IPass.Stage.Premium);
    }

    function testFreeMint(bytes32[] memory _freeMintLeave, uint256 node) public {
        vm.assume(_freeMintLeave.length > 1);
        vm.assume(node < _freeMintLeave.length);

        // free mint proof
        _freeMintLeave[node] = keccak256(bytes.concat(keccak256(abi.encode(alice))));
        bytes32 freeMintRoot = merkle.getRoot(_freeMintLeave);
        bytes32[] memory freeMintProof = merkle.getProof(_freeMintLeave, node);

        vm.startPrank(owner);
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
        bytes32[] memory freeMintProof = merkle.getProof(_freeMintLeave, node);

        vm.startPrank(alice);
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
        ipass.setMerkleRoot(freeMintRoot, FREE_MINT);
        setTokenIdToMaxSupply();
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
        ipass.setSaleStage(IPass.Stage.Whitelist);
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
        ipass.setSaleStage(IPass.Stage.Whitelist);
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
        ipass.setSaleStage(IPass.Stage.Whitelist);
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
        ipass.setSaleStage(IPass.Stage.Whitelist);
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
        ipass.setSaleStage(IPass.Stage.Whitelist);
        ipass.setMerkleRoot(whiteListRoot, WHITELIST);
        setTokenIdToMaxSupply();
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.MintExceedsLimit.selector);
        ipass.whitelistMint{value: 0.05 ether}(whiteListProof);
        vm.stopPrank();
    }

    function testPublicMint() public {
        vm.startPrank(owner);
        ipass.setSaleStage(IPass.Stage.Public);
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
        ipass.setSaleStage(IPass.Stage.Public);
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.InsufficientEthers.selector);
        ipass.publicMint{value: 0.2 ether}(3);
        vm.stopPrank();
    }

    function test_RevertPublicMintWithMintExceedsLimit() public {
        vm.startPrank(owner);
        ipass.setSaleStage(IPass.Stage.Public);
        setTokenIdToMaxSupply();
        deal(alice, 1 ether);
        changePrank(alice);
        vm.expectRevert(IPass.MintExceedsLimit.selector);
        ipass.publicMint{value: 0.3 ether}(3);
        changePrank(owner);
        changePrank(alice);
        vm.expectRevert(IPass.MintExceedsLimit.selector);
        ipass.publicMint{value: 0.5 ether}(5);
        vm.stopPrank();
    }

    // oz/merkle-tree hash pair func is not the same as murkey/Merkle
    // use dummy data to test instead
    function testPremiumMint(bytes32[] memory _tokenLeave) public {
        vm.assume(_tokenLeave.length > 2);

        // token proof
        _tokenLeave[0] = keccak256(bytes.concat(keccak256(abi.encode(1, EARTH))));
        _tokenLeave[1] = keccak256(bytes.concat(keccak256(abi.encode(2, OCEAN))));
        bytes32 tokenRoot = merkle.getRoot(_tokenLeave);
        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = merkle.getProof(_tokenLeave, 0);
        proofs[1] = merkle.getProof(_tokenLeave, 1);

        uint256[] memory tokens = new uint256[](2);
        tokens[0] = 1;
        tokens[1] = 2;

        vm.startPrank(owner);
        ipass.setSaleStage(IPass.Stage.Public);
        ipass.setPremiumMint(true);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        // public sale & premium mint
        ipass.publicMint{value: 0.2 ether}(2);
        ipass.premiumMint(proofs, tokens);
        assertEq(ipass.balanceOf(alice), 1);
        vm.stopPrank();
    }

    function test_RevertPremiumMintWithInvalidProof(bytes32[] memory _tokenLeave) public {
        vm.assume(_tokenLeave.length > 2);

        // token proof
        _tokenLeave[0] = keccak256(bytes.concat(keccak256(abi.encode(1, EARTH))));
        _tokenLeave[1] = keccak256(bytes.concat(keccak256(abi.encode(2, OCEAN))));
        bytes32 tokenRoot = merkle.getRoot(_tokenLeave);
        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = merkle.getProof(_tokenLeave, 0);
        proofs[1] = merkle.getProof(_tokenLeave, 0);

        uint256[] memory tokens = new uint256[](2);
        tokens[0] = 1;
        tokens[1] = 2;

        vm.startPrank(owner);
        ipass.setSaleStage(IPass.Stage.Public);
        ipass.setPremiumMint(true);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.publicMint{value: 0.2 ether}(2);
        vm.expectRevert(IPass.InvalidProof.selector);
        ipass.premiumMint(proofs, tokens);
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
        ipass.setSaleStage(IPass.Stage.Public);
        ipass.setPremiumMint(true);
        ipass.setMerkleRoot(tokenRoot, TOKEN);
        deal(alice, 1 ether);
        changePrank(alice);
        ipass.publicMint{value: 0.1 ether}(1);
        vm.stopPrank();
        bool result = ipass.verifyToken(tokenProofs[0], 1, EARTH, alice);
        assertTrue(result);
    }

    function testGetLicenseURI() public {
        string memory license = ipass.getLicenseURI();
        emit log_named_string("License URI", license);
    }

    function setTokenIdToMaxSupply() internal {
        stdstore
            .target(address(ipass))
            .sig(IPass.currentTokenId.selector)
            .checked_write(MAX_SUPPLY);
    }
}