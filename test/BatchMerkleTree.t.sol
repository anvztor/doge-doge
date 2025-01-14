// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BatchMerkleTree.sol";

contract BatchMerkleTreeTest is Test {
    BatchMerkleTree public tree;
    uint256 constant BATCH_SIZE = 10;

    function setUp() public {
        tree = new BatchMerkleTree(BATCH_SIZE);
    }

    function testConstructor() public {
        assertEq(tree.BATCH_SIZE(), BATCH_SIZE, "Batch size should be set correctly");
        assertEq(tree.batchCount(), 0, "Initial batch count should be zero");
    }

    function testConstructorRevert() public {
        vm.expectRevert("Invalid batch size");
        new BatchMerkleTree(0);

        vm.expectRevert("Invalid batch size");
        new BatchMerkleTree(1441); // More than 1 day of blocks
    }

    function testSubmitBatch() public {
        bytes32[] memory hashes = new bytes32[](BATCH_SIZE);
        for (uint256 i = 0; i < BATCH_SIZE; i++) {
            hashes[i] = keccak256(abi.encodePacked(i));
        }

        bytes32 root = tree.submitBatch(hashes);
        assertEq(tree.batchCount(), 1, "Batch count should increment");
        assertEq(tree.root(), root, "Root should be updated");
    }

    function testSubmitBatchRevert() public {
        bytes32[] memory invalidHashes = new bytes32[](BATCH_SIZE - 1);
        vm.expectRevert("Invalid batch length");
        tree.submitBatch(invalidHashes);
    }

    function testVerifyHeader() public {
        // Create and submit a batch
        bytes32[] memory hashes = new bytes32[](BATCH_SIZE);
        for (uint256 i = 0; i < BATCH_SIZE; i++) {
            hashes[i] = keccak256(abi.encodePacked(i));
        }
        tree.submitBatch(hashes);

        // Create a proof for the first hash
        bytes32[] memory proof = new bytes32[](4); // Adjust size based on tree depth
        proof[0] = hashes[1];
        proof[1] = keccak256(abi.encodePacked(hashes[2], hashes[3]));
        proof[2] = keccak256(abi.encodePacked(hashes[4], hashes[5]));
        proof[3] = keccak256(abi.encodePacked(hashes[6], hashes[7]));

        bool isValid = tree.verifyHeader(0, hashes[0], proof);
        assertTrue(isValid, "Header verification should pass");
    }

    function testVerifyHeaderInvalidBatch() public {
        bytes32[] memory proof = new bytes32[](1);
        vm.expectRevert("Batch index out of bounds");
        tree.verifyHeader(0, bytes32(0), proof);
    }

    function testComputeMerkleRootEmpty() public {
        bytes32[] memory emptyLeaves = new bytes32[](0);
        vm.expectRevert("Empty leaves");
        tree.computeMerkleRoot(emptyLeaves);
    }

    function testComputeMerkleRootSingle() public {
        bytes32[] memory singleLeaf = new bytes32[](1);
        singleLeaf[0] = keccak256("test");
        bytes32 root = tree.computeMerkleRoot(singleLeaf);
        assertEq(root, singleLeaf[0], "Single leaf should be the root");
    }

    function testHashPairOrder() public {
        bytes32 a = keccak256("a");
        bytes32 b = keccak256("b");
        
        bytes32 hash1 = tree.hashPair(a, b);
        bytes32 hash2 = tree.hashPair(b, a);
        
        assertEq(hash1, hash2, "Hash pair should be order-independent");
    }
}
