// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script} from "forge-std/Script.sol";

contract TempestScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
    }
}
