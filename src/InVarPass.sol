// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "ERC721A/extensions/ERC721AQueryable.sol";
import "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "./IPass.sol";

contract InVarPass is ERC721AQueryable, IPass, Ownable {
    SaleConfig public saleConfig;
    Trees public trees;

    bytes32 constant FREE_MINT = 0xaca2929d09e74b1bd257acca0d40349ade3291350b31ee1e04b706c764e53859;
    bytes32 constant WHITELIST = 0xc3d232a6c0e2fb343117f17a5ff344a1a84769265318c6d7a8d7d9b2f8bb49e3;
    bytes32 constant TOKEN = 0x1317f51c845ce3bfb7c268e5337a825f12f3d0af9584c2bbfbf4e64e314eaf73;

    uint256 constant WHITELIST_PRICE = 0.05 ether;
    uint256 constant PUBLICSALE_PRICE = 0.08 ether;
    uint256 constant PUBLIC_MINT_QTY = 3;

    // total supply
    uint256 private _supply;

    // merkle trees
    mapping(address => bool) public freemintClaimed;
    mapping(address => bool) public whitelistClaimed;

    bool private _isPremiumStart;

    string private _baseTokenURI;

    constructor(string memory _name, string memory _symbol, string memory baseURI, uint256 supply)
        ERC721A(_name, _symbol)
    {
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

    function freeMint(bytes32[] calldata _proof) external {
        if (trees.freemintMerkleRoot == 0 || !saleConfig.isFreeMint) revert SaleTimeNotReach();
        // merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (freemintClaimed[msg.sender]) revert AlreadyClaimed();
        if (!MerkleProof.verifyCalldata(_proof, trees.freemintMerkleRoot, leaf)) revert InvalidProof();
        // free mint
        if (ERC721A.totalSupply() + 1 > _supply) revert MintExceedsLimit();
        freemintClaimed[msg.sender] = true;
        _mint(msg.sender, 1);
    }

    function whitelistMint(bytes32[] calldata _proof) external payable {
        if (trees.whitelistMerkleRoot == 0 || !saleConfig.isWhitelistMint) revert SaleTimeNotReach();
        // merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (whitelistClaimed[msg.sender]) revert AlreadyClaimed();
        if (!MerkleProof.verifyCalldata(_proof, trees.whitelistMerkleRoot, leaf)) revert InvalidProof();
        // whitelist mint
        if (msg.value < WHITELIST_PRICE) revert InsufficientEthers();
        if (ERC721A.totalSupply() + 1 > _supply) revert MintExceedsLimit();
        whitelistClaimed[msg.sender] = true;
        _mint(msg.sender, 1);
    }

    function publicMint(uint256 _quantity) external payable {
        if (!saleConfig.isPublicMint) revert SaleTimeNotReach();
        if (msg.value < PUBLICSALE_PRICE * _quantity) revert InsufficientEthers();
        if (ERC721A.totalSupply() + _quantity > _supply) revert MintExceedsLimit();
        if (PUBLIC_MINT_QTY < _quantity) revert MintExceedsLimit();
        _mint(msg.sender, _quantity);
    }

    function premiumMint(bytes32[] calldata _proof, bool[] calldata _proofFlags, bytes32[] memory _leaves,
        uint256 _earthToken, uint256 _marineToken) external {
        if (!_isPremiumStart) revert MintNotStart();
        if (!MerkleProof.multiProofVerifyCalldata(_proof, _proofFlags, trees.tokenMerkleRoot, _leaves)) revert InvalidProof();
        if (!(_ownershipOf(_earthToken).addr == msg.sender && 
            _ownershipOf(_marineToken).addr == msg.sender)) revert NotOwner();
        
        _burn(_earthToken);
        _burn(_marineToken);
        _mint(msg.sender, 1);
    }

    // for other services to verify the owner of token and the pass type
    function verifyToken(bytes32[] calldata _proof, bytes32 _leaf,
        address _addr, uint256 _tokenId) external view returns (bool) {
        return (MerkleProof.verifyCalldata(_proof, trees.tokenMerkleRoot, _leaf) &&
        _ownershipOf(_tokenId).addr == _addr);
    }

    // override
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }
}
