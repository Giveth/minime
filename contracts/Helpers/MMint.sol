pragma solidity ^0.4.13;

contract MMint {

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
