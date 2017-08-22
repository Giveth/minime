pragma solidity ^0.4.13;

contract MMint {

    /// @dev This is the actual transfer function in the token contract, it can
    ///  only be called by other functions in this contract.
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return True if the transfer was successful
    function mTransfer(
        address _from,
        address _to,
        uint _amount
    )
        internal
        returns(bool);

    /// @notice Generates `_amount` tokens that are assigned to `_owner`
    /// @param _owner The address that will be assigned the new tokens
    /// @param _amount The quantity of tokens generated
    /// @return True if the tokens are generated correctly
    function mGenerateTokens(address _owner, uint _amount)
        internal
        returns (bool);

    /// @notice Burns `_amount` tokens from `_owner`
    /// @param _owner The address that will lose the tokens
    /// @param _amount The quantity of tokens to burn
    /// @return True if the tokens are burned correctly
    function mDestroyTokens(address _owner, uint _amount)
        internal
        returns (bool);
}
