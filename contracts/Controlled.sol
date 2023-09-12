// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract Controlled {
    /// @notice The address of the controller is the only address that can call
    ///  a function with this modifier
    modifier onlyController { require(msg.sender == controller); _; }

    address payable public controller;

    constructor() { controller = payable(msg.sender);}

    /// @notice Changes the controller of the contract
    /// @param _newController The new controller of the contract
    function changeController(address payable _newController) public onlyController {
        controller = _newController;
    }
}
