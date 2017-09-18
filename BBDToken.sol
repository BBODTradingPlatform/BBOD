pragma solidity ^0.4.10;

import "zeppelin-solidity/contracts/token/StandardToken.sol";

contract MigrationAgent {
    function migrateFrom(address _from, uint256 _value);
}

contract BBDToken is StandardToken {

    // Metadata
    string public constant name = "BlockChain Board Of Derivatives Token";
    string public constant symbol = "BBD";
    uint256 public constant decimals = 18;
    string public constant version = '1.0.0';

    // Presale parameters
    uint256 public presaleStartTime;
    uint256 public presaleEndTime;

    bool public presaleFinalized = false;

    uint256 public constant presaleTokenCreationCap = 40000 * 10 ** decimals;

    uint256 public constant presaleTokenCreationRate = 20000; // 2 BDD per 1 ETH

    // Sale parameters
    uint256 public saleStartTime;
    uint256 public saleEndTime;

    bool public saleFinalized = false;

    uint256 public constant totalTokenCreationCap = 240000 * 10 ** decimals; //todo komentarz

    uint256 public constant saleStartTokenCreationRate = 16600; // 1.66 BDD per 1 ETH
    uint256 public constant saleEndTokenCreationRate = 10000; // 1 BDD per 1 ETH

    // Migration information
    address public migrationMaster;
    address public migrationAgent;
    uint256 public totalMigrated;

    //todo komentarzy
    address public constant qtAccount = 0x87a9131485cf8ed8E9bD834b46A12D7f3092c263;
    address public constant coreTeamMemberOne = 0x9d3F257827B17161a098d380822fa2614FF540c8;
    address public constant coreTeamMemberTwo = 0x9d3F257827B17161a098d380822fa2614FF540c8;

    uint256 public constant divisor = 10000;

    uint256 raised = 0;

    // Events
    event Refund(address indexed _from, uint256 _value);
    event Migrate(address indexed _from, address indexed _to, uint256 _value);

    /**
        * event for token purchase logging
        * @param purchaser who paid for the tokens
        * @param beneficiary who got the tokens
        * @param value weis paid for purchase
        * @param amount amount of tokens purchased
    */ 
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    function() payable {
        require(!presaleFinalized || !saleFinalized); //todo

        if (!presaleFinalized) {
            createPresaleTokens(msg.sender);
        }
        else if(!saleFinalized){
            createSaleTokens(msg.sender);
        }
    }

    function BBDToken(uint256 _presaleStartTime, uint256 _presaleEndTime, uint256 _saleStartTime, uint256 _saleEndTime, address _migrationMaster) {
        //require(_presaleStartTime >= now);
        require(_presaleEndTime >= _presaleStartTime);
        require(_saleStartTime >= _presaleEndTime);
        require(_saleEndTime >= _saleStartTime);
        //require(_migrationMaster != 0x0);

        presaleStartTime = _presaleStartTime;
        presaleEndTime = _presaleEndTime;
        saleStartTime = _saleStartTime;
        saleEndTime = _saleEndTime;
        migrationMaster = _migrationMaster;
    }

    function getTokenCreationRate() constant returns (uint256) {
        require(!presaleFinalized || !saleFinalized);

        uint256 creationRate;

        if (!presaleFinalized) {
            creationRate = presaleTokenCreationRate;
        }
        else{ // todo else if
            // todo do sprdzenia
            uint256 rateRange = saleStartTokenCreationRate - saleEndTokenCreationRate;
            uint256 timeRange = saleEndTime - saleStartTime;
            creationRate = saleStartTokenCreationRate.sub(rateRange.div(timeRange).mul(now.sub(saleStartTime)));
        }

        return creationRate;
    }

    function createPresaleTokens(address _beneficiary) payable {
        require(!presaleFinalized); // todo sprawdzic czy mozna przkeazacc message
        require(msg.value != 0);
        require(now <= presaleEndTime);
        require(now >= presaleStartTime);

        uint256 bbdTokens = msg.value.mul(getTokenCreationRate()).div(divisor); //todo czy dobrze liczy
        uint256 checkedSupply = totalSupply.add(bbdTokens);

        require(presaleTokenCreationCap >= checkedSupply); //todo  >=

        totalSupply = totalSupply.add(bbdTokens);
        balances[_beneficiary] = balances[_beneficiary].add(bbdTokens);

        raised += msg.value;

        TokenPurchase(msg.sender, _beneficiary, msg.value, bbdTokens);

    }

    function finalizePresale() external { //todo sprawdzi external
        require(!presaleFinalized);
        require(now >= presaleEndTime || totalSupply == presaleTokenCreationCap);

        presaleFinalized = true;

        qtAccount.transfer(this.balance.mul(9000).div(divisor)); // Quant Technology 90%
        coreTeamMemberOne.transfer(this.balance.mul(500).div(divisor)); // 5%
        coreTeamMemberTwo.transfer(this.balance.mul(500).div(divisor)); // 5%
    }

    function createSaleTokens(address _beneficiary) payable {
        require(!saleFinalized); //todo spradzic require presale
        require(msg.value != 0);
        require(now <= saleEndTime);
        require(now >= saleStartTime);

        uint256 bbdTokens = msg.value.mul(getTokenCreationRate()).div(divisor);
        uint256 checkedSupply = totalSupply.add(bbdTokens);

        require(totalTokenCreationCap > checkedSupply);

        totalSupply = totalSupply.add(bbdTokens);
        balances[_beneficiary] = balances[_beneficiary].add(bbdTokens);

        raised += msg.value;

        TokenPurchase(msg.sender, _beneficiary, msg.value, bbdTokens);
    }

    function finalizeSale() external {
        require(!saleFinalized); //todo spradzic presale
        require(now >= saleEndTime || totalSupply == totalTokenCreationCap);

        saleFinalized = true;

        uint256 additionalTokensForQTAccount = totalSupply.mul(2250).div(divisor); // 22.5%
        totalSupply = totalSupply.add(additionalTokensForQTAccount);
        balances[qtAccount] = balances[qtAccount].add(additionalTokensForQTAccount);

        uint256 additionalTokensForCoreTeamMember= totalSupply.mul(125).div(divisor); // 1.25%
        totalSupply = totalSupply.add(2*additionalTokensForCoreTeamMember);
        balances[coreTeamMemberOne] = balances[coreTeamMemberOne].add(additionalTokensForCoreTeamMember);
        balances[coreTeamMemberTwo] = balances[coreTeamMemberTwo].add(additionalTokensForCoreTeamMember);

        qtAccount.transfer(this.balance.mul(9000).div(divisor)); // Quant Technology 90%
        coreTeamMemberOne.transfer(this.balance.mul(500).div(divisor)); // 5%
        coreTeamMemberTwo.transfer(this.balance.mul(500).div(divisor)); // 5%
    }

    function migrate(uint256 _value) external {
        require(saleFinalized); // presalefianlized
        require(migrationAgent != 0x0);
        require(_value > 0);
        require(_value < balances[msg.sender]);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        totalSupply = totalSupply.sub(_value);
        totalMigrated = totalMigrated.add(_value);
        MigrationAgent(migrationAgent).migrateFrom(msg.sender, _value);
        Migrate(msg.sender, migrationAgent, _value);
    }

    function setMigrationAgent(address _agent) external {
        require(saleFinalized);
        require(migrationAgent == 0x0);
        require(msg.sender == migrationMaster);

        migrationAgent = _agent;
    }

    function setMigrationMaster(address _master) external {
        require(msg.sender == migrationMaster); // presale 
        require(_master != 0);

        migrationMaster = _master;
    }

    // ICO Status overview. Used for BBOD landing page
    function icoOverview() constant returns (uint256 currentlyRaised, uint256 currentlyTotalSupply, uint256 currentlyTokenCreationRate){
        currentlyRaised = raised;
        currentlyTotalSupply = totalSupply;
        currentlyTokenCreationRate = getTokenCreationRate();
    }
}