// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "ERC721A/extensions/ERC721AQueryable.sol";
import "openzeppelin-contracts/interfaces/IERC1155.sol";
import "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "./IPass.sol";

contract InVarPass is ERC721AQueryable, IPass, Ownable {

    SaleConfig public saleConfig;

    address constant RE_NFT = 0xCeF98e10D1e80378A9A74Ce074132B66CDD5e88d;
    // mainnet
    // address constant RE_NFT = 0x502818ec5767570F7fdEe5a568443dc792c4496b;

    // total supply
    uint256 private _supply;

    // for premium mint use
    address private _signatureAddress = address(0);

    // merkle tree
    bytes32 public _merkleRoot;
    mapping(address => bool) public whitelistCalimed;

    mapping(address => bool) public freemintClaimed;

    bool private _isPremiumStart;

    string private _baseTokenURI;

    constructor(string memory _name, string memory _symbol, string memory baseURI, uint256 supply)
        ERC721A(_name, _symbol)
    {
        _baseTokenURI = baseURI;
        _supply = supply;
    }

    function setSignatureAddress(address signatureAddress) external onlyOwner {
        if (signatureAddress == address(0)) revert NullAddress();
        _signatureAddress = signatureAddress;
    }

    function setSaleConfig(
        uint32 _freemintSaleStartTime,
        uint32 _publicSaleStartTime,
        uint64 _whitelistPrice,
        uint64 _publicPrice,
        uint8 _publicMintQuantity
    ) external onlyOwner {
        saleConfig = SaleConfig({
            freemintSaleStartTime: _freemintSaleStartTime,
            publicSaleStartTime: _publicSaleStartTime,
            whitelistPrice: _whitelistPrice,
            publicPrice: _publicPrice,
            publicMintQuantity: _publicMintQuantity
        });
    }

    function setMerkleRoot(bytes32 merkleRoot) external onlyOwner {
        _merkleRoot = merkleRoot;
    }

    function setSupply(uint256 supply) external onlyOwner {
        _supply = supply;
    }

    function setIsPremiumStart(bool _start) external onlyOwner {
        _isPremiumStart = _start;
    }

    function freeMint() external {
        uint256 _saleStartTime = uint256(saleConfig.freemintSaleStartTime);
        if (block.timestamp < _saleStartTime || _saleStartTime == 0) revert SaleTimeNotReach();
        // todo: only 1st staged user(private sale, white list sale, public sale)
        if (IERC1155(RE_NFT).balanceOf(msg.sender, 1) < 0) revert OnlyFirstStagedParticipant();
        if (ERC721A.totalSupply() + 1 > _supply) revert MintExceedsLimit();
        if (freemintClaimed[msg.sender]) revert AlreadyClaimed();
        freemintClaimed[msg.sender] = true;
        _mint(msg.sender, 1);
    }

    function whitelistMint(bytes32[] calldata _proof) external payable {
        if (_merkleRoot == 0) revert SaleTimeNotReach();
        // merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (whitelistCalimed[msg.sender]) revert AlreadyClaimed();
        if (!MerkleProof.verify(_proof, _merkleRoot, leaf)) revert InvalidProof();
        whitelistCalimed[msg.sender] = true;
        // whitelist mint
        if (msg.value < saleConfig.whitelistPrice) revert InsufficientEthers();
        if (ERC721A.totalSupply() + 1 > _supply) revert MintExceedsLimit();
        _mint(msg.sender, 1);
    }

    function publicMint(uint256 _quantity) external payable {
        uint256 _saleStartTime = uint256(saleConfig.publicSaleStartTime);
        if (block.timestamp < _saleStartTime || _saleStartTime == 0) revert SaleTimeNotReach();
        if (msg.value < saleConfig.publicPrice) revert InsufficientEthers();
        if (ERC721A.totalSupply() + _quantity > _supply) revert MintExceedsLimit();
        if (saleConfig.publicMintQuantity < _quantity) revert MintExceedsLimit();
        _mint(msg.sender, _quantity);
    }

    function premiumMint(bytes32 _hashMsg, uint8 _v, bytes32 _r, bytes32 _s,
        uint256 _earthToken, uint256 _marineToken) external {
        if (!_isPremiumStart) revert MintNotStart();
        if (!verifySignature(_hashMsg, _v, _r, _s)) revert InvalidSignature();
        if (!(_ownershipOf(_earthToken).addr == msg.sender && 
            _ownershipOf(_marineToken).addr == msg.sender)) revert NotOwner();
        _burn(_earthToken);
        _burn(_marineToken);
        _mint(msg.sender, 1);
    }

    function verifySignature(bytes32 hashMsg, uint8 v, bytes32 r, bytes32 s) internal view returns (bool) {
        return _signatureAddress == ecrecover(hashMsg, v, r, s);
    }

    // override
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }
}
