// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title Merkle tree committed NFT
/// @dev A contract that commits its minted NFTs to a Merkle tree.
contract MerkleTreeCommittedNFT is ERC721 {
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private _tokenIdCounter;

    uint constant maxSupply = 8;
    // Prepare a complete Merkle binary tree that we can fill the entire supply's commitments into.
    bytes32[2 * maxSupply - 1] private _merkleTree;

    constructor() ERC721("MerkleTreeCommittedNFT", "MTCNFT") {}

    /// @dev Returns a data URL containing a name and description on the specified token.
    /// @param tokenId the token whose URI to retrieve.
    function tokenURI(uint256 tokenId) public pure override returns (string memory)
    {
        bytes memory dataURI = abi.encodePacked(
            '{',
                '"name": "MTCNFT #', tokenId.toString(), '",',
                '"description": "This is MTCNFT #', tokenId.toString(), '."',
            '}'
        );

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(dataURI)
            )
        );
    }

    /// @dev Returns the node at an index of the Merkle tree committing to the NFTs minted by this contract.
    /// @param nodeIndex the node of the Merkle tree to retrieve.
    function retrieveMerkleTreeNode(uint256 nodeIndex) public view returns (bytes32) {
        return _merkleTree[nodeIndex];
    }

    /// @dev Mints an NFT to the specified address and commits it to the Merkle tree on this contract.
    /// @param to the address to mint the NFT to.
    function safeMint(address to) public {
        uint256 tokenId = _tokenIdCounter.current();
        assert(tokenId < maxSupply);

        _safeMint(to, tokenId);

        // Increment the token id counter for the next NFT.
        _tokenIdCounter.increment();

        // Write a commitment to the newly minted token as a leaf of the Merkle tree.
        uint256 nodeIndex = tokenId + maxSupply - 1;
        _merkleTree[nodeIndex] = keccak256(abi.encodePacked(msg.sender, to, tokenId, tokenURI(tokenId)));

        // While we're not at the root node of the Merkle tree...
        while (nodeIndex > 0) {
            // Move to the parent node of the current node.
            nodeIndex = (nodeIndex - 1) / 2;
            // Recompute the hash of the current node with its left and right children.
            _merkleTree[nodeIndex] = keccak256(abi.encodePacked(_merkleTree[2 * nodeIndex + 1], _merkleTree[2 * nodeIndex + 2]));
        }
    }
}