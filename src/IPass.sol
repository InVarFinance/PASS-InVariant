// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPass {
    error AlreadyClaimed();
    error OnlyFirstStagedParticipant();
    error InsufficientEthers();
    error MintExceedsLimit();
    error SaleTimeNotReach();
    error NotOwner();
    error NullAddress();
    error InvalidProof();
    error InvalidSignature();
    error MintNotStart();

    struct SaleConfig {
        uint32 freemintSaleStartTime;
        uint32 publicSaleStartTime;
        uint64 whitelistPrice;
        uint64 publicPrice;
        uint8 publicMintQuantity;
    }

    function freeMint() external;
    function whitelistMint(bytes32[] calldata _proof) external payable;
    function publicMint(uint256 _quantity) external payable;
    function premiumMint(bytes32 _hashMsg, uint8 _v, bytes32 _r, bytes32 _s, uint256 _earthToken, uint256 _marineToken) external;
}