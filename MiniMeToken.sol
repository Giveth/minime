/*
Author: Jordi Baylina
License: GPL 3.0
 */

pragma solidity ^0.4.4;

contract Owned {
    /// Allows only the owner to call a function
    modifier onlyOwner { if (msg.sender != owner) throw; _; }

    address public owner;

    /// @return Returns the owner of this token
    function Owned() { owner = msg.sender;}

    /// @notice Changes the owner of the contract
    /// @param _newOwner The new owner of the contract
    function changeOwner(address _newOwner) onlyOwner {
        owner = _newOwner;
    }
}

contract TokenCreation {
    function proxyPayment(address _owner) payable returns(bool);
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

    /// @notice Constructor to create a MiniMeToken
    /// @param _tokenFactory address of the MiniMeTokenFactory that will create
    /// the child contracts
    /// @param _parentToken Address of the parent token, Set to 0 if it is a
    /// new token.
    /// @param _parentSnapShotBlock Block where the initail distribution of the
    /// parent token will be taked.
    /// @param _tokenName Name of the token
    /// @param _decimalUnits Number of decimals of the token
    /// @param _tokenSymbol Token Symbol
    /// @param _isConstant If true, the tokens will not be able to be transfered
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

    /// @notice Send `_amount` tokens to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _amount) returns (bool success) {
        return doTransfer(msg.sender, _to, _amount);
    }

    /// @notice Send `_amount` tokens to `_to` from `_from` on the condition it
    /// is approved by `_from`
    /// @param _from The address of the origin of the transfer
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return Whether the transfer was successful or not
    function transferFrom(address _from, address _to, uint256 _amount) returns (bool success) {
        if (isConstant) throw;
        if (msg.sender != owner) {
            if (allowed[_from][msg.sender] < _amount) return false;
            allowed[_from][msg.sender] -= _amount;
        }
        return doTransfer(_from, _to, _amount);
    }

    function doTransfer(address _from, address _to, uint _amount) internal returns(bool) {

           if (_amount == 0) {
               return true;
           }

           // Do not allow transfer to this
           if ((_to == 0) || (_to == address(this))) throw;

           // Remove _from votes
           var previousBalanceFrom = balanceOfAt(_from, block.number);
           if (previousBalanceFrom < _amount) {
               return false;
           }

           updateValueAtNow(balances[_from], previousBalanceFrom - _amount);

           var previousBalanceTo = balanceOfAt(_to, block.number);
           updateValueAtNow(balances[_to], previousBalanceTo + _amount);

           Transfer(_from, _to, _amount);

           return true;
    }

    /// @param _owner The address from which the balance will be retrieved
    /// @return The balance
    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balanceOfAt(_owner, block.number);
    }

    /// @notice `msg.sender` approves `_spender` to spend `_amount` tokens on
    /// its behalf
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _amount The amount of tokens to be approved for transfer
    /// @return Whether the approval was successful or not
    function approve(address _spender, uint256 _amount) returns (bool success) {
        if (isConstant) throw;
        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);
        return true;
    }

    /// @param _owner The address of the account owning tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens of _owner that _spender is allowed
    /// to spend
    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }

    /* Approves and then calls the receiving contract (Copied from the Consensis Standard contract) */
    function approveAndCall(address _spender, uint256 _amount, bytes _extraData) returns (bool success) {
        if (isConstant) throw;
        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);

        //call the receiveApproval function on the contract you want to be notified. This crafts the function signature manually so one doesn't have to include a contract in here just for this.
        //receiveApproval(address _from, uint256 _amount, address _tokenContract, bytes _extraData)
        //it is assumed that when does this that the call *should* succeed, otherwise one would use vanilla approve instead.
        if(!_spender.call(bytes4(bytes32(sha3("receiveApproval(address,uint256,address,bytes)"))), msg.sender, _amount, this, _extraData)) { throw; }
        return true;
    }

    /// @return Total amount of tokens
    function totalSupply() constant returns (uint) {
        return totalSupplyAt(block.number);
    }


////////////////
// Query balance and totalSupply in History
////////////////

    /// @notice Queries the balance of `_owner` at a specific `_blockNumber`.
    /// @param _owner The address from which the balance will be retrieved
    /// @param _blockNumber block number when the balance is queried
    /// @return The balance
    function balanceOfAt(address _owner, uint _blockNumber) constant returns (uint) {

        if (_blockNumber < creationBlock) {
            return 0;
        } else if ((balances[_owner].length == 0) || (balances[_owner][0].fromBlock > _blockNumber)) {
            if (address(parentToken) != 0) {
                return parentToken.balanceOfAt(_owner, parentSnapShotBlock);
            } else {
                return 0;
            }
        } else {
            return getValueAt( balances[_owner], _blockNumber);
        }

    }

    /// @notice Total amount of tokens at a specific `_blockNumber`.
    /// @param _blockNumber block number when the totalSupply is queried
    /// @return Total amounts of token at `_blockNumber`
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

    /// @notice creates a new child token with the initial distribution the same
    /// that this token at `_snapshotBlock`
    /// @param _childTokenName Name of the child token
    /// @param _childDecimalUnits Units of the child token
    /// @param _childTokenSymbol Symbol of the child token
    /// @param _snapshotBlock Block at when the the distribution of the parent
    /// token is taken as the initial thistribution of the new generated token.
    /// If the block is higher that the actual block, the actual block is token
    /// @param _isConstant Sets if the new child contract will allow transfers
    /// or not.
    /// @return The address of the new MiniMeToken Contract
    function createChildToken(string _childTokenName, uint8 _childDecimalUnits, string _childTokenSymbol, uint _snapshotBlock, bool _isConstant) returns(address) {
        if (_snapshotBlock > block.number) _snapshotBlock = block.number;
        MiniMeToken childToken = tokenFactory.createChildToken(this, _snapshotBlock, _childTokenName, _childDecimalUnits, _childTokenSymbol, _isConstant);
        NewChildToken(address(childToken), _snapshotBlock);
        return address(childToken);
    }

////////////////
// Generate and destroy tokens
////////////////

    /// @notice generates `_amount` tokens that are assigned to `_owner`
    /// @param _owner address of the owner who the new tokens will be assigned
    /// @param _amount quantity of tokens generated
    /// @return true if the tokens are generated correctly
    function generateTokens(address _owner, uint _amount) onlyOwner returns (bool) {
        if (isConstant) throw;
        uint curTotalSupply = getValueAt(totalSupplyHistory, block.number);
        updateValueAtNow(totalSupplyHistory, curTotalSupply + _amount);
        var previousBalanceTo = balanceOf(_owner);
        updateValueAtNow(balances[_owner], previousBalanceTo + _amount);
        Transfer(0, _owner, _amount);
        return true;
    }


    /// @notice destroy `_amount` tokens from `_owner`
    /// @param _owner address who the tokens are destroyed from
    /// @param _amount Quantity of tokens to destroy
    /// @return true if the tokens are removed correctly
    function destroyTokens(address _owner, uint _amount) onlyOwner returns (bool) {
        if (isConstant) throw;
        uint curTotalSupply = getValueAt(totalSupplyHistory, block.number);
        if (curTotalSupply < _amount) throw;
        updateValueAtNow(totalSupplyHistory, curTotalSupply - _amount);
        var previousBalanceFrom = balanceOf(_owner);
        if (previousBalanceFrom < _amount) throw;
        updateValueAtNow(balances[_owner], previousBalanceFrom - _amount);
        Transfer(_owner, 0, _amount);
        return true;
    }

////////////////
// Constant tokens
////////////////


    /// @notice Sets if the contract is constant or not
    /// @param _isConstant true to don't allow transfers false to allow transfer
    function setConstant(bool _isConstant) onlyOwner {
        isConstant = _isConstant;
    }

////////////////
// Internal helper functions to query and set a value in a snapshot array
////////////////

    function getValueAt(Checkpoint[] storage checkpoints, uint _block) constant internal returns (uint) {
        if (checkpoints.length == 0) return 0;
        // Shorcut for the actual value
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

    /// @notice Default method. If the contract has an owner, the Ether is sent
    /// to the owner thru `proxyPayment` method. Generally, the owner will be
    /// the contract responsable for the creation of the tokens.
    function ()  payable {
        if (owner == 0) throw;
        if (! TokenCreation(owner).proxyPayment.value(msg.value)(msg.sender)) {
            throw;
        }
    }


////////////////
// Events
////////////////
    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event Approval(address indexed _owner, address indexed _spender, uint256 _amount);
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
