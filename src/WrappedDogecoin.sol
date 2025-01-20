// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DogecoinBridge.sol";

/**
 * @title WrappedDogecoin
 * @dev Implementation of the Wrapped Dogecoin token on Ethereum
 */
contract WrappedDogecoin is ERC20, Ownable, IERC20Mintable {
    address public immutable bridge;

    /**
     * @dev Constructor that gives the specified address the of all tokens
     */
    constructor(address _bridge) ERC20("Wrapped Dogecoin", "wDOGE") Ownable(msg.sender) {
        require(_bridge != address(0), "Bridge address cannot be zero");
        bridge = _bridge;
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply. Only callable by the bridge contract.
     */
    function mint(address to, uint256 amount) external returns (bool) {
        require(msg.sender == bridge, "Only bridge can mint");
        require(to != address(0), "Cannot mint to zero address");
        _mint(to, amount);
        return true;
    }

    /**
     * @dev Burns `amount` tokens from the caller's account, reducing the
     * total supply.
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
