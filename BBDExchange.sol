pragma solidity ^0.4.13;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
  function mul(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal constant returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal constant returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() {
    owner = msg.sender;
  }


  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }


  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) onlyOwner {
    if (newOwner != address(0)) {
      owner = newOwner;
    }
  }

}

contract BBDToken {
    function totalSupply() constant returns (uint256);
    function balanceOf(address _owner) constant returns (uint256 balance);
    function transfer(address _to, uint256 _value) returns (bool);

    function creationRateOnTime() constant returns (uint256);
    function creationMinCap() constant returns (uint256);
    function transferToExchange(address _from, uint256 _value) returns (bool);
    function buy(address _beneficiary) payable;
}

/**
    Exchange for BlockChain Board Of Derivatives Token.
 */
contract BBDExchange is Ownable {
    using SafeMath for uint256;

    uint256 public constant startTime = 1506844800; //Sunday, 1 October 2017 08:00:00 GMT
    uint256 public constant endTime = 1509523200;  // Wednesday, 1 November 2017 08:00:00 GMT

    BBDToken private bddToken;

    // Events
    event LogSell(address indexed _seller, uint256 _value, uint256 _amount);
    event LogBuy(address indexed _purchaser, uint256 _value, uint256 _amount);

    // Check if min cap was archived.
    modifier onlyWhenICOReachedCreationMinCap() {
        require(bddToken.totalSupply() >= bddToken.creationMinCap());
        _;
    }
    
    function() payable {}

    function Exchange(address bddTokenAddress) {
        bddToken = BBDToken(bddTokenAddress);
    }

    // Current exchange rate for BBD
    function exchangeRate() constant returns (uint256){
        return bddToken.creationRateOnTime().mul(93).div(100); // 93% of price on current contract sale
    }

    // Number of BBD tokens on exchange
    function exchangeBDDBalance() constant returns (uint256){
        return bddToken.balanceOf(this);
    }

    // Max number of BBD tokens on exchange to sell
    function maxSell() constant returns (uint256 bddValue) {
        bddValue = this.balance.mul(exchangeRate());
    }

    // Max value of wei for buy on exchange
    function maxBuy() constant returns (uint256 valueInWei) {
        valueInWei = exchangeBDDBalance().div(exchangeRate());
    }

    // Check if sell is possible
    function checkSell(uint256 _bddValue) constant returns (bool isPossible, uint256 valueInWei) {
        valueInWei = _bddValue.div(exchangeRate());
        isPossible = this.balance >= valueInWei ? true : false;
    }

    // Check if buy is possible
    function checkBuy(uint256 _valueInWei) constant returns (bool isPossible, uint256 bddValue) {
        bddValue = _valueInWei.mul(exchangeRate());
        isPossible = exchangeBDDBalance() >= bddValue ? true : false;
    }

    // Sell BBD
    function sell(uint256 _bddValue) onlyWhenICOReachedCreationMinCap external {
        require(_bddValue > 0);
        require(now >= startTime);
        require(now <= endTime);
        require(_bddValue <= bddToken.balanceOf(msg.sender));

        uint256 checkedEth = _bddValue.div(exchangeRate());
        require(checkedEth <= this.balance);

        //Transfer BBD to exchange and ETH to user 
        require(bddToken.transferToExchange(msg.sender, _bddValue));
        msg.sender.transfer(checkedEth);

        LogSell(msg.sender, checkedEth, _bddValue);
    }

    // Buy BBD
    function buy() onlyWhenICOReachedCreationMinCap payable external {
        require(msg.value != 0);
        require(now >= startTime);
        require(now <= endTime);

        uint256 checkedBDDTokens = msg.value.mul(exchangeRate());
        require(checkedBDDTokens <= exchangeBDDBalance());

        //Transfer BBD to user. 
        require(bddToken.transfer(msg.sender, checkedBDDTokens));

        LogBuy(msg.sender, msg.value, checkedBDDTokens);
    }

    // Close Exchange
    function close() onlyOwner {
        require(now >= endTime);

        //Transfer BBD and ETH to owner
        require(bddToken.transfer(owner, exchangeBDDBalance()));
        owner.transfer(this.balance);
    }
}
