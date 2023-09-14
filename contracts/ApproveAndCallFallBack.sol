// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/// @title Approve And Call Fallback Token Interface
/// @dev This interface must be implemented by other contracts
/// wishing to accept approve and call from MiniMe token contracts.
abstract contract ApproveAndCallFallBack {
    function receiveApproval(address from, uint256 _amount, address _token, bytes memory _data) public virtual;
}
