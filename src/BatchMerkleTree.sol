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
    
    // Mapping from batch index to batch root
    mapping(uint256 => bytes32) public batchRoots;
    
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
        
        // Store the batch root
        batchRoots[batchIndex] = batchRoot;
        
        emit NewBatchSubmitted(batchIndex, batchRoot);
        return batchRoot;
    }

    /**
     * @dev Gets the root hash of a specific batch
     * @param batchIndex Index of the batch
     * @return Root hash of the batch
     */
    function getBatchRoot(uint256 batchIndex) public view returns (bytes32) {
        require(batchIndex < batchCount, "Batch index out of bounds");
        return batchRoots[batchIndex];
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
        
        bytes32[] memory leaves = batches[batchIndex];
        require(leaves.length > 0, "Batch not found");
        
        // Get the batch root
        bytes32 batchRoot = batchRoots[batchIndex];
        require(batchRoot != bytes32(0), "Batch root not found");
        
        // Find the leaf index
        uint256 leafIndex;
        bool found = false;
        for (uint256 i = 0; i < leaves.length; i++) {
            if (leaves[i] == headerHash) {
                leafIndex = i;
                found = true;
                break;
            }
        }
        require(found, "Header not found in batch");
        
        // Verify the Merkle proof
        bytes32 computedHash = headerHash;
        uint256 index = leafIndex;
        
        for (uint256 i = 0; i < proof.length; i++) {
            if (index % 2 == 0) {
                computedHash = hashPair(computedHash, proof[i]);
            } else {
                computedHash = hashPair(proof[i], computedHash);
            }
            index = index / 2;
        }
        
        return computedHash == batchRoot;
    }

    /**
     * @dev Computes the Merkle root of an array of hashes
     * @param leaves Array of leaf hashes
     * @return Merkle root
     */
    function computeMerkleRoot(bytes32[] memory leaves) public pure returns (bytes32) {
        require(leaves.length > 0, "Empty leaves");
        
        if (leaves.length == 1) {
            return leaves[0];
        }

        uint256 n = leaves.length;
        bytes32[] memory currentLevel = new bytes32[](n);
        for (uint256 i = 0; i < n; i++) {
            currentLevel[i] = leaves[i];
        }

        while (n > 1) {
            uint256 i = 0;
            uint256 j = 0;
            
            while (i < n) {
                if (i + 1 < n) {
                    currentLevel[j] = hashPair(currentLevel[i], currentLevel[i + 1]);
                    i += 2;
                } else {
                    currentLevel[j] = currentLevel[i];
                    i++;
                }
                j++;
            }
            
            n = j;
        }
        
        return currentLevel[0];
    }

    /**
     * @dev Hashes two leaf nodes together
     * @param a First leaf
     * @param b Second leaf
     * @return Hash of the two leaves
     */
    function hashPair(bytes32 a, bytes32 b) public pure returns (bytes32) {
        if (a < b) {
            return keccak256(abi.encodePacked(a, b));
        }
        return keccak256(abi.encodePacked(b, a));
    }
}
