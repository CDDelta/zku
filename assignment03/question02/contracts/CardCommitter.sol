// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Verifier.sol";

/// @title Card commitment contract.
/// @dev A contract that allows users to commit to sequences of unique cards in the same suit.
contract CardCommitter {
    mapping(address => uint[]) commitments;

    Verifier private verifier;

    constructor(address _verifierAddress) {
        verifier = Verifier(_verifierAddress);
    }

    /// @dev Returns the number of card commitments made by the address provided.
    /// @param _address the address of the user whose commitment count is to be retrieved.
    function getCommitmentCount(address _address) public view returns (uint) {
        return commitments[_address].length;
    }

    /// @dev Returns the specified card commitment made by the address provided.
    /// @param _address the address of the user whose commitment count is to be retrieved.
    /// @param _index the index of the commitment in the specified address's commitment sequence.
    function getCommitment(address _address, uint _index) public view returns (uint) {
        return commitments[_address][_index];
    }

    /// @dev Privately commits the user to a new unique card within the same suit as their previously committed cards.
    /// @param input a 2 element array with the first element being the user's latest card commitment and
    ///              the second element being the caller's previous card commitment.
    function commit(uint[2] memory a, uint[2][2] memory b, uint[2] memory c, uint[2] memory input) public {
        // Verify that the previous commitment proven in the proof is actually the previous commitment stored in the contract,
        // or, if no card has been committed, that the proof indicates so as well.
        uint commitmentCount = commitments[msg.sender].length;
        require(input[1] == 0 ? commitmentCount == 0 : commitments[msg.sender][commitmentCount - 1] == input[1], "Mismatch with previous card commitment!");
        
        // Verify that the user is not trying to commit to a duplicate card.
        for (uint i = 0; i < commitmentCount; i++) {
            require(commitments[msg.sender][i] != input[0], "Cannot commit to duplicate card!");
        }

        // Verify the commitment proof passed by the user.
        // The proof additionally verifies that the committed cards are of the same suit.
        require(verifier.verifyProof(a, b, c, input), "Card commitment proof not valid!");

        // Add the user's provided card commitment.
        commitments[msg.sender].push(input[0]);
    }
}