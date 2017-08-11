pragma solidity ^0.4.13;

import './Snapshot.sol';
import './ISnapshotToken.sol';
import './ISnapshotTokenParent.sol';
import './Helpers.sol';

contract SnapshotTokenBase is
    ISnapshotToken,
    ISnapshotTokenParent,
    Snapshot,
    Helpers
{

    // `parentToken` is the Token address that was cloned to produce this token;
    //  it will be 0x0 for a token that was not cloned
    ISnapshotTokenParent public parentToken;

    // `parentSnapShotBlock` is the block number from the Parent Token that was
    //  used to determine the initial distribution of the Clone Token
    uint256 public parentSnapshot;

    // `balances` is the map that tracks the balance of each address, in this
    //  contract when the balance changes the block number that the change
    //  occurred is also included in the map
    mapping (address => Values[]) balances;

    // Tracks the history of the `totalSupply` of the token
    Values[] totalSupplyValues;

////////////////
// Events
////////////////

    event Transfer(address indexed _from, address indexed _to, uint256 _amount);

////////////////
// Constructor
////////////////

    /// @notice Constructor to create a MiniMeToken
    /// @param _parentToken Address of the parent token, set to 0x0 if it is a
    ///  new token
    function SnapshotTokenBase(
        ISnapshotTokenParent _parentToken,
        uint256 _parentSnapshot
    )
        public
        Snapshot(_parentSnapshot)
    {
        parentToken = _parentToken;
        parentSnapshot = _parentSnapshot;
    }

///////////////////
// ERC20 Basic Methods
///////////////////

    /// @dev This function makes it easy to get the total number of tokens
    /// @return The total number of tokens
    function totalSupply()
        public
        constant
        returns (uint)
    {
        return getValue(totalSupplyValues, 0);
    }

    /// @param _owner The address that's balance is being requested
    /// @return The balance of `_owner` at the current block
    function balanceOf(address _owner)
        public
        constant
        returns (uint256 balance)
    {
        return getValue(balances[_owner], 0);
    }

    /// @notice Send `_amount` tokens to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _amount)
        public
        returns (bool success)
    {
        return snapshotBaseTransfer(msg.sender, _to, _amount);
    }

////////////////
// Query balance and totalSupply in History
////////////////

    /// @notice Total amount of tokens at a specific `_snapshot`.
    /// @param _snapshot The block number when the totalSupply is queried
    /// @return The total amount of tokens at `_snapshot`
    function totalSupplyAt(uint _snapshot)
        public
        constant
        returns(uint)
    {
        Values[] storage values = totalSupplyValues;

        // If there is a value, return it
        if (hasValueAt(values, _snapshot)) {
            return getValueAt(values, _snapshot, 0);
        }

        // Try parent contract at or before the fork
        if (address(parentToken) != 0) {
            return parentToken.totalSupplyAt(min(_snapshot, parentSnapshot));
        }

        // Default to an empty balance
        return 0;
    }

    /// @dev Queries the balance of `_owner` at a specific `_snapshot`
    /// @param _owner The address from which the balance will be retrieved
    /// @param _snapshot The block number when the balance is queried
    /// @return The balance at `_snapshot`
    function balanceOfAt(address _owner, uint _snapshot)
        public
        constant
        returns (uint)
    {
        Values[] storage values = balances[_owner];

        // If there is a value, return it
        if (hasValueAt(values, _snapshot)) {
            return getValueAt(values, _snapshot, 0);
        }

        // Try parent contract at or before the fork
        if (address(parentToken) != 0) {
            return parentToken.balanceOfAt(_owner, min(_snapshot, parentSnapshot));
        }

        // Default to an empty balance
        return 0;
    }

////////////////
// Generate and destroy tokens
////////////////

    /// @dev This is the actual transfer function in the token contract, it can
    ///  only be called by other functions in this contract.
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return True if the transfer was successful
    function snapshotBaseTransfer(address _from, address _to, uint _amount)
        internal
        returns(bool)
    {
        if (_amount == 0) {
            return true;
        }

        // If the amount being transfered is more than the balance of the
        //  account the transfer returns false
        var previousBalanceFrom = balanceOf(_from);
        if (previousBalanceFrom < _amount) {
            return false;
        }

        // First update the balance array with the new value for the address
        //  sending the tokens
        uint256 newBalanceFrom = previousBalanceFrom - _amount;
        setValue(balances[_from], newBalanceFrom);

        // Then update the balance array with the new value for the address
        //  receiving the tokens
        uint256 previousBalanceTo = balanceOf(_to);
        uint256 newBalanceTo = previousBalanceTo + _amount;
        assert(newBalanceTo >= previousBalanceTo); // Check for overflow
        setValue(balances[_to], newBalanceTo);

        // An event to make the transfer easy to find on the blockchain
        Transfer(_from, _to, _amount);
        return true;
    }

    /// @notice Generates `_amount` tokens that are assigned to `_owner`
    /// @param _owner The address that will be assigned the new tokens
    /// @param _amount The quantity of tokens generated
    /// @return True if the tokens are generated correctly
    function snapshotBaseGenerateTokens(address _owner, uint _amount)
        internal
        returns (bool)
    {
        uint curTotalSupply = totalSupply();
        uint256 newTotalSupply = curTotalSupply + _amount;
        require(newTotalSupply >= curTotalSupply); // Check for overflow

        uint previousBalanceTo = balanceOf(_owner);
        uint256 newBalanceTo = previousBalanceTo + _amount;
        assert(newBalanceTo >= previousBalanceTo); // Check for overflow

        setValue(totalSupplyValues, newTotalSupply);
        setValue(balances[_owner], newBalanceTo);

        Transfer(0, _owner, _amount);
        return true;
    }

    /// @notice Burns `_amount` tokens from `_owner`
    /// @param _owner The address that will lose the tokens
    /// @param _amount The quantity of tokens to burn
    /// @return True if the tokens are burned correctly
    function snapshotBaseDestroyTokens(address _owner, uint _amount)
        internal
        returns (bool)
    {
        uint curTotalSupply = totalSupply();
        require(curTotalSupply >= _amount);

        uint previousBalanceFrom = balanceOf(_owner);
        require(previousBalanceFrom >= _amount);

        setValue(totalSupplyValues, curTotalSupply - _amount);
        setValue(balances[_owner], previousBalanceFrom - _amount);

        Transfer(_owner, 0, _amount);
        return true;
    }
}
