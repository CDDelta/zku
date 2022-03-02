// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

/// @title HelloWorld
/// @dev A rudimentary contract for storing and retrieving a single integer.
contract HelloWorld {
    uint256 integer;

    /// @dev Retrieve integer from storage.
    /// @return value of stored integer.
    function retrieveInt() public view returns (uint256) {
        return integer;
    }

    /// @dev Store integer in storage.
    /// @param _integer integer to store.
    function storeInt(uint256 _integer) public {
        integer = _integer;
    }
}