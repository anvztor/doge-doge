// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title BatchMerkleTree
 * @dev Implements a Merkle tree for batch processing of Dogecoin block headers
 */
contract BatchMerkleTree {
    // Merkle root of the batch tree
    bytes32 public root;
    
    // Mapping from batch index to array of block header hashes
    mapping(uint256 => bytes32[]) private batches;
    
    // Number of batches processed
    uint256 public batchCount;
    
    // Number of headers per batch
    uint256 public immutable BATCH_SIZE;
    
    event NewBatchSubmitted(uint256 indexed batchIndex, bytes32 batchRoot);
    
    constructor(uint256 batchSize) {
        require(batchSize > 0 && batchSize <= 1440, "Invalid batch size"); // Max 1 day of blocks
        BATCH_SIZE = batchSize;
    }

    /**
     * @dev Submits a new batch of block header hashes
     * @param headerHashes Array of block header hashes
     * @return batchRoot Root hash of the new batch
     */
    function submitBatch(bytes32[] memory headerHashes) public returns (bytes32 batchRoot) {
        require(headerHashes.length == BATCH_SIZE, "Invalid batch length");
        
        uint256 batchIndex = batchCount++;
        batches[batchIndex] = headerHashes;
        
        batchRoot = computeMerkleRoot(headerHashes);
        root = batchRoot;
        
        emit NewBatchSubmitted(batchIndex, batchRoot);
        return batchRoot;
    }

    /**
     * @dev Verifies if a header hash exists in a specific batch
     * @param batchIndex Index of the batch
     * @param headerHash Hash of the block header to verify
     * @param proof Merkle proof for the header
     * @return True if the header exists in the batch
     */
    function verifyHeader(
        uint256 batchIndex,
        bytes32 headerHash,
        bytes32[] memory proof
    ) public view returns (bool) {
        require(batchIndex < batchCount, "Batch index out of bounds");
        
        bytes32 batchRoot = computeMerkleRoot(batches[batchIndex]);
        return MerkleProof.verify(proof, batchRoot, headerHash);
    }

    /**
     * @dev Computes the Merkle root of an array of hashes
     * @param leaves Array of leaf hashes
     * @return Merkle root
     */
    function computeMerkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        require(leaves.length > 0, "Empty leaves");
        
        if (leaves.length == 1) {
            return leaves[0];
        }

        uint256 n = leaves.length;
        uint256 offset = 0;

        while (n > 0) {
            for (uint256 i = 0; i < n - 1; i += 2) {
                leaves[offset + i/2] = hashPair(leaves[offset + i], leaves[offset + i + 1]);
            }
            
            if (n % 2 == 1) {
                leaves[offset + (n-1)/2] = leaves[offset + n - 1];
            }
            
            offset += n/2;
            n = (n + 1) / 2;
        }
        
        return leaves[0];
    }

    /**
     * @dev Hashes two leaf nodes together
     * @param a First leaf
     * @param b Second leaf
     * @return Hash of the two leaves
     */
    function hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(a < b ? abi.encodePacked(a, b) : abi.encodePacked(b, a)));
    }
}
