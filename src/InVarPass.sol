// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./IPass.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";

import "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import "openzeppelin-contracts/utils/Base64.sol";
import "openzeppelin-contracts/utils/Strings.sol";
import "openzeppelin-contracts/utils/Counters.sol";

contract InVarPass is ERC721Enumerable, IPass, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    SaleConfig public saleConfig;
    Trees public trees;

    bytes32 constant FREE_MINT =
        0xaca2929d09e74b1bd257acca0d40349ade3291350b31ee1e04b706c764e53859;
    bytes32 constant WHITELIST =
        0xc3d232a6c0e2fb343117f17a5ff344a1a84769265318c6d7a8d7d9b2f8bb49e3;
    bytes32 constant TOKEN =
        0x1317f51c845ce3bfb7c268e5337a825f12f3d0af9584c2bbfbf4e64e314eaf73;

    uint256 constant WHITELIST_PRICE = 0.05 ether;
    uint256 constant PUBLICSALE_PRICE = 0.1 ether;
    uint256 constant PUBLIC_MINT_QTY = 3;
    address constant MULTISIG = address(0);

    // total supply
    uint256 private MAX_SUPPLY;
    uint256 private _premiumTokenIds = 10_000;

    // mint records
    mapping(address => MintRecord) public mintRecords;

    /**
     *  =================== Metadata ===================
     */

    mapping(uint256 => bytes32) tokenTypes;
    mapping(bytes32 => Metadata) _metadata;

    function setMetadata(string calldata _type, Metadata memory metadata)
        external
        onlyOwner
    {
        _metadata[keccak256(abi.encodePacked(_type))] = metadata;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        _requireMinted(_tokenId);
        Metadata memory metadata = _metadata[tokenTypes[_tokenId]];
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        abi.encodePacked(
                            '{"name":"',
                            _tokenName(metadata.tokenNamePrefix, _tokenId),
                            '","description":"',
                            metadata.description,
                            '","external_url":"https://app.invar.finance/sftdemo"'
                            ',"image":"',
                            metadata.imgUrl,
                            '","properties":',
                            metadata.properties,
                            "}"
                        )
                    )
                )
            );
    }

    function _tokenName(string memory prefix_, uint256 tokenId_)
        internal
        pure
        returns (string memory)
    {
        return string(abi.encodePacked(prefix_, " #", tokenId_.toString()));
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _supply
    ) ERC721(_name, _symbol) {
        MAX_SUPPLY = _supply;
    }

    /**
     *  =================== Owner Operation ===================
     */

    function setSaleConfig(
        bool _isFreeMint,
        bool _isWhitelistMint,
        bool _isPublicMint,
        bool _isPremiumMint
    ) external onlyOwner {
        saleConfig = SaleConfig({
            isFreeMint: _isFreeMint,
            isWhitelistMint: _isWhitelistMint,
            isPublicMint: _isPublicMint,
            isPremiumMint: _isPremiumMint
        });
    }

    function setMerkleRoot(bytes32 _root, bytes32 _name) external onlyOwner {
        if (_name == FREE_MINT) {
            trees.freemintMerkleRoot = _root;
        }
        if (_name == WHITELIST) {
            trees.whitelistMerkleRoot = _root;
        }
        if (_name == TOKEN) {
            trees.tokenMerkleRoot = _root;
        }
    }

    function setMaxSupply(uint256 _supply) external onlyOwner {
        MAX_SUPPLY = _supply;
    }

    function withdraw() external onlyOwner nonReentrant {
        (bool success, ) = payable(MULTISIG).call{value: address(this).balance}(
            ""
        );
        if (!success) revert EthersTransferErr();
    }

    /**
     * =================== Mint ===================
     */

    function freeMint(
        bytes32[] calldata _proof,
        bytes32[] calldata _tokenProof,
        string calldata _type
    ) external {
        if (trees.freemintMerkleRoot == 0 || !saleConfig.isFreeMint)
            revert MintNotStart();
        // merkle proof
        // double-hashed value to meet @openzeppelin/merkle-tree hashLeaf func
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(msg.sender)))
        );
        if (!MerkleProof.verifyCalldata(_proof, trees.freemintMerkleRoot, leaf))
            revert InvalidProof();
        if (mintRecords[msg.sender].freemintClaimed) revert AlreadyClaimed();
        // free mint
        uint256 tokenId = _generateTokenId();
        mintRecords[msg.sender].freemintClaimed = true;
        _safeMint(msg.sender, tokenId);
        _setTokenType(_tokenProof, tokenId, _type, msg.sender);

        emit Mint(msg.sender, Stage.Free, tokenId);
    }

    function whitelistMint(
        bytes32[] calldata _proof,
        bytes32[] calldata _tokenProof,
        string calldata _type
    ) external payable nonReentrant {
        if (trees.whitelistMerkleRoot == 0 || !saleConfig.isWhitelistMint)
            revert MintNotStart();
        // merkle proof
        // double-hashed value to meet @openzeppelin/merkle-tree hashLeaf func
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(msg.sender)))
        );
        if (
            !MerkleProof.verifyCalldata(_proof, trees.whitelistMerkleRoot, leaf)
        ) revert InvalidProof();
        if (mintRecords[msg.sender].whitelistClaimed) revert AlreadyClaimed();
        // whitelist mint
        uint256 tokenId = _generateTokenId();
        mintRecords[msg.sender].whitelistClaimed = true;
        _safeMint(msg.sender, tokenId);
        _setTokenType(_tokenProof, tokenId, _type, msg.sender);
        _refundIfOver(WHITELIST_PRICE);

        emit Mint(msg.sender, Stage.Whitelist, tokenId);
    }

    function publicMint(
        uint256 _quantity,
        bytes32[] calldata _tokenProof,
        string[] calldata _types
    ) external payable nonReentrant {
        if (!saleConfig.isPublicMint) revert MintNotStart();
        if (PUBLIC_MINT_QTY < mintRecords[msg.sender].publicMinted + _quantity)
            revert MintExceedsLimit();
        mintRecords[msg.sender].publicMinted += uint8(_quantity);

        for (uint256 i = 0; i < _quantity; i++) {
            uint256 tokenId = _generateTokenId();
            _safeMint(msg.sender, _quantity);
            _setTokenType(_tokenProof, tokenId, _types[i], msg.sender);

            emit Mint(msg.sender, Stage.Public, tokenId);
        }

        _refundIfOver(PUBLICSALE_PRICE * _quantity);
    }

    function _setTokenType(
        bytes32[] calldata _proof,
        uint256 _tokenId,
        string calldata _type,
        address _owner
    ) internal {
        // on-chain metadata setup
        if (!verifyToken(_proof, _tokenId, _type, _owner))
            revert InvalidProof();
        tokenTypes[_tokenId] = keccak256(abi.encodePacked(_type));
    }

    function premiumMint(
        bytes32[] calldata _proof,
        bool[] calldata _proofFlags,
        bytes32[] memory _leaves,
        uint256 _earthToken,
        uint256 _oceanToken,
        string calldata _type
    ) external {
        if (!saleConfig.isPremiumMint) revert MintNotStart();
        // leaves: earth, ocean, sky
        if (
            !MerkleProof.multiProofVerifyCalldata(
                _proof,
                _proofFlags,
                trees.tokenMerkleRoot,
                _leaves
            )
        ) revert InvalidProof();
        if (
            !(ownerOf(_earthToken) == msg.sender &&
                ownerOf(_oceanToken) == msg.sender)
        ) revert NotOwner();

        _burn(_earthToken);
        _burn(_oceanToken);

        uint256 tokenId = _premiumTokenId();
        _safeMint(msg.sender, tokenId);
        tokenTypes[tokenId] = keccak256(abi.encodePacked(_type));

        emit Mint(msg.sender, Stage.Premium, tokenId);
    }

    function _refundIfOver(uint256 _price) private {
        if (msg.value < _price) revert InsufficientEthers();
        if (msg.value > _price) {
            (bool success, ) = payable(msg.sender).call{
                value: msg.value - _price
            }("");
            if (!success) revert EthersTransferErr();
        }
    }

    function _generateTokenId() private view returns (uint256) {
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        if (tokenId == MAX_SUPPLY) revert MintExceedsLimit();
        return tokenId;
    }

    function _premiumTokenId() private view returns (uint256) {
        return _premiumTokenIds + 1;
    }

    // for other services to verify the owner of token and the pass type
    function verifyToken(
        bytes32[] calldata _proof,
        uint256 _tokenId,
        string calldata _type,
        address _owner
    ) public view returns (bool) {
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(_tokenId, _type)))
        );
        return (MerkleProof.verifyCalldata(
            _proof,
            trees.tokenMerkleRoot,
            leaf
        ) && ownerOf(_tokenId) == _owner);
    }
}
