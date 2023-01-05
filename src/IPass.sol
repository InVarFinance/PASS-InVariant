// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPass {
    error AlreadyClaimed();
    error EthersTransferErr();
    error InsufficientEthers();
    error InvalidProof();
    error MintExceedsLimit();
    error MintNotStart();
    error MismatchLength();
    error NotOwner();

    enum Stage {
        Free,
        Whitelist,
        Public,
        Premium
    }

    event Mint(address indexed _to, Stage indexed _stage, uint256 _tokenId);

    struct Metadata {
        string imgUrl;
        string tokenNamePrefix;
        string description;
        string properties;
    }

    struct SaleConfig {
        bool isFreeMint;
        bool isWhitelistMint;
        bool isPublicMint;
        bool isPremiumMint;
    }

    struct Trees {
        bytes32 freemintMerkleRoot;
        bytes32 whitelistMerkleRoot;
        bytes32 tokenMerkleRoot;
    }

    struct MintRecord {
        bool freemintClaimed;
        bool whitelistClaimed;
        uint8 publicMinted;
    }
    /**
     *  =================== Owner Operation ===================
     */

    /**
     * @notice Owner sets metadata for the pass type,
     *  so metadata is able to fetch on-chain
     * @param _type The pass type
     * @param _metadata The metadata
     */
    function setMetadata(string calldata _type, Metadata memory _metadata) external;

    /**
     * @notice Owner sets the current sale stage
     */ 
    function setSaleConfig(bool _isFreeMint, bool _isWhitelistMint, bool _isPublicMint, bool _isPremiumMint) external;

    /**
     * @notice Owner sets the merkle root for free mint, whitelist mint, tokens
     * @param _root The merkle root
     * @param _name The name for cooresponding root
     */
    function setMerkleRoot(bytes32 _root, bytes32 _name) external;

    /**
     * @notice Owner sets the max supply for the pass
     * @param _supply Total pass supply
     */
    function setMaxSupply(uint256 _supply) external;

    /**
     * @notice Owner withdraw ethers to the project party's multisig vault
     */
    function withdraw() external;

    /**
     * =================== Mint ===================
     */

    /**
     * @notice User who is on free mint list can mint the pass
     * @param _proof The merkle proof of the free mint merkle tree
     * @param _tokenProof The merkle proof of the token merkle tree
     * @param _type The type of the pass
     */
    function freeMint(bytes32[] calldata _proof, bytes32[] calldata _tokenProof, string calldata _type) external;

    /**
     * @notice User who is on white list can mint the pass
     * @param _proof The merkle proof of the white mint merkle tree
     * @param _tokenProof The merkle proof of the token merkle tree
     * @param _type The type of the pass
     */
    function whitelistMint(bytes32[] calldata _proof, bytes32[] calldata _tokenProof, string calldata _type) external payable;

    /**
     * @notice User can mint 3 pass at most
     * @param _quantity The quantity that user want to mint
     * @param _tokenProofs The merkle proofs of the token merkle tree
     * @param _types The types of the passes
     */
    function publicMint(uint256 _quantity, bytes32[][] calldata _tokenProofs, string[] calldata _types) external payable;

    /**
     * @notice User mints premium pass by burning their holding passes,
     *  one for earth, one for ocean
     * @param _proof The multi proof of the token merkle tree
     * @param _proofFlags The proof flags of the token merkle tree
     * @param _tokens The tokens that user is holding
     * @param _types The types of the passes
     */
    function premiumMint(bytes32[] calldata _proof, bool[] calldata _proofFlags, uint256[] calldata _tokens, string[] calldata _types) external;

    /**
     * @notice This function is for the future projects use
     */
    function verifyToken(bytes32[] calldata _proof, uint256 _tokenId, string calldata _type, address _owner) external view returns (bool);
}
