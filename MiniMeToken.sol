pragma solidity ^0.4.4;

contract Owned {
    /// Allows only the owner to call a function
    modifier onlyOwner { if (msg.sender != owner) throw; _; }

    address public owner;

    function Owned() { owner = msg.sender;}



    function changeOwner(address _newOwner) onlyOwner {
        owner = _newOwner;
    }
}

contract MiniMeToken is Owned {

    string public name;                   //fancy name: eg Simon Bucks
    uint8 public decimals;                //How many decimals to show. ie. There could 1000 base units with 3 decimals. Meaning 0.980 SBX = 980 base units. It's like comparing 1 wei to 1 ether.
    string public symbol;                 //An identifier: eg SBX
    string public version = 'H0.1';       //human 0.1 standard. Just an arbitrary versioning scheme.

    struct  Checkpoint {
        // snapshot when starts to take effect this assignation
        uint fromBlock;
        // balance assigned to token holder from this snapshot
        uint value;
    }

    MiniMeToken public parentToken;
    uint public parentSnapShotBlock;
    uint public creationBlock;
    mapping (address => Checkpoint[]) balances;
    mapping (address => mapping (address => uint256)) allowed;
    Checkpoint[] totalSupplyHistory;
    bool public isConstant;

    MiniMeTokenFactory public tokenFactory;

////////////////
// Constructor
////////////////

    function MiniMeToken(
        address _tokenFactory,
        address _parentToken,
        uint _parentSnapShotBlock,
        string _tokenName,
        uint8 _decimalUnits,
        string _tokenSymbol,
        bool _isConstant
        ) {
        tokenFactory = MiniMeTokenFactory(_tokenFactory);
        name = _tokenName;                                   // Set the name for display purposes
        decimals = _decimalUnits;                            // Amount of decimals for display purposes
        symbol = _tokenSymbol;                              // Set the symbol for display purposes
        parentToken = MiniMeToken(_parentToken);
        parentSnapShotBlock = _parentSnapShotBlock;
        isConstant = _isConstant;
        creationBlock = block.number;
    }


////////////////
// ERC20 Interface
////////////////

    function transfer(address _to, uint256 _value) returns (bool success) {

        return doTransfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        //same as above. Replace this line with the following if you want to protect against wrapping uints.
        //if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && balances[_to] + _value > balances[_to]) {

        if (isConstant) throw;
        if (msg.sender != owner) {
            if (allowed[_from][msg.sender] < _value) return false;
            allowed[_from][msg.sender] -= _value;
        }
        return doTransfer(_from, _to, _value);
    }

    function doTransfer(address _from, address _to, uint _value) internal returns(bool) {

           if (_value == 0) {
               return true;
           }

           // Do not allow transfer to this
           if ((_to == 0) || (_to == address(this))) throw;

           // Remove _from votes
           var previousBalanceFrom = balanceOfAt(_from, block.number);
           if (previousBalanceFrom < _value) {
               return false;
           }

           updateValueAtNow(balances[_from], previousBalanceFrom - _value);

           var previousBalanceTo = balanceOfAt(_to, block.number);
           updateValueAtNow(balances[_to], previousBalanceTo + _value);

           Transfer(_from, _to, _value);

           return true;
    }


    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balanceOfAt(_owner, block.number);
    }

    function approve(address _spender, uint256 _value) returns (bool success) {
        if (isConstant) throw;
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }

    /* Approves and then calls the receiving contract */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData) returns (bool success) {
        if (isConstant) throw;
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);

        //call the receiveApproval function on the contract you want to be notified. This crafts the function signature manually so one doesn't have to include a contract in here just for this.
        //receiveApproval(address _from, uint256 _value, address _tokenContract, bytes _extraData)
        //it is assumed that when does this that the call *should* succeed, otherwise one would use vanilla approve instead.
        if(!_spender.call(bytes4(bytes32(sha3("receiveApproval(address,uint256,address,bytes)"))), msg.sender, _value, this, _extraData)) { throw; }
        return true;
    }

    function totalSupply() constant returns (uint) {
        return totalSupplyAt(block.number);
    }


////////////////
// Query balance and totalSupply in History
////////////////

    function balanceOfAt(address _holder, uint _blockNumber) constant returns (uint) {

        if (_blockNumber < creationBlock) {
            return 0;
        } else if ((balances[_holder].length == 0) || (balances[_holder][0].fromBlock > _blockNumber)) {
            if (address(parentToken) != 0) {
                return parentToken.balanceOfAt(_holder, parentSnapShotBlock);
            } else {
                return 0;
            }
        } else {
            return getValueAt( balances[_holder], _blockNumber);
        }

    }

    function totalSupplyAt(uint _blockNumber) constant returns(uint) {
        if (_blockNumber < creationBlock) {
            return 0;
        } else if ((totalSupplyHistory.length == 0) || (totalSupplyHistory[0].fromBlock > _blockNumber)) {
            if (address(parentToken) != 0) {
                return parentToken.totalSupplyAt(parentSnapShotBlock);
            } else {
                return 0;
            }
        } else {
            return getValueAt( totalSupplyHistory, _blockNumber);
        }
    }

////////////////
// Create a child token from an snapshot of this token at a given block
////////////////

    function createChildToken(string _childTokenName, uint8 _childDecimalUnits, string _childTokenSymbol, uint _snapshotBlock, bool _isConstant) returns(address) {
        if (_snapshotBlock > block.number) _snapshotBlock = block.number;
        MiniMeToken childToken = tokenFactory.createChildToken(this, _snapshotBlock, _childTokenName, _childDecimalUnits, _childTokenSymbol, _isConstant);
        NewChildToken(address(childToken), _snapshotBlock);
        return address(childToken);
    }


////////////////
// Generate and destroy tokens
////////////////

    function generateTokens(address _holder, uint _value) onlyOwner {
        if (isConstant) throw;
        uint curTotalSupply = getValueAt(totalSupplyHistory, block.number);
        updateValueAtNow(totalSupplyHistory, curTotalSupply + _value);
        var previousBalanceTo = balanceOf(_holder);
        updateValueAtNow(balances[_holder], previousBalanceTo + _value);
        Transfer(0, _holder, _value);
    }

    function destroyTokens(address _holder, uint _value) onlyOwner {
        if (isConstant) throw;
        uint curTotalSupply = getValueAt(totalSupplyHistory, block.number);
        if (curTotalSupply < _value) throw;
        updateValueAtNow(totalSupplyHistory, curTotalSupply - _value);
        var previousBalanceFrom = balanceOf(_holder);
        if (previousBalanceFrom < _value) throw;
        updateValueAtNow(balances[_holder], previousBalanceFrom - _value);
        Transfer(_holder, 0, _value);
    }

////////////////
// Constant tokens
////////////////

    function setConstant(bool _isConstant) onlyOwner {
        isConstant = _isConstant;
    }

////////////////
// Internal helper functions to query and set a value in a snapshot array
////////////////

    function getValueAt(Checkpoint[] storage checkpoints, uint _block) constant internal returns (uint) {
        if (checkpoints.length == 0) return 0;
        //Shorcut for the actual value
        if (_block >= checkpoints[checkpoints.length-1].fromBlock) return checkpoints[checkpoints.length-1].value;
        if (_block < checkpoints[0].fromBlock) return 0;
        uint min = 0;
        uint max = checkpoints.length-1;
        while (max > min) {
            uint mid = (max + min + 1)/ 2;
            if (checkpoints[mid].fromBlock<=_block) {
                min = mid;
            } else {
                max = mid-1;
            }
        }
        return checkpoints[min].value;
    }

    function updateValueAtNow(Checkpoint[] storage checkpoints, uint _value) internal  {
           if ((checkpoints.length == 0) || (checkpoints[checkpoints.length -1].fromBlock < block.number)) {
               Checkpoint newCheckPoint = checkpoints[ checkpoints.length++ ];
               newCheckPoint.fromBlock =  block.number;
               newCheckPoint.value = _value;
           } else {
               Checkpoint oldCheckPoint = checkpoints[checkpoints.length-1];
               oldCheckPoint.value = _value;
           }
    }


    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event NewChildToken(address indexed _childToken, uint _snapshotBlock);

}

contract MiniMeTokenFactory {
    function createChildToken(
        address _parentToken,
        uint _snapshotBlock,
        string _tokenName,
        uint8 _decimalUnits,
        string _tokenSymbol,
        bool _isConstant
    ) returns (MiniMeToken) {
        MiniMeToken newToken = new MiniMeToken(this, _parentToken, _snapshotBlock, _tokenName, _decimalUnits, _tokenSymbol, _isConstant);
        return newToken;
    }
}
