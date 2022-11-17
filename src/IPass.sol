// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPass {
    error AlreadyClaimed();
    error EthersTransferErr();
    error InsufficientEthers();
    error InvalidProof();
    error InvalidSignature();
    error MintExceedsLimit();
    error MintNotStart();
    error NotOwner();
    error NullAddress();
    error OnlyFirstStagedParticipant();
    error SaleTimeNotReach();

    enum Stage {
        Free,
        Whitelist,
        Public,
        Premium
    }

    struct SaleConfig {
        bool isFreeMint;
        bool isWhitelistMint;
        bool isPublicMint;
    }

    struct Trees {
        bytes32 freemintMerkleRoot;
        bytes32 whitelistMerkleRoot;
        bytes32 tokenMerkleRoot;
    }

    struct MintRecord {
        bool freemintClaimed;
        bool whitelistClaimed;
        uint256 publicMinted;
    }

    function freeMint(bytes32[] calldata _proof) external;

    function whitelistMint(bytes32[] calldata _proof) external payable;

    function publicMint(uint256 _quantity) external payable;

    function premiumMint(
        bytes32[] calldata _proof,
        bool[] calldata _proofFlags,
        bytes32[] memory _leaves,
        uint256 _earthToken,
        uint256 _marineToken
    ) external;

    function verifyToken(
        bytes32[] calldata _proof,
        bytes32 _leaf,
        address _addr,
        uint256 _tokenId
    ) external view returns (bool);
}
