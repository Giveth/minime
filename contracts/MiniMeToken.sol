// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { MiniMeBase } from "./MiniMeBase.sol";
import { MiniMeTokenFactory } from "./MiniMeTokenFactory.sol";

contract MiniMeToken is MiniMeBase {
    // The factory used to create new clone tokens
    MiniMeTokenFactory public immutable tokenFactory;

    ////////////////
    // Constructor
    ////////////////

    /// @notice Constructor to create a MiniMeToken
    /// @param _tokenFactory The address of the MiniMeTokenFactory contract that
    ///  will create the Clone token contracts, the token factory needs to be
    ///  deployed first
    /// @param _parentToken Address of the parent token, set to 0x0 if it is a
    ///  new token
    /// @param _parentSnapShotBlock Block of the parent token that will
    ///  determine the initial distribution of the clone token, set to 0 if it
    ///  is a new token
    /// @param _tokenName Name of the new token
    /// @param _decimalUnits Number of decimals of the new token
    /// @param _tokenSymbol Token Symbol for the new token
    /// @param _transfersEnabled If true, tokens will be able to be transferred
    constructor(
        MiniMeTokenFactory _tokenFactory,
        MiniMeToken _parentToken,
        uint256 _parentSnapShotBlock,
        string memory _tokenName,
        uint8 _decimalUnits,
        string memory _tokenSymbol,
        bool _transfersEnabled
    )
        MiniMeBase(_parentToken, _parentSnapShotBlock, _tokenName, _decimalUnits, _tokenSymbol, _transfersEnabled)
    {
        tokenFactory = _tokenFactory;
    }

    ////////////////
    // Generate and destroy tokens
    ////////////////

    /// @notice Generates `_amount` tokens that are assigned to `_owner`
    /// @param _owner The address that will be assigned the new tokens
    /// @param _amount The quantity of tokens generated
    /// @return True if the tokens are generated correctly
    function generateTokens(address _owner, uint256 _amount) public onlyController returns (bool) {
        return mint(_owner, _amount);
    }

    /// @notice Burns `_amount` tokens from `_owner`
    /// @param _owner The address that will lose the tokens
    /// @param _amount The quantity of tokens to burn
    /// @return True if the tokens are burned correctly
    function destroyTokens(address _owner, uint256 _amount) public onlyController returns (bool) {
        return burn(_owner, _amount);
    }

    ////////////////
    // Clone Token Method
    ////////////////

    /// @notice Creates a new clone token with the initial distribution being
    ///  this token at `_snapshotBlock`
    /// @param _cloneTokenName Name of the clone token
    /// @param _cloneDecimalUnits Number of decimals of the smallest unit
    /// @param _cloneTokenSymbol Symbol of the clone token
    /// @param _snapshotBlock Block when the distribution of the parent token is
    ///  copied to set the initial distribution of the new clone token;
    ///  if the block is zero than the actual block, the current block is used
    /// @param _transfersEnabled True if transfers are allowed in the clone
    /// @return The address of the new MiniMeToken Contract
    function createCloneToken(
        string memory _cloneTokenName,
        uint8 _cloneDecimalUnits,
        string memory _cloneTokenSymbol,
        uint256 _snapshotBlock,
        bool _transfersEnabled
    )
        public
        returns (address)
    {
        if (_snapshotBlock == 0) _snapshotBlock = block.number;
        MiniMeToken cloneToken = tokenFactory.createCloneToken(
            this, _snapshotBlock, _cloneTokenName, _cloneDecimalUnits, _cloneTokenSymbol, _transfersEnabled
        );

        cloneToken.changeController(payable(msg.sender));

        // An event to make the token easy to find on the blockchain
        emit NewCloneToken(address(cloneToken), _snapshotBlock);
        return address(cloneToken);
    }
    event NewCloneToken(address indexed _cloneToken, uint256 _snapshotBlock);
}
