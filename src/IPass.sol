// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPass {
    error AlreadyClaimed();
    error OnlyReOwner();
    error InsufficientEthers();
    error MintExceedsLimit();
    error SaleTimeNotReach();
    error TypeError();
    error NotOwner();
    error TypeQueryForNonexistentToken();
    error InvalidProof();
    error MintNotStart();
    error MintSkyQueryForNonexistentToken();

    enum Type {
        Earth,
        Ocean,
        Sky
    }

    struct SaleConfig {
        uint32 freemintSaleStartTime;
        uint32 publicSaleStartTime;
        uint64 whitelistPrice;
        uint64 publicPrice;
        uint8 publicMintQuantity;
    }

    function getTypeByToken(uint256 _tokenId) external view returns (uint256);
}