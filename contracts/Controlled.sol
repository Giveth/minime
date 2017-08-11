pragma solidity ^0.4.13;

import './ITokenController.sol';

contract Controlled {

    ITokenController public controller;

    /// @notice The address of the controller is the only address that can call
    ///  a function with this modifier
    modifier onlyController
    {
         require(msg.sender == address(controller));
         _;
    }

    function Controlled()
    {
         controller = ITokenController(msg.sender);
    }

    /// @notice Changes the controller of the contract
    /// @param _newController The new controller of the contract
    function changeController(ITokenController _newController)
        public
        onlyController
    {
        controller = _newController;
    }
}
