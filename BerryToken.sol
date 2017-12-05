pragma solidity ^0.4.18;

import "./OpenZeppelin/MintableToken.sol";
import "./OpenZeppelin/BurnableToken.sol";

contract BerryToken is MintableToken, BurnableToken {

    string public constant name = "Berry";
    string public constant symbol = "BERRY";
    uint32 public constant decimals = 14;

    function BerryToken() public {
        totalSupply = 400000000E14;
        balances[owner] = totalSupply; // Add all tokens to issuer balance (crowdsale in this case)
    }

}
