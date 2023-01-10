// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC721Enumerable, ERC721} from "openzeppelin-contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IPass} from "./IPass.sol";
import {IPassConstants} from "./IPassConstants.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import {CantBeEvil, LicenseVersion} from "a16z-contracts/licenses/CantBeEvil.sol";

import {MerkleProof} from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import {Counters} from "openzeppelin-contracts/utils/Counters.sol";

contract InVarPass is ERC721Enumerable, IPass, IPassConstants, Ownable, ReentrancyGuard, CantBeEvil {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    SaleConfig public saleConfig;
    Trees public trees;

    // total supply
    uint256 private MAX_SUPPLY;
    uint256 private _premiumTokenIds;

    // mint records
    mapping(address => MintRecord) public mintRecords;

    string private _baseuri;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _supply,
        uint256 _premium,
        string memory _uri
    ) ERC721(_name, _symbol) CantBeEvil(LicenseVersion.PERSONAL_NO_HATE) {
        MAX_SUPPLY = _supply;
        _premiumTokenIds = _premium;
        _baseuri = _uri;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, CantBeEvil) returns (bool) {
        return super.supportsInterface(interfaceId);
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

    function setBaseUri(string memory _uri) external onlyOwner {
        _baseuri = _uri;
    }

    function setPremium(uint256 _premium) external onlyOwner {
        _premiumTokenIds = _premium;
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

    function freeMint(bytes32[] calldata _proof) external {
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

        emit Mint(msg.sender, Stage.Free, tokenId);
    }

    function whitelistMint(bytes32[] calldata _proof) external payable nonReentrant {
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
        _refundIfOver(WHITELIST_PRICE);

        emit Mint(msg.sender, Stage.Whitelist, tokenId);
    }

    function publicMint(uint256 _quantity) external payable nonReentrant {
        if (!saleConfig.isPublicMint) revert MintNotStart();
        if (PUBLIC_MINT_QTY < mintRecords[msg.sender].publicMinted + _quantity) revert MintExceedsLimit();
        mintRecords[msg.sender].publicMinted += uint8(_quantity);

        for (uint256 i = 0; i < _quantity; i++) {
            uint256 tokenId = _generateTokenId();
            _safeMint(msg.sender, tokenId);
            emit Mint(msg.sender, Stage.Public, tokenId);
        }

        _refundIfOver(PUBLICSALE_PRICE * _quantity);
    }

    function premiumMint(bytes32[] calldata _proof, bool[] calldata _proofFlags, uint256[] calldata _tokens) external {
        if (!saleConfig.isPremiumMint) revert MintNotStart();
        if (ownerOf(_tokens[0]) != msg.sender ||
            ownerOf(_tokens[1]) != msg.sender) revert NotOwner();

        bytes32[] memory leave = new bytes32[](_tokens.length);
        leave[0] = keccak256(bytes.concat(keccak256(abi.encode(_tokens[0], EARTH))));
        leave[1] = keccak256(bytes.concat(keccak256(abi.encode(_tokens[1], OCEAN))));
        _burn(_tokens[0]);
        _burn(_tokens[1]);

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
        bytes calldata _type,
        address _owner
    ) public view returns (bool) {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_tokenId, _type))));
        return (MerkleProof.verifyCalldata(
            _proof,
            trees.tokenMerkleRoot,
            leaf
        ) && ownerOf(_tokenId) == _owner);
    }

    // override
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseuri;
    }
}
