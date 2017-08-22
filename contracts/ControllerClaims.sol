pragma solidity ^0.4.13;

import './Controlled.sol';
import './IBasicToken.sol';
import './IOwned.sol';

contract ControllerClaims is Controlled {

////////////////
// Events
////////////////

    event ClaimedTokens(address indexed _token, address indexed _controller, uint _amount);

    event ClaimedOwnership(address indexed _owned, address indexed _controller);

///////////////////
// Public functions
///////////////////

    /// @notice This method can be used by the controller to extract mistakenly
    ///  sent tokens to this contract.
    /// @param _token The address of the token contract that you want to recover
    ///  set to 0 in case you want to extract ether.
    function claimTokens(IBasicToken _token)
        public
        onlyController
    {
        // Transfer Ether
        if (address(_token) == 0) {
            controller.transfer(this.balance);
            return;
        }

        uint balance = _token.balanceOf(this);
        _token.transfer(controller, balance);
        ClaimedTokens(_token, controller, balance);
    }

    function claimOwnership(IOwned _owned)
        public
        onlyController
    {
        _owned.changeOwner(controller);
        ClaimedOwnership(_owned, controller);
    }
}
