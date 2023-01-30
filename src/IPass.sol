// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPass {
    error AlreadyClaimed();
    error EthersTransferErr();
    error InsufficientEthers();
    error InvalidProof();
    error InvalidStage();
    error LengthMismatch();
    error MintExceedsLimit();
    error MintNotStart();
    error WrongPremiumTokenIds();

    enum Stage {
        Free,
        Whitelist,
        Public,
        Premium
    }

    event UpdateSaleStage(Stage _stage);
    event UpdateBaseUri(string _uri);
    event UpdateMerkleRoot(bytes32 indexed _name, bytes32 _root);
    event UpdatePremiumMint(bool _isPremiumMint);
    event Mint(address indexed _to, Stage indexed _stage, uint256 _tokenId);

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
     * @notice Owner sets the current sale stage
     */ 
    function setSaleStage(Stage _stage) external;

    /**
     * @notice Owner sets the merkle root for free mint, whitelist mint, tokens
     * @param _root The merkle root
     * @param _name The name for cooresponding root
     */
    function setMerkleRoot(bytes32 _root, bytes32 _name) external;

    /**
     * @notice Owner withdraw ethers to the project party's multisig vault
     */
    function withdraw() external;

    /**
     * =================== Mint ===================
     */

    /**
     * @notice Get the lastest minted tokenId
     * 
     */
    function currentTokenId() external view returns (uint256);

    /**
     * @notice User who is on free mint list can mint the pass
     * @param _proof The merkle proof of the free mint merkle tree
     */
    function freeMint(bytes32[] calldata _proof) external;

    /**
     * @notice User who is on white list can mint the pass
     * @param _proof The merkle proof of the white mint merkle tree
     */
    function whitelistMint(bytes32[] calldata _proof) external payable;

    /**
     * @notice User can mint 3 pass at most
     * @param _quantity The quantity that user want to mint
     */
    function publicMint(uint256 _quantity) external payable;

    /**
     * @notice User mints premium pass by burning their holding passes,
     *  one for earth, one for ocean
     * @param _proofs The proofs of the tokens
     * @param _tokens The tokens that user is holding
     */
    function premiumMint(bytes32[][] calldata _proofs, uint256[] calldata _tokens) external;

    /**
     * @notice This function is for the future projects use
     */
    function verifyToken(bytes32[] calldata _proof, uint256 _tokenId, bytes calldata _type, address _owner) external view returns (bool);
}
