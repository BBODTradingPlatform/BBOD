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
    function creationMin() constant returns (uint256);
    function transferToExchange(address _from, uint256 _value) returns (bool);
    function buy(address _beneficiary) payable;
}

contract Exchange is Ownable {
    using SafeMath for uint256;

    uint256 public constant startTime = 1506624307; //Sunday, 1 October 2017 08:00:00 GMT
    uint256 public constant endTime = 1506725107; // Wednesday, 1 November 2017 08:00:00 GMT
    uint256 public constant decimals = 18;

    BBDToken private bddToken;

    // Events
    event LogSell(address indexed _seller, uint256 _value, uint256 _amount);
    event LogBuy(address indexed _purchaser, uint256 _value, uint256 _amount);

    modifier onlyWhenICOReachedCreationMin() {
        require(bddToken.totalSupply() >= bddToken.creationMin());
        _;
    }

    function() payable {}

    function Exchange(address bddTokenAddress) {
        bddToken = BBDToken(bddTokenAddress);
    }

    // Current exchange rate for BBD
    function exchangeRate() constant returns (uint256){
        return bddToken.creationRateOnTime().mul(93).div(100); // 93%
    }

    // Number of BBD tokens on exchange
    function exchangeBDDBalance() constant returns (uint256){
        return bddToken.balanceOf(this);
    }

    // Max number of BBD tokens on exchange to sell
    function maxSell() constant returns (uint256 maxBddVal) {
        maxBddVal = this.balance.mul(exchangeRate());
    }

    // Max value of wei for buy on exchange
    function maxBuy() constant returns (uint256 maxEthVal) {
        maxEthVal = exchangeBDDBalance().div(exchangeRate());
    }

    // Calculate sell value 
    function calculateSell(uint256 _bddVal) constant returns (bool isPossible, uint256 weiVal) {
        weiVal = _bddVal.mul(10 ** decimals).div(exchangeRate());
        isPossible = this.balance >= weiVal ? true : false;
    }

    // Calculate buy value 
    function calculateBuy(uint256 _weiVal) constant returns (bool isPossible, uint256 bddVal) {
        bddVal = _weiVal.mul(exchangeRate()).div(10 ** decimals);
        isPossible = exchangeBDDBalance() >= bddVal ? true : false;
    }

    // Sell BBD
    function sell(uint256 _bbdVal) onlyWhenICOReachedCreationMin external {
        require(now >= startTime);
        require(now <= endTime);
        require(_bbdVal <= bddToken.balanceOf(msg.sender));

        uint256 checkedEth = _bbdVal.div(exchangeRate());
        require(checkedEth <= this.balance);

        //Transfer BBD to exchange and ETH to user 
        require(bddToken.transferToExchange(msg.sender, _bbdVal));
        msg.sender.transfer(checkedEth);

        LogSell(msg.sender, checkedEth, _bbdVal);
    }

    // Buy BBD
    function buy() onlyWhenICOReachedCreationMin external payable {
        require(now >= startTime);
        require(now <= endTime);

        uint256 checkedBDDTokens = msg.value.mul(exchangeRate());
        require(checkedBDDTokens <= exchangeBDDBalance());

        //Transfer BBD to user. 
        require(bddToken.transfer(msg.sender, checkedBDDTokens));

        LogBuy(msg.sender, msg.value, checkedBDDTokens);
    }

    function close() onlyOwner {
        require(now >= endTime);

        require(bddToken.transfer(owner, exchangeBDDBalance()));
        owner.transfer(this.balance);
    }
}
