// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/DogecoinHeader.sol";

contract DogecoinHeaderTest is Test {
    // Test data from Dogecoin block #3,000,000
    // Block hash (big-endian): 0x00000000000000270cba1d6702c8e36c1ce00ae31a8bbb7d8f84ad21f4784918
    bytes32 constant EXPECTED_HASH = bytes32(uint256(0x00000000000000270cba1d6702c8e36c1ce00ae31a8bbb7d8f84ad21f4784918));
    
    function setUp() public {
    }

    function testHashBlockHeader() public {
        DogecoinHeader.BlockHeader memory header = DogecoinHeader.BlockHeader({
            version: 0x20000000,
            prevBlock: bytes32(0x7d0b42f23cb3d098d4c27a45bb98f2f8f37e5ad65bb842784acd2965072c2521),
            merkleRoot: bytes32(0x06c8a40b031d5af1fc3f3cd2c1fb8effbb7b42df9fb6a9c8ed9fe7c5c5af6c4c),
            timestamp: 1468701786,
            bits: 0x1a01d309,
            nonce: 0x123b6854
        });

        bytes32 hash = DogecoinHeader.hashBlockHeader(header);
        assertEq(hash, DogecoinHeader.reverseBytes32(EXPECTED_HASH), "Hash should match expected value");
    }

    function testVerifyPoW() public {
        // Using data from Dogecoin block #3,000,000
        DogecoinHeader.BlockHeader memory validHeader = DogecoinHeader.BlockHeader({
            version: 0x20000000,
            prevBlock: bytes32(0x7d0b42f23cb3d098d4c27a45bb98f2f8f37e5ad65bb842784acd2965072c2521),
            merkleRoot: bytes32(0x06c8a40b031d5af1fc3f3cd2c1fb8effbb7b42df9fb6a9c8ed9fe7c5c5af6c4c),
            timestamp: 1468701786,
            bits: 0x1a01d309,
            nonce: 0x123b6854
        });

        bool isValid = DogecoinHeader.verifyPoW(validHeader);
        assertTrue(isValid, "PoW verification should pass for valid header");
    }

    function testCalculateTarget() public {
        // Using difficulty bits from block #3,000,000
        uint32 bits = 0x1a01d309;
        uint256 target = DogecoinHeader.calculateTarget(bits);
        assertTrue(target > 0, "Target should be greater than zero");
        assertTrue(target < type(uint256).max, "Target should be less than max uint256");
        
        // The calculated target should be greater than the actual block hash
        assertTrue(target > uint256(DogecoinHeader.reverseBytes32(EXPECTED_HASH)), "Target should be greater than block hash");
    }

    function testInvalidPoW() public {
        // Using valid header but with wrong nonce
        DogecoinHeader.BlockHeader memory invalidHeader = DogecoinHeader.BlockHeader({
            version: 0x20000000,
            prevBlock: bytes32(0x7d0b42f23cb3d098d4c27a45bb98f2f8f37e5ad65bb842784acd2965072c2521),
            merkleRoot: bytes32(0x06c8a40b031d5af1fc3f3cd2c1fb8effbb7b42df9fb6a9c8ed9fe7c5c5af6c4c),
            timestamp: 1468701786,
            bits: 0x1a01d309,
            nonce: 0x1234567 // Invalid nonce
        });

        bool isValid = DogecoinHeader.verifyPoW(invalidHeader);
        assertFalse(isValid, "PoW verification should fail for invalid header");
    }
}
