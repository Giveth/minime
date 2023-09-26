// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

error TransfersDisabled();
error ParentSnapshotNotReached();
error NotEnoughBalance();
error NotEnoughAllowance();
error NotEnoughSupply();
error InvalidDestination();
error ControllerRejected();
error Overflow();
error AllowanceAlreadySet();
error OperationFailed();
error ControllerNotSet();
error ERC2612ExpiredSignature(uint256 deadline);
error ERC2612InvalidSigner(address signer, address owner);
/*
    Copyright 2016, Jordi Baylina

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

import { Controlled } from "./Controlled.sol";
import { TokenController } from "./TokenController.sol";
import { ApproveAndCallFallBack } from "./ApproveAndCallFallBack.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Nonces } from "./Nonces.sol";

/// @title MiniMeBase Contract
/// @author Jordi Baylina
/// @dev This token contract's goal is to make it easy for anyone to clone this
///  token using the token distribution at a given block, this will allow DAO's
///  and DApps to upgrade their features in a decentralized manner without
///  affecting the original token
abstract contract MiniMeBase is Controlled, IERC20, IERC20Permit, EIP712, Nonces {
    string public name; //The Token's name: e.g. DigixDAO Tokens
    uint8 public immutable decimals; //Number of decimals of the smallest unit
    string public symbol; //An identifier: e.g. REP
    string public constant TOKEN_VERSION = "MMT_0.2"; //An arbitrary versioning scheme
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /// @dev `Checkpoint` is the structure that attaches a block number to a
    ///  given value, the block number attached is the one that last changed the
    ///  value
    struct Checkpoint {
        // `fromBlock` is the block number that the value was generated from
        uint128 fromBlock;
        // `value` is the amount of tokens at a specific block number
        uint128 value;
    }

    // `parentToken` is the Token address that was cloned to produce this token;
    //  it will be 0x0 for a token that was not cloned
    MiniMeBase public immutable parentToken;

    // `parentSnapShotBlock` is the block number from the Parent Token that was
    //  used to determine the initial distribution of the Clone Token
    uint256 public immutable parentSnapShotBlock;

    // `creationBlock` is the block number that the Clone Token was created
    uint256 public immutable creationBlock;

    // `balances` is the map that tracks the balance of each address, in this
    //  contract when the balance changes the block number that the change
    //  occurred is also included in the map
    mapping(address account => Checkpoint[] history) private balances;

    // `allowed` tracks any extra transfer rights as in all ERC20 tokens
    mapping(address account => mapping(address authorized => uint256 amount) allowance) private allowed;

    // Tracks the history of the `totalSupply` of the token
    Checkpoint[] private totalSupplyHistory;

    // Flag that determines if the token is transferable or not.
    bool public transfersEnabled;

    /// @notice Constructor to create a MiniMeBase
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
        MiniMeBase _parentToken,
        uint256 _parentSnapShotBlock,
        string memory _tokenName,
        uint8 _decimalUnits,
        string memory _tokenSymbol,
        bool _transfersEnabled
    )
        EIP712(_tokenName, TOKEN_VERSION)
    {
        name = _tokenName; // Set the name
        decimals = _decimalUnits; // Set the decimals
        symbol = _tokenSymbol; // Set the symbol
        parentToken = _parentToken;
        parentSnapShotBlock = _parentSnapShotBlock;
        transfersEnabled = _transfersEnabled;
        creationBlock = block.number;
    }

    ///////////////////
    // ERC20 Methods
    ///////////////////

    /// @notice Send `_amount` tokens to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return success Whether the transfer was successful or not
    function transfer(address _to, uint256 _amount) public returns (bool success) {
        if (!transfersEnabled) revert TransfersDisabled();
        doTransfer(msg.sender, _to, _amount);
        return true;
    }

    /// @notice Send `_amount` tokens to `_to` from `_from` on the condition it
    ///  is approved by `_from`
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return success True if the transfer was successful
    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool success) {
        // The controller of this contract can move tokens around at will,
        //  this is important to recognize! Confirm that you trust the
        //  controller of this contract, which in most situations should be
        //  another open source smart contract or 0x0
        if (msg.sender != controller) {
            if (!transfersEnabled) revert TransfersDisabled();

            // The standard ERC 20 transferFrom functionality
            if (allowed[_from][msg.sender] < _amount) revert NotEnoughAllowance();
            allowed[_from][msg.sender] -= _amount;
        }
        doTransfer(_from, _to, _amount);
        return true;
    }

    /// @dev This is the actual transfer function in the token contract, it can
    ///  only be called by other functions in this contract.
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    function doTransfer(address _from, address _to, uint256 _amount) internal {
        if (_amount == 0) {
            emit Transfer(_from, _to, _amount); // Follow the spec to louch the event when transfer 0
            return;
        }

        if (parentSnapShotBlock >= block.number) revert ParentSnapshotNotReached();

        // Do not allow transfer to 0x0 or the token contract itself
        if ((_to == address(0)) || (_to == address(this))) revert InvalidDestination();

        // If the amount being transfered is more than the balance of the
        //  account the transfer throws
        uint256 previousBalanceFrom = balanceOfAt(_from, block.number);

        if (previousBalanceFrom < _amount) revert NotEnoughBalance();

        // First update the balance array with the new value for the address
        //  sending the tokens
        updateValueAtNow(balances[_from], previousBalanceFrom - _amount);

        // Then update the balance array with the new value for the address
        //  receiving the tokens
        uint256 previousBalanceTo = balanceOfAt(_to, block.number);
        if (uint128(previousBalanceTo + _amount) < previousBalanceTo) revert Overflow(); // Check for overflow
        updateValueAtNow(balances[_to], previousBalanceTo + _amount);

        // Alerts the token controller of the transfer
        if (isContract(controller)) {
            if (!TokenController(controller).onTransfer(_from, _to, _amount)) {
                revert ControllerRejected();
            }
        }

        // An event to make the transfer easy to find on the blockchain
        emit Transfer(_from, _to, _amount);
    }

    /// @param _owner The address that's balance is being requested
    /// @return balance The balance of `_owner` at the current block
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balanceOfAt(_owner, block.number);
    }

    /// @notice `msg.sender` approves `_spender` to spend `_amount` tokens on
    ///  its behalf. This is a modified version of the ERC20 approve function
    ///  to be a little bit safer
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _amount The amount of tokens to be approved for transfer
    /// @return success True if the approval was successful
    function approve(address _spender, uint256 _amount) public returns (bool success) {
        return doApprove(msg.sender, _spender, _amount);
    }

    /**
     * @inheritdoc IERC20Permit
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        public
        virtual
    {
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline));

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != owner) {
            revert ERC2612InvalidSigner(signer, owner);
        }

        doApprove(owner, spender, value);
    }

    function doApprove(address _owner, address _spender, uint256 _amount) internal returns (bool) {
        if (!transfersEnabled) revert TransfersDisabled();

        // To change the approve amount you first have to reduce the addresses`
        //  allowance to zero by calling `approve(_spender,0)` if it is not
        //  already 0 to mitigate the race condition described here:
        //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        if ((_amount != 0) && (allowed[_owner][_spender] != 0)) revert AllowanceAlreadySet();

        // Alerts the token controller of the approve function call
        if (isContract(controller)) {
            if (!TokenController(controller).onApprove(_owner, _spender, _amount)) {
                revert ControllerRejected();
            }
        }

        allowed[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
        return true;
    }

    /// @dev This function makes it easy to read the `allowed[]` map
    /// @param _owner The address of the account that owns the token
    /// @param _spender The address of the account able to transfer the tokens
    /// @return remaining Amount of remaining tokens of _owner that _spender is allowed
    ///  to spend
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    /// @notice `msg.sender` approves `_spender` to send `_amount` tokens on
    ///  its behalf, and then a function is triggered in the contract that is
    ///  being approved, `_spender`. This allows users to use their tokens to
    ///  interact with contracts in one function call instead of two
    /// @param _spender The address of the contract able to transfer the tokens
    /// @param _amount The amount of tokens to be approved for transfer
    /// @return success True if the function call was successful
    function approveAndCall(address _spender, uint256 _amount, bytes memory _extraData) public returns (bool success) {
        if (!approve(_spender, _amount)) revert OperationFailed();

        ApproveAndCallFallBack(_spender).receiveApproval(msg.sender, _amount, address(this), _extraData);

        return true;
    }

    /// @dev This function makes it easy to get the total number of tokens
    /// @return The total number of tokens
    function totalSupply() public view returns (uint256) {
        return totalSupplyAt(block.number);
    }

    ////////////////
    // Query balance and totalSupply in History
    ////////////////

    /// @dev Queries the balance of `_owner` at a specific `_blockNumber`
    /// @param _owner The address from which the balance will be retrieved
    /// @param _blockNumber The block number when the balance is queried
    /// @return The balance at `_blockNumber`
    function balanceOfAt(address _owner, uint256 _blockNumber) public view returns (uint256) {
        // These next few lines are used when the balance of the token is
        //  requested before a check point was ever created for this token, it
        //  requires that the `parentToken.balanceOfAt` be queried at the
        //  genesis block for that token as this contains initial balance of
        //  this token
        if ((balances[_owner].length == 0) || (balances[_owner][0].fromBlock > _blockNumber)) {
            if (address(parentToken) != address(0)) {
                return parentToken.balanceOfAt(_owner, min(_blockNumber, parentSnapShotBlock));
            } else {
                // Has no parent
                return 0;
            }

            // This will return the expected balance during normal situations
        } else {
            return getValueAt(balances[_owner], _blockNumber);
        }
    }

    /// @notice Total amount of tokens at a specific `_blockNumber`.
    /// @param _blockNumber The block number when the totalSupply is queried
    /// @return The total amount of tokens at `_blockNumber`
    function totalSupplyAt(uint256 _blockNumber) public view returns (uint256) {
        // These next few lines are used when the totalSupply of the token is
        //  requested before a check point was ever created for this token, it
        //  requires that the `parentToken.totalSupplyAt` be queried at the
        //  genesis block for this token as that contains totalSupply of this
        //  token at this block number.
        if ((totalSupplyHistory.length == 0) || (totalSupplyHistory[0].fromBlock > _blockNumber)) {
            if (address(parentToken) != address(0)) {
                return parentToken.totalSupplyAt(min(_blockNumber, parentSnapShotBlock));
            } else {
                return 0;
            }

            // This will return the expected totalSupply during normal situations
        } else {
            return getValueAt(totalSupplyHistory, _blockNumber);
        }
    }

    ///
    /// @inheritdoc IERC20Permit
    ///
    function nonces(address owner) public view virtual override(IERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    ///
    /// @inheritdoc IERC20Permit
    ///
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }

    ////////////////
    // Generate and destroy tokens
    ////////////////

    /// @notice Generates `_amount` tokens that are assigned to `_owner`
    /// @param _owner The address that will be assigned the new tokens
    /// @param _amount The quantity of tokens generated
    /// @return True if the tokens are generated correctly
    function mint(address _owner, uint256 _amount) internal returns (bool) {
        uint256 curTotalSupply = totalSupply();
        if (uint128(curTotalSupply + _amount) < curTotalSupply) revert Overflow(); // Check for overflow
        uint256 previousBalanceTo = balanceOf(_owner);
        if (uint128(previousBalanceTo + _amount) < previousBalanceTo) revert Overflow(); // Check for overflow
        updateValueAtNow(totalSupplyHistory, curTotalSupply + _amount);
        updateValueAtNow(balances[_owner], previousBalanceTo + _amount);
        emit Transfer(address(0), _owner, _amount);
        return true;
    }

    /// @notice Burns `_amount` tokens from `_owner`
    /// @param _owner The address that will lose the tokens
    /// @param _amount The quantity of tokens to burn
    /// @return True if the tokens are burned correctly
    function burn(address _owner, uint256 _amount) internal returns (bool) {
        uint256 curTotalSupply = totalSupply();
        if (curTotalSupply < _amount) revert NotEnoughSupply();
        uint256 previousBalanceFrom = balanceOf(_owner);
        if (previousBalanceFrom < _amount) revert NotEnoughBalance();
        updateValueAtNow(totalSupplyHistory, curTotalSupply - _amount);
        updateValueAtNow(balances[_owner], previousBalanceFrom - _amount);
        emit Transfer(_owner, address(0), _amount);
        return true;
    }

    ////////////////
    // Enable tokens transfers
    ////////////////

    /// @notice Enables token holders to transfer their tokens freely if true
    /// @param _transfersEnabled True if transfers are allowed in the clone
    function enableTransfers(bool _transfersEnabled) public onlyController {
        transfersEnabled = _transfersEnabled;
    }

    ////////////////
    // Internal helper functions to query and set a value in a snapshot array
    ////////////////

    /// @dev `getValueAt` retrieves the number of tokens at a given block number
    /// @param checkpoints The history of values being queried
    /// @param _block The block number to retrieve the value at
    /// @return The number of tokens being queried
    function getValueAt(Checkpoint[] storage checkpoints, uint256 _block) internal view returns (uint256) {
        if (checkpoints.length == 0) return 0;

        // Shortcut for the actual value
        if (_block >= checkpoints[checkpoints.length - 1].fromBlock) {
            return checkpoints[checkpoints.length - 1].value;
        }
        if (_block < checkpoints[0].fromBlock) return 0;

        // Binary search of the value in the array
        uint256 sMin = 0;
        uint256 max = checkpoints.length - 1;
        while (max > sMin) {
            uint256 mid = (max + sMin + 1) / 2;
            if (checkpoints[mid].fromBlock <= _block) {
                sMin = mid;
            } else {
                max = mid - 1;
            }
        }
        return checkpoints[sMin].value;
    }

    /// @dev `updateValueAtNow` used to update the `balances` map and the
    ///  `totalSupplyHistory`
    /// @param checkpoints The history of data being updated
    /// @param _value The new number of tokens
    function updateValueAtNow(Checkpoint[] storage checkpoints, uint256 _value) internal {
        if ((checkpoints.length == 0) || (checkpoints[checkpoints.length - 1].fromBlock < block.number)) {
            Checkpoint storage newCheckPoint = checkpoints.push();
            newCheckPoint.fromBlock = uint128(block.number);
            newCheckPoint.value = uint128(_value);
        } else {
            Checkpoint storage oldCheckPoint = checkpoints[checkpoints.length - 1];
            oldCheckPoint.value = uint128(_value);
        }
    }

    /// @dev Internal function to determine if an address is a contract
    /// @param _addr The address being queried
    /// @return True if `_addr` is a contract
    function isContract(address _addr) internal view returns (bool) {
        uint256 size;
        if (_addr == address(0)) return false;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

    /// @dev Helper function to return a min betwen the two uints
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @notice The fallback function: If the contract's controller has not been
    ///  set to 0, then the `proxyPayment` method is called which relays the
    ///  ether and creates tokens as described in the token controller contract
    receive() external payable {
        if (!isContract(controller)) revert ControllerNotSet();
        if (!TokenController(controller).proxyPayment{ value: msg.value }(msg.sender)) {
            revert ControllerRejected();
        }
    }

    //////////
    // Safety Methods
    //////////

    /// @notice This method can be used by the controller to extract mistakenly
    ///  sent tokens to this contract.
    /// @param _token The address of the token contract that you want to recover
    ///  set to 0 in case you want to extract ether.
    function claimTokens(IERC20 _token) public onlyController {
        if (address(_token) == address(0)) {
            controller.transfer(address(this).balance);
            return;
        }

        IERC20 token = _token;
        uint256 balance = token.balanceOf(address(this));
        token.transfer(controller, balance);
        emit ClaimedTokens(address(_token), controller, balance);
    }

    ////////////////
    // Events
    ////////////////
    event ClaimedTokens(address indexed _token, address indexed _controller, uint256 _amount);
}
