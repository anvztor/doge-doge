// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DogecoinValidator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title DogecoinBridge
 * @dev Bridge contract for transferring Dogecoin to Ethereum through SPV proofs
 */
contract DogecoinBridge is Ownable, Pausable {
    // The validator contract
    DogecoinValidator public immutable validator;
    
    // The wrapped Dogecoin token on Ethereum
    IERC20 public immutable wrappedDoge;
    
    // Minimum confirmation blocks required for processing a Dogecoin transaction
    uint256 public minConfirmations;
    
    // Maximum amount that can be bridged in a single transaction
    uint256 public maxBridgeAmount;
    
    // Mapping from Dogecoin transaction hash to bridge information
    mapping(bytes32 => BridgeTransaction) public bridgeTransactions;
    
    struct BridgeTransaction {
        address recipient;      // Ethereum recipient address
        uint256 amount;        // Amount of DOGE (in satoshis)
        bool processed;        // Whether this transaction has been processed
        uint256 blockHeight;   // Dogecoin block height containing the transaction
        uint256 timestamp;     // Timestamp when the bridge transaction was processed
    }
    
    // Events
    event BridgeInitiated(
        bytes32 indexed txHash,
        address indexed recipient,
        uint256 amount,
        uint256 blockHeight
    );
    
    event BridgeCompleted(
        bytes32 indexed txHash,
        address indexed recipient,
        uint256 amount,
        uint256 blockHeight
    );
    
    constructor(
        address _validator,
        address _wrappedDoge,
        uint256 _minConfirmations,
        uint256 _maxBridgeAmount,
        address initialOwner
    ) Ownable(initialOwner) {
        require(_validator != address(0), "Invalid validator address");
        require(_wrappedDoge != address(0), "Invalid wrapped DOGE address");
        require(_minConfirmations > 0, "Invalid min confirmations");
        require(_maxBridgeAmount > 0, "Invalid max bridge amount");
        
        validator = DogecoinValidator(_validator);
        wrappedDoge = IERC20(_wrappedDoge);
        minConfirmations = _minConfirmations;
        maxBridgeAmount = _maxBridgeAmount;
    }
    
    /**
     * @dev Process a Dogecoin transaction and mint wrapped tokens
     * @param txHash Dogecoin transaction hash
     * @param blockHeight Block height containing the transaction
     * @param txIndex Index of the transaction in the block
     * @param merkleProof Merkle proof for the transaction
     * @param headerProof Proof that the block header is in the batch tree
     * @param batchIndex Index of the batch containing the block header
     * @param recipient Ethereum address to receive wrapped tokens
     * @param amount Amount of DOGE to bridge (in satoshis)
     */
    function bridgeTransaction(
        bytes32 txHash,
        uint256 blockHeight,
        uint256 txIndex,
        bytes32[] calldata merkleProof,
        bytes32[] calldata headerProof,
        uint256 batchIndex,
        address recipient,
        uint256 amount
    ) external whenNotPaused {
        require(amount > 0 && amount <= maxBridgeAmount, "Invalid amount");
        require(recipient != address(0), "Invalid recipient");
        require(!bridgeTransactions[txHash].processed, "Transaction already processed");
        
        // Verify the Dogecoin transaction through the validator
        require(
            validator.verifyTransaction(
                txHash,
                blockHeight,
                txIndex,
                merkleProof,
                headerProof,
                batchIndex
            ),
            "Invalid transaction proof"
        );
        
        // Store bridge transaction information
        bridgeTransactions[txHash] = BridgeTransaction({
            recipient: recipient,
            amount: amount,
            processed: true,
            blockHeight: blockHeight,
            timestamp: block.timestamp
        });
        
        // Mint wrapped tokens to the recipient
        // Note: The actual minting would be handled by the wrapped token contract
        // which should have minting rights assigned to this bridge contract
        
        emit BridgeCompleted(txHash, recipient, amount, blockHeight);
    }
    
    /**
     * @dev Update minimum confirmations required
     * @param _minConfirmations New minimum confirmation blocks
     */
    function setMinConfirmations(uint256 _minConfirmations) external onlyOwner {
        require(_minConfirmations > 0, "Invalid min confirmations");
        minConfirmations = _minConfirmations;
    }
    
    /**
     * @dev Update maximum bridge amount
     * @param _maxBridgeAmount New maximum bridge amount
     */
    function setMaxBridgeAmount(uint256 _maxBridgeAmount) external onlyOwner {
        require(_maxBridgeAmount > 0, "Invalid max bridge amount");
        maxBridgeAmount = _maxBridgeAmount;
    }
    
    /**
     * @dev Pause the bridge
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause the bridge
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
