pragma solidity ^0.4.18;

import "./OpenZeppelin/BurnableToken.sol";
import "./PausableERC827Token.sol";

contract BerryToken is PausableERC827Token, BurnableToken {

    string public constant name = "Berry";
    string public constant symbol = "BERRY";
    uint32 public constant decimals = 14;

    function BerryToken() public {
        totalSupply_ = 400000000E14;
        balances[owner] = totalSupply_; // Add all tokens to issuer balance (crowdsale in this case)
    }

}
