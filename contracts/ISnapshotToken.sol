pragma solidity ^0.4.13;

// is ISnapshotable, IBasicToken, ISnapshotTokenParent
interface ISnapshotToken {

////////////////
// Events
////////////////

    event SnapshotCreated(uint256 snapshot);

    event Transfer(address indexed _from, address indexed _to, uint256 _amount);

////////////////
// Public functions
////////////////

    function createSnapshot()
        public
        returns (uint256);

    /// @dev This function makes it easy to get the total number of tokens
    /// @return The total number of tokens
    function totalSupply()
        public
        constant
        returns (uint);

    /// @param _owner The address that's balance is being requested
    /// @return The balance of `_owner` at the current block
    function balanceOf(address _owner)
        public
        constant
        returns (uint256 balance);

    /// @notice Send `_amount` tokens to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _amount)
        public
        returns (bool success);

    /// @notice Total amount of tokens at a specific `_snapshot`.
    /// @param _snapshot The block number when the totalSupply is queried
    /// @return The total amount of tokens at `_snapshot`
    function totalSupplyAt(uint _snapshot)
        public
        constant
        returns(uint);

    /// @dev Queries the balance of `_owner` at a specific `_snapshot`
    /// @param _owner The address from which the balance will be retrieved
    /// @param _snapshot The block number when the balance is queried
    /// @return The balance at `_snapshot`
    function balanceOfAt(address _owner, uint _snapshot)
        public
        constant
        returns (uint);

}
