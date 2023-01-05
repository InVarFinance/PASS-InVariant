// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import { InVarPass } from "../src/InVarPass.sol";

contract InVarPassScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
        new InVarPass("InVarPass", "IVP", 500, 5);
    }
}
