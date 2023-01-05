// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract IPassConstants{
    bytes32 constant FREE_MINT =
        0xaca2929d09e74b1bd257acca0d40349ade3291350b31ee1e04b706c764e53859;
    bytes32 constant WHITELIST =
        0xc3d232a6c0e2fb343117f17a5ff344a1a84769265318c6d7a8d7d9b2f8bb49e3;
    bytes32 constant TOKEN =
        0x1317f51c845ce3bfb7c268e5337a825f12f3d0af9584c2bbfbf4e64e314eaf73;

    bytes32 constant PREMIUM_TYPE = 
        0x8aae35e5b7d4a4d17030ddbae29872bbd179fd4a375f7e2a3b05ac1f0a2e4d16;

    uint256 constant WHITELIST_PRICE = 0.05 ether;
    uint256 constant PUBLICSALE_PRICE = 0.1 ether;
    uint256 constant PUBLIC_MINT_QTY = 3;
    address constant MULTISIG = 0xAcB683ba69202c5ae6a3B9b9b191075295b1c41C;
}