// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC721Enumerable, ERC721} from "openzeppelin-contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IPass} from "./IPass.sol";
import {IPassConstants} from "./IPassConstants.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import {MerkleProof} from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import {Base64} from "openzeppelin-contracts/utils/Base64.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";
import {Counters} from "openzeppelin-contracts/utils/Counters.sol";

contract InVarPass is ERC721Enumerable, IPass, IPassConstants, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    SaleConfig public saleConfig;
    Trees public trees;

    // total supply
    uint256 private MAX_SUPPLY;
    uint256 private _premiumTokenIds;

    // mint records
    mapping(address => MintRecord) public mintRecords;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _supply,
        uint256 _premium
    ) ERC721(_name, _symbol) {
        MAX_SUPPLY = _supply;
        _premiumTokenIds = _premium;
    }

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
                            '","external_url":"https://app.invar.finance/invaria2222"'
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
        (bool success, ) = payable(MULTISIG).call{value: address(this).balance}("");
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
        if (trees.freemintMerkleRoot == 0 || !saleConfig.isFreeMint) revert MintNotStart();
        // merkle proof
        // double-hashed value to meet oz/merkle-tree hashLeaf func
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender))));
        if (!MerkleProof.verifyCalldata(_proof, trees.freemintMerkleRoot, leaf)) revert InvalidProof();
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
        if (trees.whitelistMerkleRoot == 0 || !saleConfig.isWhitelistMint) revert MintNotStart();
        // merkle proof
        // double-hashed value to meet oz/merkle-tree hashLeaf func
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender))));
        if (!MerkleProof.verifyCalldata(_proof, trees.whitelistMerkleRoot, leaf)) revert InvalidProof();
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
        bytes32[][] calldata _tokenProofs,
        string[] calldata _types
    ) external payable nonReentrant {
        if (!saleConfig.isPublicMint) revert MintNotStart();
        if (PUBLIC_MINT_QTY < mintRecords[msg.sender].publicMinted + _quantity) revert MintExceedsLimit();
        mintRecords[msg.sender].publicMinted += uint8(_quantity);

        for (uint256 i = 0; i < _quantity; i++) {
            uint256 tokenId = _generateTokenId();
            _safeMint(msg.sender, tokenId);
            _setTokenType(_tokenProofs[i], tokenId, _types[i], msg.sender);

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
        if (!verifyToken(_proof, _tokenId, _type, _owner)) revert InvalidProof();
        tokenTypes[_tokenId] = keccak256(abi.encodePacked(_type));
    }

    function premiumMint(
        bytes32[] calldata _proof,
        bool[] calldata _proofFlags,
        uint256[] calldata _tokens,
        string[] calldata _types
    ) external {
        if (!saleConfig.isPremiumMint) revert MintNotStart();
        
        uint256 length = _tokens.length;
        if (length != _types.length) revert MismatchLength();
        bytes32[] memory leave = new bytes32[](length);
        for (uint8 i = 0; i < length; i++) {
            if (!(ownerOf(_tokens[i]) == msg.sender)) revert NotOwner();
            leave[i] = keccak256(bytes.concat(keccak256(abi.encode(_tokens[i], _types[i]))));
            _burn(_tokens[i]);
        }

        // leave: earth, ocean
        if (
            !MerkleProof.multiProofVerifyCalldata(
                _proof,
                _proofFlags,
                trees.tokenMerkleRoot,
                leave
            )
        ) revert InvalidProof();

        uint256 tokenId = _getPremiumTokenId();
        _safeMint(msg.sender, tokenId);
        tokenTypes[tokenId] = PREMIUM_TYPE;

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

    function _generateTokenId() private returns (uint256) {
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        if (tokenId >= MAX_SUPPLY) revert MintExceedsLimit();
        return tokenId;
    }

    function _getPremiumTokenId() private view returns (uint256) {
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
