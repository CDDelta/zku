// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Verifier.sol";

contract TriangleJump {
    mapping(address => uint) moveCount;

    Verifier private verifier;

    constructor(address _verifierAddress) {
        verifier = Verifier(_verifierAddress);
    }

    function performMove(uint[2] memory a, uint[2][2] memory b, uint[2] memory c, uint[1] memory input) public {
        require(verifier.verifyProof(a, b, c, input), "Invalid move proof!");

        // Perform state updates, for example,
        moveCount[msg.sender]++;
    }
}