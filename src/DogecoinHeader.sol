// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DogecoinHeader
 * @dev Defines the structure and utilities for Dogecoin block headers
 */
library DogecoinHeader {
    struct BlockHeader {
        uint32 version;
        bytes32 prevBlock;
        bytes32 merkleRoot;
        uint32 timestamp;
        uint32 bits;
        uint32 nonce;
    }

    /**
     * @dev Computes the hash of a Dogecoin block header
     * @param header The block header to hash
     * @return The double SHA256 hash of the header
     */
    function hashBlockHeader(BlockHeader memory header) internal pure returns (bytes32) {
        // Pack the header fields in little-endian
        bytes memory packed = abi.encodePacked(
            reverseBytes4(header.version),
            reverseBytes32(header.prevBlock),
            reverseBytes32(header.merkleRoot),
            reverseBytes4(header.timestamp),
            reverseBytes4(header.bits),
            reverseBytes4(header.nonce)
        );
        
        // Double SHA256 hash
        bytes32 firstHash = sha256(packed);
        bytes32 finalHash = sha256(abi.encodePacked(firstHash));
        
        // Reverse the final hash to match Dogecoin's byte order
        return reverseBytes32(finalHash);
    }

    /**
     * @dev Verifies the proof of work for a block header
     * @param header The block header to verify
     * @return True if the proof of work is valid
     */
    function verifyPoW(BlockHeader memory header) internal pure returns (bool) {
        bytes32 hash = hashBlockHeader(header);
        uint256 target = calculateTarget(header.bits);
        
        // Convert hash to uint256 for comparison with target
        // Note: hash is already in correct byte order from hashBlockHeader
        uint256 hashNum = uint256(hash);
        
        // In Dogecoin, hash must be less than target
        return hashNum < target;
    }

    /**
     * @dev Calculates the target difficulty from compact bits
     * @param bits The compact bits representation
     * @return The target as a uint256
     */
    function calculateTarget(uint32 bits) internal pure returns (uint256) {
        // Extract exponent and mantissa from bits
        uint256 size = bits >> 24;
        uint256 mantissa = bits & 0x00ffffff;

        // The mantissa is signed but we know it's valid
        require(mantissa > 0, "Invalid difficulty bits");
        
        // Quick check for zero target
        if (size == 0) {
            return 0;
        }
        
        // Calculate target using the formula: mantissa * 256^(size-3)
        uint256 target;
        if (size <= 3) {
            target = mantissa >> (8 * (3 - size));
        } else {
            // Check for potential overflow
            require(size <= 32, "Invalid size in difficulty bits");
            target = mantissa << (8 * (size - 3));
        }

        // Ensure we don't exceed the maximum target
        require(target > 0, "Invalid target");
        return target;
    }

    function reverseBytes4(uint32 input) internal pure returns (bytes4) {
        return bytes4(
            ((input & 0xff000000) >> 24) |
            ((input & 0x00ff0000) >> 8) |
            ((input & 0x0000ff00) << 8) |
            ((input & 0x000000ff) << 24)
        );
    }

    function reverseBytes32(bytes32 input) internal pure returns (bytes32) {
        bytes32 output;
        for(uint i = 0; i < 32; i++) {
            output |= bytes32(uint256(uint8(input[i])) << ((31 - i) * 8));
        }
        return output;
    }
}
