pragma solidity ^0.4.13;

import './IApproveAndCallFallback.sol';
import './IERC20Token.sol';

contract AllowanceBase {

////////////////
// State
////////////////

    // `allowed` tracks any extra transfer rights as in all ERC20 tokens
    mapping (address => mapping (address => uint256)) allowed;

////////////////
// Events
////////////////

    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _amount
        );

////////////////
// Constructor
////////////////

    function AllowanceBase()
        internal
    {
    }

////////////////
// Public functions
////////////////

    /// @dev This function makes it easy to read the `allowed[]` map
    /// @param _owner The address of the account that owns the token
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens of _owner that _spender is allowed
    ///  to spend
    function allowance(address _owner, address _spender)
        public
        constant
        returns (uint256 remaining)
    {
        return allowed[_owner][_spender];
    }

    /// @notice `msg.sender` approves `_spender` to spend `_amount` tokens on
    ///  its behalf. This is a modified version of the ERC20 approve function
    ///  to be a little bit safer
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _amount The amount of tokens to be approved for transfer
    /// @return True if the approval was successful
    function approve(address _spender, uint256 _amount)
        public
        returns (bool success)
    {
        // To change the approve amount you first have to reduce the addresses`
        //  allowance to zero by calling `approve(_spender,0)` if it is not
        //  already 0 to mitigate the race condition described here:
        //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        require((_amount == 0) || (allowed[msg.sender][_spender] == 0));

        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);
        return true;
    }

    /// @notice `msg.sender` approves `_spender` to send `_amount` tokens on
    ///  its behalf, and then a function is triggered in the contract that is
    ///  being approved, `_spender`. This allows users to use their tokens to
    ///  interact with contracts in one function call instead of two
    /// @param _spender The address of the contract able to transfer the tokens
    /// @param _amount The amount of tokens to be approved for transfer
    /// @return True if the function call was successful
    function approveAndCall(address _spender, uint256 _amount, bytes _extraData
    ) returns (bool success) {
        require(approve(_spender, _amount));

        IApproveAndCallFallback(_spender).receiveApproval(
            msg.sender,
            _amount,
            IERC20Token(this),
            _extraData
        );

        return true;
    }

    /// @notice Send `_amount` tokens to `_to` from `_from` on the condition it
    ///  is approved by `_from`
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return True if the transfer was successful
    function transferFrom(address _from, address _to, uint256 _amount)
        public
        returns (bool success)
    {
        // The standard ERC 20 transferFrom functionality
        if (allowed[_from][msg.sender] < _amount) {
            return false;
        }

        allowed[_from][msg.sender] -= _amount;
        return allowanceBaseTransfer(_from, _to, _amount);
    }

////////////////
// Abstract functions
////////////////

    function allowanceBaseTransfer(address from, address to, uint256 amount)
        internal
        returns (bool);

}
