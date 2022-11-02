// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPass {
    error AlreadyClaimed();
    error OnlyFirstStagedParticipant();
    error InsufficientEthers();
    error MintExceedsLimit();
    error SaleTimeNotReach();
    error NotOwner();
    error NullAddress();
    error InvalidProof();
    error InvalidSignature();
    error MintNotStart();

    struct SaleConfig{
        bool isFreeMint;
        bool isWhitelistMint;
        bool isPublicMint;
    }

    struct Trees{
        bytes32 freemintMerkleRoot;
        bytes32 whitelistMerkleRoot;
        bytes32 tokenMerkleRoot;
    }

    function freeMint(bytes32[] calldata _proof) external;
    function whitelistMint(bytes32[] calldata _proof) external payable;
    function publicMint(uint256 _quantity) external payable;
    function premiumMint(bytes32[] calldata _proof, bool[] calldata _proofFlags, bytes32[] memory _leaves,
        uint256 _earthToken, uint256 _marineToken) external;
}