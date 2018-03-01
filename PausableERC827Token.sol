pragma solidity ^0.4.18;

import "./OpenZeppelin/ERC827Token.sol";
import "./OpenZeppelin/PausableToken.sol";

/**
 * @title Pausable ERC827 token
 * @dev ERC827 token modified with pausable functions.
 **/
contract PausableERC827Token is ERC827Token, PausableToken {

    function transfer(address _to, uint256 _value, bytes _data) public whenNotPaused returns (bool) {
        return super.transfer(_to, _value, _data);
    }

    function transferFrom(address _from, address _to, uint256 _value, bytes _data) public whenNotPaused returns (bool) {
        return super.transferFrom(_from, _to, _value, _data);
    }

    function approve(address _spender, uint256 _value, bytes _data) public whenNotPaused returns (bool) {
        return super.approve(_spender, _value, _data);
    }

    function increaseApproval(address _spender, uint _addedValue, bytes _data) public whenNotPaused returns (bool) {
        return super.increaseApproval(_spender, _addedValue, _data);
    }

    function decreaseApproval(address _spender, uint _subtractedValue, bytes _data) public whenNotPaused returns (bool) {
        return super.decreaseApproval(_spender, _subtractedValue, _data);
    }
}
