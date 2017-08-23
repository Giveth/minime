pragma solidity ^0.4.13;


contract IBasicToken {

////////////////
// Events
////////////////

    event Transfer(address indexed _from, address indexed _to, uint256 _amount);

///////////////////
// ERC20 Basic Methods
///////////////////

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

}
