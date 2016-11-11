/*
    Copyright 2016, Jordi Baylina

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


pragma solidity ^0.4.4;

contract Owned {
    /// @notice The address of the owner is the only address that can call a
    ///  function with this modifier
    modifier onlyOwner { if (msg.sender != owner) throw; _; }

    address public owner;

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

    string public name;                //The Token's name: e.g. DigixDAO Tokens
    uint8 public decimals;             //Number of decimals of the smallest unit
    string public symbol;              //An identifier: e.g. REP
    string public version = 'H0.1';    //An arbitrary versioning scheme.


    /// @dev `Checkpoint` is the structure that attaches a block number to the a
    /// given token attribute
    struct  Checkpoint {

        // `fromBlock` is the block number that the value was generated from
        uint fromBlock;

        // `value` is the attribute in question at a specific block number
        uint value;
    }

    // `parentToken` is the Token address that was cloned. 0x0 for a root token
    MiniMeToken public parentToken;

    // `parentSnapShotBlock` is the Block number from the Parent Token that was
    // used to determine the initial distribution of the Cloned Token.
    uint public parentSnapShotBlock;

    // `creationBlock` is the block number that the Cloned Token was created
    uint public creationBlock;

    // `balances` is the map that tracks the balance of each address
    mapping (address => Checkpoint[]) balances;

    // `allowed` tracks any extra transfer rights as in all ERC20 tokens
    mapping (address => mapping (address => uint256)) allowed;

    // Tracks the history of the `totalSupply` of the token
    Checkpoint[] totalSupplyHistory;

    // Flag that determines if the token is transferable or not.
    bool public isConstant;

    // The factory used to create new cloned tokens
    MiniMeTokenFactory public tokenFactory;

////////////////
// Constructor
////////////////

    /// @notice Constructor to create a MiniMeToken
    /// @param _tokenFactory The address of the MiniMeTokenFactory contract that
    /// will create the Cloned token contracts
    /// @param _parentToken Address of the parent token, set to 0x0 if it is a
    /// new token
    /// @param _parentSnapShotBlock Block of the parent token that will
    ///  determine the initial distribution of the cloned token, set to 0 if it
    ///  is a new token
    /// @param _tokenName Name of the new token
    /// @param _decimalUnits Number of decimals of the new token
    /// @param _tokenSymbol Token Symbol for the new token
    /// @param _isConstant If true, tokens will not be able to be transferred
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
        name = _tokenName;                                 // Set the name
        decimals = _decimalUnits;                          // Set the decimals
        symbol = _tokenSymbol;                             // Set the symbol
        parentToken = MiniMeToken(_parentToken);
        parentSnapShotBlock = _parentSnapShotBlock;
        isConstant = _isConstant;
        creationBlock = block.number;
    }


///////////////////
// ERC20 Methods
///////////////////

    /// @notice Send `_amount` tokens to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _amount) returns (bool success) {
        if (isConstant) throw;
        return doTransfer(msg.sender, _to, _amount);
    }

    /// @notice Send `_amount` tokens to `_to` from `_from` on the condition it
    /// is approved by `_from`
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return True if the transfer was successful
    function transferFrom(address _from, address _to, uint256 _amount)
        returns (bool success) {

        // The owner of this contract can move tokens around at will, this is
        // important to recognize! Confirm that you trust the owner of this
        // contract, which in most situations should be another open source
        // smart contract or 0x0
        if (msg.sender != owner) {
            if (isConstant) throw;

            // The standard ERC 20 transferFrom functionality
            if (allowed[_from][msg.sender] < _amount) return false;
            allowed[_from][msg.sender] -= _amount;
        }
        return doTransfer(_from, _to, _amount);
    }

    function doTransfer(address _from, address _to, uint _amount) internal returns(bool) {

           if (_amount == 0) {
               return true;
           }

           // Do not allow transfer to 0x0 or the token contract itself
           if ((_to == 0) || (_to == address(this))) throw;

           // If the amount being transfered is more than the balance of the
           // account the transfer returns false
           var previousBalanceFrom = balanceOfAt(_from, block.number);
           if (previousBalanceFrom < _amount) {
               return false;
           }

           // First update the balance array with the new value for the address
           // sending the tokens
           updateValueAtNow(balances[_from], previousBalanceFrom - _amount);

           // Then update the balance array with the new value for the address
           // receiving the tokens
           var previousBalanceTo = balanceOfAt(_to, block.number);
           updateValueAtNow(balances[_to], previousBalanceTo + _amount);

           // An event to make the transfer easy to find on the blockchain
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

    /* Approves and then calls the receiving contract (Copied from the Consensys Standard contract) */
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
    /// @return The balance at `_blockNumber`
    function balanceOfAt(address _owner, uint _blockNumber) constant
        returns (uint) {

        // If the _blockNumber requested is before the genesis block for the
        //  token the value returned is 0
        if (_blockNumber < creationBlock) {
            return 0;

        // These next few lines are used when the balance of the token is
        // requested before a check point was ever created for this token, it
        // requires that the `parentToken.balanceOfAt` be queried at the genesis
        // block for this token as this contains initial balance of this token.
        } else if ((balances[_owner].length == 0)
            || (balances[_owner][0].fromBlock > _blockNumber)) {
            if (address(parentToken) != 0) {
                return parentToken.balanceOfAt(_owner, parentSnapShotBlock);
            } else {
                // Has no parent
                return 0;
            }

        // This will return the expected balance during normal situations
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
// Clone Token Method
////////////////

    /// @notice creates a new child token with the initial distribution the same
    ///  that this token at `_snapshotBlock`
    /// @param _childTokenName Name of the child token
    /// @param _childDecimalUnits Units of the child token
    /// @param _childTokenSymbol Symbol of the child token
    /// @param _snapshotBlock Block at when the the distribution of the parent
    ///  token is taken as the initial thistribution of the new generated token.
    ///  If the block is higher that the actual block, the actual block is token
    /// @param _isConstant Sets if the new child contract will allow transfers
    ///  or not.
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

        // Binary search of the value in the array.
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


////////////////
// MiniMeTokenFactory
////////////////

// This contract is used to generate child contracts from a contract.
// In solidity this is the way to create a contract from a contract of the same
//  class
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
