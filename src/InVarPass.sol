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

    // backend fetches the type to return the right metadata of the token id
    function getTypeByToken(uint256 _tokenId) external view returns (uint256) {
        if (!_exists(_tokenId)) revert TypeQueryForNonexistentToken();
        return uint256(_tokenTypes[_tokenId]);
    }

    function freeMint(uint256 _quantity) external {
        uint256 _saleStartTime = uint256(saleConfig.freemintSaleStartTime);
        if (block.timestamp < _saleStartTime || _saleStartTime == 0) revert SaleTimeNotReach();
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
        if (!_skyMintStart) revert MintNotStart();
        
        if (
            !ERC721A._exists(earthToken) || 
            !ERC721A._exists(oceanToken)
        ) revert MintSkyQueryForNonexistentToken();

        if (
            _tokenTypes[earthToken] != Type.Earth ||
            _tokenTypes[oceanToken] != Type.Ocean
        ) revert TypeError();

        if (
            ERC721A.ownerOf(earthToken) != msg.sender ||
            ERC721A.ownerOf(oceanToken) != msg.sender
        ) revert NotOwner();

        delete _tokenTypes[earthToken];
        delete _tokenTypes[oceanToken];
        _burn(earthToken);
        _burn(oceanToken);

        _mint(msg.sender, 1);
        _tokenTypes[_lastTokenOfOwner(msg.sender)] = Type.Sky;
    }

    function _lastTokenOfOwner(address owner) internal view returns (uint256) {
        uint256 tokenIdsIdx;
        address currOwnershipAddr;
        uint256 tokenIdsLength = ERC721A.balanceOf(owner);
        uint256 tokenId = 0;
        TokenOwnership memory ownership;
        for (uint256 i = ERC721A._startTokenId(); tokenIdsIdx != tokenIdsLength; ++i) {
            ownership = ERC721A._ownershipAt(i);
            if (ownership.burned) {
                continue;
            }
            if (ownership.addr != address(0)) {
                currOwnershipAddr = ownership.addr;
            }
            if (currOwnershipAddr == owner) {
                tokenId = i;
            }
        }
        return tokenId;
    }

    // override
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
}
