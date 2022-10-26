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

    // for sky mint use
    address private _signatureAddress = address(0);

    // merkle tree
    bytes32 public _merkleRoot;
    mapping(address => bool) public whitelistCalimed;

    mapping(uint256 => Type) private _tokenTypes;

    bool private _skyMintStart;

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

    function setSkyMintStart(bool _start) external onlyOwner {
        _skyMintStart = _start;
    }

    function freeMint(uint256 _quantity) external {
        uint256 _saleStartTime = uint256(saleConfig.freemintSaleStartTime);
        if (block.timestamp < _saleStartTime || _saleStartTime == 0) revert SaleTimeNotReach();
        // todo: only 1st staged user(private sale, white list sale, public sale)
        if (IERC1155(RE_NFT).balanceOf(msg.sender, 1) < 0) revert OnlyReOwner();
        if (ERC721A.totalSupply() + _quantity > _supply) revert MintExceedsLimit();
        _mint(msg.sender, _quantity);
    }

    function whitelistMint(bytes32[] calldata merkleProof) external payable {
        if (_merkleRoot == 0) revert SaleTimeNotReach();
        // merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (whitelistCalimed[msg.sender]) revert AlreadyClaimed();
        if (!MerkleProof.verify(merkleProof, _merkleRoot, leaf)) revert InvalidProof();
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

    function skyMint(uint256 earthToken, uint256 oceanToken) external {
        // todo: verify signature before mint

        _mint(msg.sender, 1);
    }

    // override
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
}
