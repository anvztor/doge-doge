// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/DogecoinBridge.sol";
import "../src/DogecoinValidator.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock WDOGE token for testing
contract MockWDOGE is ERC20 {
    constructor() ERC20("Wrapped DOGE", "WDOGE") {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract DogecoinBridgeTest is Test {
    DogecoinBridge public bridge;
    DogecoinValidator public validator;
    MockWDOGE public wdoge;
    
    address public owner;
    uint256 constant BATCH_SIZE = 10;
    uint256 constant MIN_CONFIRMATIONS = 6;
    uint256 constant MAX_BRIDGE_AMOUNT = 1000000000; // 10 DOGE
    
    function setUp() public {
        owner = address(this);
        
        // Deploy contracts
        validator = new DogecoinValidator(owner, BATCH_SIZE);
        wdoge = new MockWDOGE();
        bridge = new DogecoinBridge(
            address(validator),
            address(wdoge),
            MIN_CONFIRMATIONS,
            MAX_BRIDGE_AMOUNT,
            owner
        );
    }
    
    function testConstructor() public {
        assertEq(address(bridge.validator()), address(validator), "Invalid validator address");
        assertEq(address(bridge.wrappedDoge()), address(wdoge), "Invalid wrapped DOGE address");
        assertEq(bridge.minConfirmations(), MIN_CONFIRMATIONS, "Invalid min confirmations");
        assertEq(bridge.maxBridgeAmount(), MAX_BRIDGE_AMOUNT, "Invalid max bridge amount");
        assertEq(bridge.owner(), owner, "Invalid owner");
    }
    
    function testBridgeTransaction() public {
        // First submit a batch of headers to the validator
        DogecoinHeader.BlockHeader[] memory headers = new DogecoinHeader.BlockHeader[](BATCH_SIZE);
        
        for (uint256 i = 0; i < BATCH_SIZE; i++) {
            headers[i] = DogecoinHeader.BlockHeader({
                version: 0x20000000,
                prevBlock: i == 0 ? bytes32(0) : DogecoinHeader.hashBlockHeader(headers[i-1]),
                merkleRoot: keccak256(abi.encodePacked("merkleRoot", i)),
                timestamp: uint32(block.timestamp - (BATCH_SIZE - i) * 60),
                bits: 0x1e0ffff0,
                nonce: uint32(i)
            });
        }
        
        validator.submitHeaderBatch(headers, 0);
        
        // Now try to bridge a transaction
        bytes32 txHash = keccak256("test transaction");
        uint256 blockHeight = 5; // Use middle block
        uint256 txIndex = 0;
        address recipient = address(0x123);
        uint256 amount = 1000000; // 0.01 DOGE
        
        // Create merkle proof for transaction
        bytes32[] memory merkleProof = new bytes32[](1);
        merkleProof[0] = keccak256("merkle proof");
        
        // Create header proof
        bytes32[] memory headerProof = new bytes32[](1);
        headerProof[0] = keccak256("header proof");
        
        bridge.bridgeTransaction(
            txHash,
            blockHeight,
            txIndex,
            merkleProof,
            headerProof,
            0, // First batch
            recipient,
            amount
        );
        
        // Verify bridge transaction was stored
        DogecoinBridge.BridgeTransaction memory bridgeTx = bridge.bridgeTransactions(txHash);
        assertEq(bridgeTx.recipient, recipient, "Invalid recipient");
        assertEq(bridgeTx.amount, amount, "Invalid amount");
        assertTrue(bridgeTx.processed, "Transaction should be marked as processed");
        assertEq(bridgeTx.blockHeight, blockHeight, "Invalid block height");
        
        // Try to bridge same transaction again
        vm.expectRevert("Transaction already processed");
        bridge.bridgeTransaction(
            txHash,
            blockHeight,
            txIndex,
            merkleProof,
            headerProof,
            0,
            recipient,
            amount
        );
    }
    
    function testPause() public {
        bridge.pause();
        assertTrue(bridge.paused(), "Bridge should be paused");
        
        bytes32 txHash = keccak256("test transaction");
        bytes32[] memory merkleProof = new bytes32[](1);
        bytes32[] memory headerProof = new bytes32[](1);
        
        vm.expectRevert("Pausable: paused");
        bridge.bridgeTransaction(
            txHash,
            0,
            0,
            merkleProof,
            headerProof,
            0,
            address(0x123),
            1000000
        );
        
        bridge.unpause();
        assertFalse(bridge.paused(), "Bridge should be unpaused");
    }
    
    function testSetMinConfirmations() public {
        uint256 newMinConfirmations = 12;
        bridge.setMinConfirmations(newMinConfirmations);
        assertEq(bridge.minConfirmations(), newMinConfirmations, "Min confirmations not updated");
        
        vm.expectRevert("Invalid min confirmations");
        bridge.setMinConfirmations(0);
    }
    
    function testSetMaxBridgeAmount() public {
        uint256 newMaxAmount = 2000000000;
        bridge.setMaxBridgeAmount(newMaxAmount);
        assertEq(bridge.maxBridgeAmount(), newMaxAmount, "Max bridge amount not updated");
        
        vm.expectRevert("Invalid max bridge amount");
        bridge.setMaxBridgeAmount(0);
    }
}
