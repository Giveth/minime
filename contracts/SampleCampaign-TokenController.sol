// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/*
    Copyright 2017, Jordi Baylina

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/// @title MilestoneTracker Contract
/// @author Jordi Baylina
/// @dev This contract controls the issuance of tokens for the MiniMe Token
///  Contract. This version specifically acts as a Campaign manager for raising
///  funds for non-profit causes, but it can be customized for any variety of
///  purposes.

import { MiniMeToken } from "./MiniMeToken.sol";
import { TokenController } from "./TokenController.sol";

error NotAuthorized();
error InvalidParameters();
error PaymentRejected();
error TransferFailed(address destination);
error TokenMintFailed();
error FundingPeriodNotOver();

/// @dev `Owned` is a base level contract that assigns an `owner` that can be
///  later changed
contract Owned {
    /// @dev `owner` is the only address that can call a function with this
    /// modifier
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    address public owner;

    /// @notice The Constructor assigns the message sender to be `owner`
    constructor() {
        owner = msg.sender;
    }

    /// @notice `owner` can step down and assign some other address to this role
    /// @param _newOwner The address of the new owner. 0x0 can be used to create
    ///  an ublock.timestampned neutral vault, however that cannot be undone
    function changeOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }
}

/// @dev This is designed to control the issuance of a MiniMe Token for a
///  non-profit Campaign. This contract effectively dictates the terms of the
///  funding round.

contract Campaign is TokenController, Owned {
    uint256 public startFundingTime; // In UNIX Time Format
    uint256 public endFundingTime; // In UNIX Time Format
    uint256 public maximumFunding; // In wei
    uint256 public totalCollected; // In wei
    MiniMeToken public tokenContract; // The new token for this Campaign
    address payable public vaultAddress; // The address to hold the funds donated

    /// @notice 'Campaign()' initiates the Campaign by setting its funding
    /// parameters
    /// @dev There are several checks to make sure the parameters are acceptable
    /// @param _startFundingTime The UNIX time that the Campaign will be able to
    /// start receiving funds
    /// @param _endFundingTime The UNIX time that the Campaign will stop being able
    /// to receive funds
    /// @param _maximumFunding In wei, the Maximum amount that the Campaign can
    /// receive (currently the max is set at 10,000 ETH for the beta)
    /// @param _vaultAddress The address that will store the donated funds
    /// @param _tokenAddress Address of the token contract this contract controls

    constructor(
        uint256 _startFundingTime,
        uint256 _endFundingTime,
        uint256 _maximumFunding,
        address payable _vaultAddress,
        MiniMeToken _tokenAddress
    ) {
        require(
            (_endFundingTime >= block.timestamp) // Cannot end in the past
                && (_endFundingTime > _startFundingTime) && (_maximumFunding <= 10_000 ether) // The Beta is limited
                && (_vaultAddress != address(0)),
            "Invalid parameters"
        ); // To prevent burning ETH
        startFundingTime = _startFundingTime;
        endFundingTime = _endFundingTime;
        maximumFunding = _maximumFunding;
        tokenContract = _tokenAddress; // The Deployed Token Contract
        vaultAddress = _vaultAddress;
    }

    /// @dev The fallback function is called when ether is sent to the contract, it
    /// simply calls `doPayment()` with the address that sent the ether as the
    /// `_owner`. Payable is a required solidity modifier for functions to receive
    /// ether, without this modifier functions will throw if ether is sent to them

    receive() external payable {
        doPayment(msg.sender);
    }

    /////////////////
    // TokenController interface
    /////////////////

    /// @notice `proxyPayment()` allows the caller to send ether to the Campaign and
    /// have the tokens created in an address of their choosing
    /// @param _owner The address that will hold the newly created tokens

    function proxyPayment(address _owner) public payable override returns (bool) {
        doPayment(_owner);
        return true;
    }

    /// @notice Notifies the controller about a transfer, for this Campaign all
    ///  transfers are allowed by default and no extra notifications are needed
    /// @return False if the controller does not authorize the transfer
    function onTransfer(address, address, uint256) public pure override returns (bool) {
        return true;
    }

    /// @notice Notifies the controller about an approval, for this Campaign all
    ///  approvals are allowed by default and no extra notifications are needed
    /// @return False if the controller does not authorize the approval
    function onApprove(address, address, uint256) public pure override returns (bool) {
        return true;
    }

    /// @dev `doPayment()` is an internal function that sends the ether that this
    ///  contract receives to the `vault` and creates tokens in the address of the
    ///  `_owner` assuming the Campaign is still accepting funds
    /// @param _owner The address that will hold the newly created tokens
    function doPayment(address _owner) internal {
        // First check that the Campaign is allowed to receive this donation
        if (
            (block.timestamp > startFundingTime) || (block.timestamp > endFundingTime)
                || (tokenContract.controller() == address(0)) // Extra check
                || (msg.value == 0) || (totalCollected + msg.value > maximumFunding)
        ) {
            revert PaymentRejected();
        }

        //Track how much the Campaign has collected
        totalCollected += msg.value;

        //Send the ether to the vault
        if (!vaultAddress.send(msg.value)) revert TransferFailed(vaultAddress);

        // Creates an equal amount of tokens as ether sent. The new tokens are created
        //  in the `_owner` address
        if (!tokenContract.generateTokens(_owner, msg.value)) revert TokenMintFailed();

        return;
    }

    /// @notice `finalizeFunding()` ends the Campaign by calling setting the
    ///  controller to 0, thereby ending the issuance of new tokens and stopping the
    ///  Campaign from receiving more ether
    /// @dev `finalizeFunding()` can only be called after the end of the funding period.

    function finalizeFunding() external {
        if (block.timestamp > endFundingTime) revert FundingPeriodNotOver();
        tokenContract.changeController(payable(address(0)));
    }

    /// @notice `onlyOwner` changes the location that ether is sent
    /// @param _newVaultAddress The address that will receive the ether sent to this
    ///  Campaign
    function setVault(address payable _newVaultAddress) external onlyOwner {
        vaultAddress = _newVaultAddress;
    }
}
