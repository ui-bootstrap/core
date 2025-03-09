/*
This file is part of the DAO.

The DAO is free software: you can redistribute it and/or modify
it under the terms of the GNU lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The DAO is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the DAO.  If not, see <http://www.gnu.org/licenses/>.
*/


import "./SubUser.sol";
//import "SlockDAO - deprecated";

contract RewardCollector {
    function payOneTimeFee() returns(bool) {}
    function feeDivisor() constant returns(uint) {}
    function payReward() {}
}

contract Slock is SubUser {
    
    address public owner;
    uint public deposit;
    uint public price;
    uint public timeBlock;

    uint public openTime;
    uint public closeTime;
    
    bool public isRented;
    bool public isRentable;
    
    bool public isFeeFree;
    
    RewardCollector public rewardCollector;

    event Open();
    event Close();
    event Rent(address indexed _user);
    event Return();

    function Slock(uint _deposit, uint _price, uint _timeBlock, RewardCollector _rewardCollector) SubUser() {
        owner = msg.sender;
        deposit = _deposit;
        price = _price;
        rewardCollector = _rewardCollector;
        
        if (_timeBlock == 0)
            timeBlock = 1;
        else
            timeBlock = _timeBlock;
            
        openTime = block.timestamp;
        isRented = false;
        isRentable = true;
        isFeeFree = false;
    }

    modifier require(bool _condition)
    {
        if (!_condition) throw;
        _
    }
    
    // be nice to the user and protect him from sending money when it makes no sense
    modifier noMoney()
    {
        if (msg.value > 0) throw;
        _
    }
    
    modifier onlyOwner()
    {
        if (msg.sender != owner) throw;
        _
    }


    modifier onlyUsers()
    {
        if (msg.sender != user && !isSubUser(msg.sender)) throw;
        _
    }
    
    // setters

    function setDeposit(uint _deposit) onlyOwner noMoney {
        deposit = _deposit;
    }
    
    function setPrice(uint _price) onlyOwner noMoney {
        price = _price;
    }

    function setTimeBlock(uint _timeBlock) onlyOwner noMoney require(_timeBlock != 0) {
        timeBlock = _timeBlock;
    }
    
    function changeOwner(address _newOwner) onlyOwner noMoney {
        owner = _newOwner;
    }
    
    function setRentable(bool _isRentable) onlyOwner noMoney {
        isRentable = _isRentable;
    }
    
    function payOneTimeFee() {
        if (rewardCollector.payOneTimeFee.value(msg.value)())
            isFeeFree = true;
        else
            throw;
    }
    
    // helpers
    
    // used as interface for other smart contracts, normally this is done by signed whisper messages
    function open() onlyUsers noMoney {
        Open();
    }
    
    function close() onlyUsers noMoney {
        Close();
    }
    
    // return cost in wei
    function costs() noMoney returns(uint) {
            return price * (now - openTime + timeBlock) / timeBlock;
    }
    
    // main functions

    function rent() require(isRentable && !isRented && msg.value == deposit) { // TODO add calendar, seperate rental cost from deposit
        user = msg.sender;
        openTime = block.timestamp;
        isRented = true;
    }

    function returnIt() onlyUser require(isRented) noMoney {
        uint cost = costs();
        if (cost > deposit)
            cost = deposit;
        else
            user.send(deposit - cost);
            
        if (isFeeFree)
            owner.send(cost);
        else {
            uint divisor = rewardCollector.feeDivisor();
            rewardCollector.payReward.value(cost / divisor)();
            owner.send(cost - cost / divisor ); 
        }
        
        removeAllSubUsers();
        user = owner;
        isRented = false;
        Close();
    }
    
    function returnToOwner() onlyOwner require(isRented) noMoney {
        uint cost = costs();
        if (cost > deposit){
            if (isFeeFree)
                owner.send(deposit);
            else {
                uint divisor = rewardCollector.feeDivisor();
                rewardCollector.payReward.value(deposit / divisor)();
                owner.send(deposit - deposit / divisor );
            }
            user = owner;
            isRented = false;
            Close();
        }
    }
}