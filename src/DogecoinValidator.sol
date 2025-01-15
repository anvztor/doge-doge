// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DogecoinHeader.sol";
import "./BatchMerkleTree.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title DogecoinValidator
 * @dev Validates Dogecoin transactions using SPV proofs
 */
contract DogecoinValidator is Ownable {
    using DogecoinHeader for DogecoinHeader.BlockHeader;

    // Batch Merkle tree for block headers
    BatchMerkleTree public batchMerkleTree;

    // Mapping from block height to block header
    mapping(uint256 => DogecoinHeader.BlockHeader) public blockHeaders;
    
    // Mapping from block hash to block height
    mapping(bytes32 => uint256) public blockHeights;
    
    // Mapping from transaction hash to processed flag
    mapping(bytes32 => bool) public processedTransactions;

    // Events
    event HeaderBatchSubmitted(uint256 indexed batchIndex, uint256 startHeight);
    event TransactionVerified(bytes32 indexed txHash, uint256 indexed blockHeight);

    constructor(address initialOwner, uint256 batchSize) Ownable(initialOwner) {
        batchMerkleTree = new BatchMerkleTree(batchSize);
    }

    /**
     * @dev Submits a batch of block headers
     * @param headers Array of block headers
     * @param startHeight Starting block height for this batch
     */
    function submitHeaderBatch(
        DogecoinHeader.BlockHeader[] calldata headers,
        uint256 startHeight
    ) external onlyOwner returns (bytes32) {
        uint256 batchSize = headers.length;
        require(batchSize > 0, "Empty batch");

        bytes32[] memory headerHashes = new bytes32[](batchSize);

        // Verify headers and store them
        for (uint256 i = 0; i < batchSize; i++) {
            DogecoinHeader.BlockHeader memory header = headers[i];
            uint256 height = startHeight + i;

            // For first header in batch (except genesis), verify it links to previously stored header
            if (i == 0 && height > 0) {
                bytes32 prevHash = DogecoinHeader.hashBlockHeader(blockHeaders[height - 1]);
                require(
                    header.prevBlock == prevHash,
                    "Invalid link to previous batch"
                );
            }
            // For subsequent headers, verify they link to previous header in batch
            else if (i > 0) {
                bytes32 prevHash = DogecoinHeader.hashBlockHeader(headers[i-1]);
                require(
                    header.prevBlock == prevHash,
                    "Invalid header chain"
                );
            }

            // Verify proof of work
            require(header.verifyPoW(), "Invalid proof of work");

            // Store header
            blockHeaders[height] = header;
            bytes32 headerHash = DogecoinHeader.hashBlockHeader(header);
            blockHeights[headerHash] = height;
            headerHashes[i] = headerHash;
        }

        // Add headers to batch Merkle tree
        bytes32 batchRoot = batchMerkleTree.submitBatch(headerHashes);
        emit HeaderBatchSubmitted(batchMerkleTree.batchCount() - 1, startHeight);
        
        return batchRoot;
    }

    /**
     * @dev Verifies a Dogecoin transaction using SPV proof
     * @param txHash Hash of the transaction to verify
     * @param blockHeight Height of the block containing the transaction
     * @param merkleProof Merkle proof for the transaction
     * @param headerProof Proof that the block header is in our batch tree
     * @param batchIndex Index of the batch containing the block header
     */
    function verifyTransaction(
        bytes32 txHash,
        uint256 blockHeight,
        bytes32[] calldata merkleProof,
        bytes32[] calldata headerProof,
        uint256 batchIndex
    ) external returns (bool) {
        require(!processedTransactions[txHash], "Transaction already processed");
        
        // Get the block header
        DogecoinHeader.BlockHeader memory header = blockHeaders[blockHeight];
        require(blockHeights[header.hashBlockHeader()] == blockHeight, "Block header not found");
        
        // Verify the block header exists in our batch
        require(
            batchMerkleTree.verifyHeader(batchIndex, header.hashBlockHeader(), headerProof),
            "Invalid header proof"
        );
        
        // Verify the transaction Merkle proof
        require(
            MerkleProof.verify(merkleProof, header.merkleRoot, txHash),
            "Invalid transaction proof"
        );
        
        processedTransactions[txHash] = true;
        emit TransactionVerified(txHash, blockHeight);
        return true;
    }

    /**
     * @dev Gets a block header by height
     * @param height Block height
     * @return BlockHeader
     */
    function getBlockHeader(uint256 height) external view returns (DogecoinHeader.BlockHeader memory) {
        return blockHeaders[height];
    }
}
