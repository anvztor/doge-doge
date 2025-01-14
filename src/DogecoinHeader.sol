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
        bytes memory encoded = abi.encodePacked(
            header.version,
            header.prevBlock,
            header.merkleRoot,
            header.timestamp,
            header.bits,
            header.nonce
        );
        return sha256(abi.encodePacked(sha256(encoded)));
    }

    /**
     * @dev Verifies the proof of work for a block header
     * @param header The block header to verify
     * @return True if the proof of work is valid
     */
    function verifyPoW(BlockHeader memory header) internal pure returns (bool) {
        bytes32 hash = hashBlockHeader(header);
        uint256 target = calculateTarget(header.bits);
        return uint256(hash) <= target;
    }

    /**
     * @dev Calculates the target difficulty from compact bits
     * @param bits The compact bits representation
     * @return The target as a uint256
     */
    function calculateTarget(uint32 bits) internal pure returns (uint256) {
        uint256 exponent = bits >> 24;
        uint256 mantissa = bits & 0x007fffff;
        
        if (exponent <= 3) {
            mantissa >>= 8 * (3 - exponent);
            return mantissa;
        } else {
            return mantissa << (8 * (exponent - 3));
        }
    }
}
