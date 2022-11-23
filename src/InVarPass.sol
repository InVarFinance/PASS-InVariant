// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "ERC721A/extensions/ERC721AQueryable.sol";
import "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";
import "./IPass.sol";

contract InVarPass is ERC721AQueryable, IPass, Ownable, ReentrancyGuard {
    SaleConfig public saleConfig;
    Trees public trees;

    bytes32 constant FREE_MINT = 0xaca2929d09e74b1bd257acca0d40349ade3291350b31ee1e04b706c764e53859;
    bytes32 constant WHITELIST = 0xc3d232a6c0e2fb343117f17a5ff344a1a84769265318c6d7a8d7d9b2f8bb49e3;
    bytes32 constant TOKEN = 0x1317f51c845ce3bfb7c268e5337a825f12f3d0af9584c2bbfbf4e64e314eaf73;

    uint256 constant WHITELIST_PRICE = 0.05 ether;
    uint256 constant PUBLICSALE_PRICE = 0.08 ether;
    uint256 constant PUBLIC_MINT_QTY = 3;

    address constant MULTISIG = address(0);

    // total supply
    uint256 private _supply;

    // mint records
    mapping(address => MintRecord) public mintRecords;

    bool private _isPremiumStart;

    string private _baseTokenURI;

    event Mint(address indexed _to, Stage indexed _stage, uint256[] _tokenId);

    constructor(
        string memory _name,
        string memory _symbol,
        string memory baseURI,
        uint256 supply
    ) ERC721A(_name, _symbol) {
        _baseTokenURI = baseURI;
        _supply = supply;
    }

    function setSaleConfig(
        bool _isFreeMint,
        bool _isWhitelistMint,
        bool _isPublicMint
    ) external onlyOwner {
        saleConfig = SaleConfig({
            isFreeMint: _isFreeMint,
            isWhitelistMint: _isWhitelistMint,
            isPublicMint: _isPublicMint
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

    function setBaseUri(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function setSupply(uint256 supply) external onlyOwner {
        _supply = supply;
    }

    function setIsPremiumStart(bool _start) external onlyOwner {
        _isPremiumStart = _start;
    }

    function withdraw() external onlyOwner nonReentrant {
        (bool success, ) = payable(MULTISIG).call{value: address(this).balance}("");
        if (!success) revert EthersTransferErr();
    }

    function freeMint(bytes32[] calldata _proof) external {
        if (trees.freemintMerkleRoot == 0 || !saleConfig.isFreeMint) revert SaleTimeNotReach();
        // merkle proof
        // double-hashed value to meet @openzeppelin/merkle-tree hashLeaf func
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender))));
        if (!MerkleProof.verifyCalldata(_proof, trees.freemintMerkleRoot, leaf)) revert InvalidProof();
        if (mintRecords[msg.sender].freemintClaimed) revert AlreadyClaimed();
        // free mint
        if (ERC721A.totalSupply() + 1 > _supply) revert MintExceedsLimit();
        mintRecords[msg.sender].freemintClaimed = true;
        
        uint256[] memory tokenIds = _generateTokenIds();
        _mint(msg.sender, 1);

        emit Mint(msg.sender, Stage.Free, tokenIds);
    }

    function whitelistMint(bytes32[] calldata _proof) external payable nonReentrant {
        if (trees.whitelistMerkleRoot == 0 || !saleConfig.isWhitelistMint) revert SaleTimeNotReach();
        // merkle proof
        // double-hashed value to meet @openzeppelin/merkle-tree hashLeaf func
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender))));
        if (!MerkleProof.verifyCalldata(_proof, trees.whitelistMerkleRoot, leaf)) revert InvalidProof();
        if (mintRecords[msg.sender].whitelistClaimed) revert AlreadyClaimed();
        // whitelist mint
        if (ERC721A.totalSupply() + 1 > _supply) revert MintExceedsLimit();
        mintRecords[msg.sender].whitelistClaimed = true;

        uint256[] memory tokenIds = _generateTokenIds();
        _mint(msg.sender, 1);
        _refundIfOver(WHITELIST_PRICE);

        emit Mint(msg.sender, Stage.Whitelist, tokenIds);
    }

    function publicMint(uint256 _quantity) external payable nonReentrant {
        if (!saleConfig.isPublicMint) revert SaleTimeNotReach();
        if (ERC721A.totalSupply() + _quantity > _supply ||
            PUBLIC_MINT_QTY < mintRecords[msg.sender].publicMinted + _quantity) 
            revert MintExceedsLimit();
        mintRecords[msg.sender].publicMinted += _quantity;
        
        uint256[] memory tokenIds = _generateTokenIds(_quantity);
        _mint(msg.sender, _quantity);
        _refundIfOver(PUBLICSALE_PRICE * _quantity);
        
        emit Mint(msg.sender, Stage.Public, tokenIds);
    }

    function premiumMint(
        bytes32[] calldata _proof,
        bool[] calldata _proofFlags,
        bytes32[] memory _leaves,
        uint256 _earthToken,
        uint256 _marineToken
    ) external {
        if (!_isPremiumStart) revert MintNotStart();
        if (!MerkleProof.multiProofVerifyCalldata(
            _proof,
            _proofFlags,
            trees.tokenMerkleRoot,
            _leaves)) revert InvalidProof();
        if (!(_ownershipOf(_earthToken).addr == msg.sender &&
                _ownershipOf(_marineToken).addr == msg.sender)) revert NotOwner();

        _burn(_earthToken);
        _burn(_marineToken);
        uint256[] memory tokenIds = _generateTokenIds();
        _mint(msg.sender, 1);
        
        emit Mint(msg.sender, Stage.Premium, tokenIds);
    }

    function _refundIfOver(uint256 _price) private {
        if (msg.value < _price) revert InsufficientEthers();
        if (msg.value > _price) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - _price}("");
            if (!success) revert EthersTransferErr();
        }
    }

    function _generateTokenIds() private view returns (uint256[] memory) {
        return _generateTokenIds(1);
    }

    function _generateTokenIds(uint256 _size) private view returns (uint256[] memory) {
        uint256 tokenId = ERC721A._nextTokenId();
        uint256[] memory tokenIds = new uint256[](_size);
        for (uint256 i = 0; i < _size; i++) {
            tokenIds[i] = tokenId;
            tokenId++;
        }
        return tokenIds;
    }

    // for other services to verify the owner of token and the pass type
    function verifyToken(
        bytes32[] calldata _proof,
        bytes calldata _type,
        address _addr,
        uint256 _tokenId
    ) external view returns (bool) {
        string memory passType = abi.decode(_type, (string));
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_tokenId, passType))));
        return (MerkleProof.verifyCalldata(
            _proof,
            trees.tokenMerkleRoot,
            leaf
        ) && explicitOwnershipOf(_tokenId).addr == _addr);
    }

    // override
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }
}
