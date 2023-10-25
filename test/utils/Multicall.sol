// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract Multicall {
    function multicall(address[] calldata addresses, bytes[] calldata data) external {
        require(addresses.length == data.length, "unmatched lengths");

        for (uint256 i; i < addresses.length; ++i) {
            address to = addresses[i];
            require(to.code.length != 0, "not contract");

            (bool success,) = to.call(data[i]);
            require(success, "call failed");
        }
    }
}
