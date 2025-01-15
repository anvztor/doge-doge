// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/DogecoinValidator.sol";

contract DogecoinValidatorTest is Test {
    DogecoinValidator public validator;
    address public owner;
    uint256 constant BATCH_SIZE = 10;

    function setUp() public {
        owner = address(this);
        validator = new DogecoinValidator(owner, BATCH_SIZE);
    }

    function testConstructor() public view {
        assertEq(validator.owner(), owner, "Owner should be set correctly");
        assertTrue(address(validator.batchMerkleTree()) != address(0), "BatchMerkleTree should be initialized");
    }

    function testSubmitHeaderBatch() public {
        DogecoinHeader.BlockHeader[] memory headers = new DogecoinHeader.BlockHeader[](BATCH_SIZE);
        uint256 baseTimestamp = 1641234567;
        
        // Create and store a previous block header
        DogecoinHeader.BlockHeader[] memory prevBatch = new DogecoinHeader.BlockHeader[](1);
        prevBatch[0] = DogecoinHeader.BlockHeader({
            version: 0x20000000,
            prevBlock: bytes32(0x0000000000000000001f78c7b25e1a99c56bce6a3f25f6fe8768467e3c79d62b),
            merkleRoot: bytes32(0x4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b),
            timestamp: uint32(baseTimestamp - 60),
            bits: 0x1a01c9c4,
            nonce: uint32(0x1a44b9f2)
        });
        
        uint256 startHeight = 4500000;
        bytes32 prevRoot = validator.submitHeaderBatch(prevBatch, startHeight - 1);
        require(prevRoot != bytes32(0), "Previous batch submission failed");
        
        // First block
        headers[0] = DogecoinHeader.BlockHeader({
            version: 0x20000000,
            prevBlock: DogecoinHeader.hashBlockHeader(prevBatch[0]),
            merkleRoot: bytes32(0x4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b),
            timestamp: uint32(baseTimestamp),
            bits: 0x1a01c9c4,
            nonce: uint32(0x1a44b9f2)
        });

        // Generate subsequent blocks with proper linking
        for (uint256 i = 1; i < BATCH_SIZE; i++) {
            headers[i] = DogecoinHeader.BlockHeader({
                version: 0x20000000,
                prevBlock: DogecoinHeader.hashBlockHeader(headers[i-1]),
                merkleRoot: bytes32(0x4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b),
                timestamp: uint32(baseTimestamp + (i * 60)),
                bits: 0x1a01c9c4,
                nonce: uint32(0x1a44b9f2 + i)
            });
        }

        bytes32 batchRoot = validator.submitHeaderBatch(headers, startHeight);
        assertTrue(batchRoot != bytes32(0), "Batch root should not be zero");

        // Verify headers were stored correctly
        for (uint256 i = 0; i < BATCH_SIZE; i++) {
            DogecoinHeader.BlockHeader memory storedHeader = validator.getBlockHeader(startHeight + i);
            assertEq(
                DogecoinHeader.hashBlockHeader(storedHeader),
                DogecoinHeader.hashBlockHeader(headers[i]),
                "Stored header should match submitted header"
            );
        }
    }

    function testVerifyTransaction() public {
        DogecoinHeader.BlockHeader[] memory headers = new DogecoinHeader.BlockHeader[](BATCH_SIZE);
        uint256 baseTimestamp = 1641234567;
        
        // Create and store a previous block header
        DogecoinHeader.BlockHeader[] memory prevBatch = new DogecoinHeader.BlockHeader[](1);
        prevBatch[0] = DogecoinHeader.BlockHeader({
            version: 0x20000000,
            prevBlock: bytes32(0x0000000000000000001f78c7b25e1a99c56bce6a3f25f6fe8768467e3c79d62b),
            merkleRoot: bytes32(0x4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b),
            timestamp: uint32(baseTimestamp - 60),
            bits: 0x1a01c9c4,
            nonce: uint32(0x1a44b9f2)
        });
        
        uint256 startHeight = 4500000;
        bytes32 prevRoot = validator.submitHeaderBatch(prevBatch, startHeight - 1);
        require(prevRoot != bytes32(0), "Previous batch submission failed");
        
        // First block
        headers[0] = DogecoinHeader.BlockHeader({
            version: 0x20000000,
            prevBlock: DogecoinHeader.hashBlockHeader(prevBatch[0]),
            merkleRoot: bytes32(0x4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b),
            timestamp: uint32(baseTimestamp),
            bits: 0x1a01c9c4,
            nonce: uint32(0x1a44b9f2)
        });

        // Generate subsequent blocks with proper linking
        for (uint256 i = 1; i < BATCH_SIZE; i++) {
            headers[i] = DogecoinHeader.BlockHeader({
                version: 0x20000000,
                prevBlock: DogecoinHeader.hashBlockHeader(headers[i-1]),
                merkleRoot: bytes32(0x4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b),
                timestamp: uint32(baseTimestamp + (i * 60)),
                bits: 0x1a01c9c4,
                nonce: uint32(0x1a44b9f2 + i)
            });
        }

        validator.submitHeaderBatch(headers, startHeight);

        // Now verify a transaction
        bytes32 txHash = keccak256(abi.encodePacked("test transaction"));
        uint256 blockHeight = startHeight + 5; // Use middle block
        uint256 txIndex = 0;

        // Create merkle proof for transaction
        bytes32[] memory merkleProof = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            merkleProof[i] = keccak256(abi.encodePacked("merkle proof", i));
        }

        // Create header proof
        bytes32[] memory headerProof = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            headerProof[i] = keccak256(abi.encodePacked("header proof", i));
        }

        bool verified = validator.verifyTransaction(
            txHash,
            blockHeight,
            merkleProof,
            headerProof,
            0 // First batch
        );

        assertTrue(verified, "Transaction should be verified");
        assertTrue(validator.processedTransactions(txHash), "Transaction should be marked as processed");

        // Try to verify same transaction again
        vm.expectRevert("Transaction already processed");
        validator.verifyTransaction(
            txHash,
            blockHeight,
            merkleProof,
            headerProof,
            0
        );
    }
}
