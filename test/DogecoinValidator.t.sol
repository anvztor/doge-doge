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
        validator = new DogecoinValidator(BATCH_SIZE);
    }

    function testConstructor() public {
        assertEq(validator.owner(), owner, "Owner should be set correctly");
        assertTrue(address(validator.batchMerkleTree()) != address(0), "BatchMerkleTree should be initialized");
    }

    function testSubmitBlockHeaders() public {
        DogecoinHeader.BlockHeader[] memory headers = new DogecoinHeader.BlockHeader[](BATCH_SIZE);
        
        // Create a valid chain of headers
        for (uint256 i = 0; i < BATCH_SIZE; i++) {
            headers[i] = DogecoinHeader.BlockHeader({
                version: 0x20000000,
                prevBlock: i == 0 ? bytes32(0) : headers[i-1].hashBlockHeader(),
                merkleRoot: keccak256(abi.encodePacked("merkleRoot", i)),
                timestamp: uint32(block.timestamp - (BATCH_SIZE - i) * 60), // 1 minute apart
                bits: 0x1e0ffff0, // Low difficulty for testing
                nonce: uint32(i * 1000000)
            });
        }

        validator.submitBlockHeaders(headers, 1000000);
        // Verify batch was submitted by checking BatchMerkleTree state
        assertEq(validator.batchMerkleTree().batchCount(), 1, "Batch should be submitted");
    }

    function testSubmitBlockHeadersNotOwner() public {
        DogecoinHeader.BlockHeader[] memory headers = new DogecoinHeader.BlockHeader[](BATCH_SIZE);
        address notOwner = address(0x1);
        
        vm.startPrank(notOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        validator.submitBlockHeaders(headers, 1000000);
        vm.stopPrank();
    }

    function testSubmitBlockHeadersInvalidSize() public {
        DogecoinHeader.BlockHeader[] memory headers = new DogecoinHeader.BlockHeader[](BATCH_SIZE - 1);
        vm.expectRevert("Invalid batch size");
        validator.submitBlockHeaders(headers, 1000000);
    }

    function testSubmitBlockHeadersInvalidChain() public {
        DogecoinHeader.BlockHeader[] memory headers = new DogecoinHeader.BlockHeader[](BATCH_SIZE);
        
        // Create headers with invalid chain (broken prevBlock links)
        for (uint256 i = 0; i < BATCH_SIZE; i++) {
            headers[i] = DogecoinHeader.BlockHeader({
                version: 0x20000000,
                prevBlock: bytes32(i), // Invalid prevBlock
                merkleRoot: keccak256(abi.encodePacked("merkleRoot", i)),
                timestamp: uint32(block.timestamp - (BATCH_SIZE - i) * 60),
                bits: 0x1e0ffff0,
                nonce: uint32(i * 1000000)
            });
        }

        vm.expectRevert("Invalid header chain");
        validator.submitBlockHeaders(headers, 1000000);
    }

    function testVerifyTransaction() public {
        // First submit a batch of headers
        DogecoinHeader.BlockHeader[] memory headers = new DogecoinHeader.BlockHeader[](BATCH_SIZE);
        for (uint256 i = 0; i < BATCH_SIZE; i++) {
            headers[i] = DogecoinHeader.BlockHeader({
                version: 0x20000000,
                prevBlock: i == 0 ? bytes32(0) : headers[i-1].hashBlockHeader(),
                merkleRoot: keccak256(abi.encodePacked("merkleRoot", i)),
                timestamp: uint32(block.timestamp - (BATCH_SIZE - i) * 60),
                bits: 0x1e0ffff0,
                nonce: uint32(i * 1000000)
            });
        }
        validator.submitBlockHeaders(headers, 1000000);

        // Create mock proofs
        bytes32 txHash = keccak256("transaction");
        bytes32[] memory merkleProof = new bytes32[](3);
        bytes32[] memory headerProof = new bytes32[](3);

        vm.expectRevert("Not implemented"); // Because getBlockHeader is not implemented yet
        validator.verifyTransaction(
            txHash,
            1000000,
            0,
            merkleProof,
            headerProof,
            0
        );
    }

    function testVerifyTransactionDuplicate() public {
        bytes32 txHash = keccak256("transaction");
        bytes32[] memory merkleProof = new bytes32[](3);
        bytes32[] memory headerProof = new bytes32[](3);

        // Mark transaction as processed
        vm.store(
            address(validator),
            keccak256(abi.encode(txHash, uint256(0))), // slot for processedTxs mapping
            bytes32(uint256(1))
        );

        vm.expectRevert("Transaction already processed");
        validator.verifyTransaction(
            txHash,
            1000000,
            0,
            merkleProof,
            headerProof,
            0
        );
    }
}
