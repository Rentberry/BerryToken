pragma solidity ^0.4.18;

import "./OpenZeppelin/Ownable.sol";
import "./BerryToken.sol";

/*
 * ICO Start time - 1512464400 - December 5, 2018 9:00:00 AM
 * Default ICO End time - 1519862399 - February 28, 2018 11:59:59 PM
*/
contract BerryCrowdsale is Ownable {

    using SafeMath for uint;

    BerryToken public token = new BerryToken();
    uint totalSupply = token.totalSupply();

    bool public isRefundAllowed;
    bool public newBonus_and_newPeriod;
    bool public new_bonus_for_next_period;

    uint public icoStartTime;
    uint public icoEndTime;
    uint public weiRaised;
    uint public hardCap; // amount of ETH collected, which marks end of crowd sale
    uint public tokensDistributed; // amount of bought tokens
    uint public bonus_for_add_stage;

    /*         Bonus variables          */
    uint internal baseBonus1 = 127;
    uint internal baseBonus2 = 120;
    uint internal baseBonus3 = 113;
    uint internal baseBonus4 = 107;
    uint internal baseBonus5 = 100;
    uint public manualBonus;
    /* * * * * * * * * * * * * * * * * * */

    uint public rate; // how many token units a buyer gets per wei
    uint private icoMinPurchase; // In ETH
    uint private icoEndDateIncCount;

    address[] public investors_number;
    address private wallet; // address where funds are collected

    mapping (address => uint) public orderedTokens;
    mapping (address => uint) contributors;

    event FundsWithdrawn(address _who, uint256 _amount);

    modifier hardCapNotReached() {
        require(weiRaised < hardCap);
        _;
    }

    modifier crowdsaleEnded() {
        require(now > icoEndTime);
        _;
    }

    modifier crowdsaleInProgress() {
        bool withinPeriod = (now >= icoStartTime && now <= icoEndTime);
        require(withinPeriod);
        _;
    }

    function BerryCrowdsale(uint _icoStartTime, uint _icoEndTime, address _wallet) public {
        require (
          _icoStartTime > now &&
          _icoEndTime > _icoStartTime
        );

        icoStartTime = _icoStartTime;
        icoEndTime = _icoEndTime;
        wallet = _wallet;

        rate = 4E14; // wei per 1 token

        hardCap = 100000 ether;
        icoEndDateIncCount = 0;
        icoMinPurchase = 100 finney; // 0.1 ETH
        isRefundAllowed = false;
    }

    // fallback function can be used to buy tokens
    function() public payable {
        buyTokens();
    }

    // low level token purchase function
    function buyTokens() public payable crowdsaleInProgress hardCapNotReached {
        require(msg.value > 0);

        // check if the buyer exceeded the funding goal
        calculatePurchaseAndBonuses(msg.sender, msg.value);
    }

    // Returns number of investors
    function getInvestorCount() public view returns (uint) {
        return investors_number.length;
    }

    // Owner can allow or disallow refunds even if soft cap is reached. Should be used in case KYC is not passed.
    // WARNING: owner should transfer collected ETH back to contract before allowing to refund, if he already withdrawn ETH.
    function toggleRefunds() public onlyOwner {
        isRefundAllowed = true;
    }

    // Sends ordered tokens to investors after ICO end if soft cap is reached
    // tokens can be send only if ico has ended
    function sendOrderedTokens() public onlyOwner crowdsaleEnded {
        address investor;
        uint tokensCount;
        for(uint i = 0; i < investors_number.length; i++) {
            investor = investors_number[i];
            tokensCount = orderedTokens[investor];
            assert(tokensCount > 0);
            orderedTokens[investor] = 0;
            token.transfer(investor, tokensCount);
        }
    }

    // Moves ICO ending date by one month. End date can be moved only 3 times.
    // Returns true if ICO end date was successfully shifted
    function moveIcoEndDateByOneMonth(uint bonus_percentage) public onlyOwner crowdsaleInProgress returns (bool) {
        if (icoEndDateIncCount < 3) {
            icoEndTime = icoEndTime.add(30 days);
            icoEndDateIncCount++;
            newBonus_and_newPeriod = true;
            bonus_for_add_stage = bonus_percentage;
            return true;
        }
        else {
            return false;
        }
    }

    // Owner can send back collected ETH if soft cap is not reached or KYC is not passed
    // WARNING: crowdsale contract should have all received funds to return them.
    // If you have already withdrawn them, send them back to crowdsale contract
    function refundInvestors() public onlyOwner {
        require(now >= icoEndTime);
        require(isRefundAllowed);
        require(msg.sender.balance > 0);

        address investor;
        uint contributedWei;
        uint tokens;
        for(uint i = 0; i < investors_number.length; i++) {
            investor = investors_number[i];
            contributedWei = contributors[investor];
            tokens = orderedTokens[investor];
            if(contributedWei > 0) {
                weiRaised = weiRaised.sub(contributedWei);
                contributors[investor] = 0;
                orderedTokens[investor] = 0;
                tokensDistributed = tokensDistributed.sub(tokens);
                investor.transfer(contributedWei); // return funds back to contributor
            }
        }
    }

    // Owner of contract can withdraw collected ETH, if soft cap is reached, by calling this function
    function withdraw() public onlyOwner {
        uint to_send = weiRaised;
        weiRaised = 0;
        FundsWithdrawn(msg.sender, to_send);
        wallet.transfer(to_send);
    }

    // This function should be used to manually reserve some tokens for "big sharks" or bug-bounty program participants
    function manualReserve(address _beneficiary, uint _amount) public onlyOwner crowdsaleInProgress {
        require(_beneficiary != address(0));
        require(_amount > 0);
        checkAndMint(_amount);
        tokensDistributed = tokensDistributed.add(_amount);
        token.transfer(_beneficiary, _amount);
    }

    function burnUnsold() public onlyOwner crowdsaleEnded {
        uint tokensLeft = totalSupply.sub(tokensDistributed);
        token.burn(tokensLeft);
    }

    function finishIco() public onlyOwner {
        icoEndTime = now;
    }

    function distribute_for_founders() public crowdsaleEnded onlyOwner {
        uint to_send = totalSupply.mul(30).div(70);
        checkAndMint(to_send);
        token.transfer(wallet, to_send);
    }

    function transferOwnershipToken(address _to) public onlyOwner {
        token.transferOwnership(_to);
    }

    /***************************
    **  Internal functions    **
    ***************************/

    // Calculates purchase conditions and token bonuses
    function calculatePurchaseAndBonuses(address _beneficiary, uint _weiAmount) internal {
        if (now >= icoStartTime && now < icoEndTime) require(_weiAmount >= icoMinPurchase);

        uint cleanWei; // amount of wei to use for purchase excluding change and hardcap overflows
        uint change;
        uint _tokens;

        //check for hardcap overflow
        if (_weiAmount.add(weiRaised) > hardCap) {
            cleanWei = hardCap.sub(weiRaised);
            change = _weiAmount.sub(cleanWei);
        }
        else cleanWei = _weiAmount;

        assert(cleanWei > 4); // 4 wei is a price of minimal fracture of token
        _tokens = cleanWei.mul(rate).mul(2500).div(1 ether);

        if (contributors[_beneficiary] == 0) investors_number.push(_beneficiary);

        _tokens = calculateBonus(_tokens, cleanWei);
        checkAndMint(_tokens);

        contributors[_beneficiary] = contributors[_beneficiary].add(cleanWei);
        weiRaised = weiRaised.add(cleanWei);
        tokensDistributed = tokensDistributed.add(_tokens);
        orderedTokens[_beneficiary] = orderedTokens[_beneficiary].add(_tokens);

        if (change > 0) _beneficiary.transfer(change);
    }

    // Calculates bonuses based on current stage
    function calculateBonus(uint _baseAmount, uint _wei) internal returns (uint) {
        require(_baseAmount > 0 && _wei > 0);

        if (now >= icoStartTime && now < icoEndTime) {
            return calculateBonusIco(_baseAmount, _wei);
        }
        else return _baseAmount;
    }

    function setBonusForNextStage (uint newBonusPercentage) public onlyOwner {
        manualBonus = newBonusPercentage.add(100);
        new_bonus_for_next_period = true;
    }

    function check_for_manual_bonus (uint _baseBonus) internal returns (uint) {
        if (new_bonus_for_next_period) {
            new_bonus_for_next_period = false;
            return manualBonus;
        } else
            return _baseBonus;
    }

    // Calculates bonuses, specific for the ICO
    // Contains date and volume based bonuses
    function calculateBonusIco(uint _baseAmount, uint _wei) internal returns(uint) {
        if(now >= icoStartTime && now < 1513727999) {
            // 5-19 Dec - 33% bonus
            return _baseAmount.mul(133).div(100);
        }
        else if(now >= 1513728000 && now < 1514332799) {
            // 20-26 - 27% bonus
            baseBonus1 = check_for_manual_bonus(baseBonus1);    // returns 127 if no changes detected
            return _baseAmount.mul(baseBonus1).div(100);
        }
        else if(now >= 1514332800 && now < 1516147199) {
            // 27 dec - 16 jan - 20% bonus
            baseBonus2 = check_for_manual_bonus(baseBonus2);
            return _baseAmount.mul(baseBonus2).div(100);
        }
        else if(now >= 1516147200 && now < 1517356799) {
            // 17-30 jan - 13% bonus
            baseBonus3 = check_for_manual_bonus(baseBonus3);
            return _baseAmount.mul(baseBonus3).div(100);
        }
        else if(now >= 1517356800 && now < 1518566399) {
            //31 jan - 13 feb 7 % bonus
            baseBonus4 = check_for_manual_bonus(baseBonus4);
            return _baseAmount.mul(baseBonus4).div(100);
        }
        else if(now >= 1518566400 && now < 1519862399) {
            //14-28 feb - no bonus
            baseBonus5 = check_for_manual_bonus(baseBonus5);
            return _baseAmount.mul(baseBonus5).div(100);
        }
        else if (newBonus_and_newPeriod) {
            return _baseAmount.mul(bonus_for_add_stage.add(100)).div(100);
        }
        else if(now < icoEndTime) {
            if(_wei >= 1 ether && _wei < 3 ether) {
                return _baseAmount.mul(101).div(100);
            }
            else if(_wei >= 3 ether && _wei < 5 ether) {
                return _baseAmount.mul(102).div(100);
            }
            else if(_wei >= 5 ether) {
                return _baseAmount.mul(103).div(100);
            }
            else {
                return _baseAmount;
            }
        }
    }

    // Checks if more tokens should be minted based on amount of sold tokens, required additional tokens and total supply.
    // If there are not enough tokens, mint missing tokens
    function checkAndMint(uint _amount) internal {
        uint required = tokensDistributed.add(_amount);
        if(required > totalSupply) token.mint(this, required.sub(totalSupply));
    }
}
