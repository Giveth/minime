pragma solidity ^0.4.13;

import './ISnapshotToken.sol';
import './IBasicToken.sol';
import './IERC20Token.sol';
import './IApproveAndCallFallback.sol';

// TODO: Anyone can create a token and disburse it, but then everyone
//       needs to pay extra gas for claim(). It is not possible to skip
//       these mallicious disbursals. Some solution strategies:
//        * Limit the people who can disburse to a trusted set
//        * Allow claims in any order

contract Disbursal is IApproveAndCallFallback {

////////////////
// Types
////////////////

    struct Disbursment {
        uint256 snapshot;
        IBasicToken disbursedToken;
        uint256 remainingAmount;
        uint256 remainingShares;
    }

////////////////
// State
////////////////

    ISnapshotToken public SHARE_TOKEN;

    Disbursment[] disbursments;

    mapping(address => uint256) claimed;

////////////////
// Events
////////////////

    event Disbursed(
        uint256 disbursalIndex,
        IBasicToken disbursedToken,
        uint256 amount,
        uint256 snapshot,
        uint256 totalShares
    );

    event Claimed(
        address beneficiary,
        uint256 disbursalIndex,
        IBasicToken disbursedToken,
        uint256 amount
    );

////////////////
// Constructor
////////////////

    function Disbursal(
        ISnapshotToken shareToken
    )
        public
    {
        SHARE_TOKEN = shareToken;
    }

////////////////
// Public functions
////////////////

    function claim()
        public
    {
        claim(msg.sender);
    }

    function claim(address beneficiary)
        public
    {
        for(uint256 i = claimed[beneficiary]; i < disbursments.length; ++i) {
            claim(beneficiary, i);
        }
    }

    function claim(address beneficiary, uint256 index)
        public
    {
        require(index < disbursments.length);
        require(claimed[beneficiary] == index);

        // Compute share
        // NOTE: By mainting both remaining counters we have automatic
        //       distribution of rounding errors between claims, with the
        //       final claim being exact and issuing all the remaining tokens.
        // TODO: Remove < 2¹²⁸ restrictions
        // TODO: Correct rounding instead of floor.
        Disbursment storage disbursment = disbursments[index];
        uint256 shares = SHARE_TOKEN.balanceOfAt(beneficiary, disbursment.snapshot);
        assert(disbursment.remainingShares < 2**128);
        assert(disbursment.remainingAmount < 2**128);
        assert(shares <= disbursment.remainingShares);
        uint256 amount = (disbursment.remainingAmount * shares) / disbursment.remainingShares;
        assert(amount <= disbursment.remainingAmount);

        // Update state
        disbursment.remainingAmount -= amount;
        disbursment.remainingShares -= shares;
        claimed[beneficiary] = index + 1;

        // Transfer tokens
        IBasicToken token = disbursment.disbursedToken;
        bool success = token.transfer(beneficiary, amount);
        require(success);

        // Log and return
        Claimed(beneficiary, index, token, amount);
    }

    // ERC20 receiver
    function receiveApproval(address from, uint256 amount, IERC20Token token, bytes data)
    {
        require(data.length == 0);

        // Transfer all allowed tokens to self.
        require(amount < 2**128);
        bool success = token.transferFrom(from, this, amount);
        require(success);

        // Disburse these tokens
        disburse(IBasicToken(token), amount);
    }

    // TODO: ERC223 style receiver

////////////////
// Internal functions
////////////////

    // TODO: Ideally we make this function public, and allow
    //       disbursal of any basic token. When counting how
    //       many tokens we need to disburse, a simple
    //       `balanceOf(this)` is insufficient, as it also
    //       contains the remaining amount from previous disbursments.
    function disburse(IBasicToken token, uint256 amount)
        internal
    {
        // Transfer all allowed tokens to self.
        require(amount < 2**128);

        // Verify our balance
        // TODO: we need to check for newly received tokens!

        // Create snapshot
        uint256 snapshot = SHARE_TOKEN.createSnapshot();
        uint256 totalShares = SHARE_TOKEN.totalSupplyAt(snapshot);
        require(totalShares < 2**128);

        // Create disbursal
        uint256 index = disbursments.length;
        disbursments.push(Disbursment({
            snapshot: snapshot,
            disbursedToken: token,
            remainingAmount: amount,
            remainingShares: totalShares
        }));

        // Log
        Disbursed(index, token, amount, snapshot, totalShares);
    }
}
