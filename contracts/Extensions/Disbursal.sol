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

    mapping(address => mapping(uint256 => bool)) claimed;

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

    function claimable()
        public
        constant
        returns (uint256[])
    {
        return claimable(msg.sender);
    }

    function claimable(address beneficiary)
        public
        constant
        returns (uint256[])
    {
        return claimable(beneficiary, 0, disbursments.length);
    }

    function claimable(address beneficiary, uint256 from, uint256 to)
        public
        constant
        returns (uint256[])
    {
        require(from <= to);
        require(to < disbursments.length);
        uint256[] storage result;
        for(uint256 i = from; i < to; ++i) {
            if(claimable(beneficiary, i)) {
                result.push(i);
            }
        }
        return  result;
    }

    function claimable(address beneficiary, uint256 index)
        public
        constant
        returns (bool)
    {
        // Invalid index
        if(index >= disbursments.length) {
            return false;
        }

        // Already claimed
        if(claimed[beneficiary][index] == true) {
            return false;
        }

        // Check if `beneficiary` has shares
        Disbursment storage disbursment = disbursments[index];
        uint256 shares = SHARE_TOKEN.balanceOfAt(beneficiary, disbursment.snapshot);
        return  shares > 0;
    }

    function claim()
        public
    {
        claim(msg.sender);
    }

    function claim(address beneficiary)
        public
    {
        for(uint256 i = 0; i < disbursments.length; ++i) {
            if(claimed[beneficiary][i] == false) {
                claim(beneficiary, i);
            }
        }
    }

    function claim(address beneficiary, uint256[] indices)
        public
    {
        for(uint256 i = 0; i < indices.length; ++i) {
            claim(beneficiary, indices[i]);
        }
    }

    function claim(address beneficiary, uint256 index)
        public
    {
        require(index < disbursments.length);
        require(claimed[beneficiary][index] == false);

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
        uint256 amount = mulDiv(disbursment.remainingAmount, shares, disbursment.remainingShares);
        assert(amount <= disbursment.remainingAmount);

        // Update state
        // TODO: Can we reduce the number of state writes?
        disbursment.remainingAmount -= amount;
        disbursment.remainingShares -= shares;
        claimed[beneficiary][index] = true;

        // Transfer tokens
        IBasicToken token = disbursment.disbursedToken;
        bool success = token.transfer(beneficiary, amount);
        require(success);

        // Log and return
        Claimed(beneficiary, index, token, amount);
    }

    function disburseAllowance(IERC20Token token)
        public
    {
        uint256 amount = token.allowance(msg.sender, this);
        disburseAllowance(token, msg.sender);
    }

    function disburseAllowance(IERC20Token token, address from, uint256 amount)
        public
    {
        // Transfer all allowed tokens to self.
        require(amount < 2**128);
        bool success = token.transferFrom(from, this, amount);
        require(success);

        // Disburse these tokens
        disburse(IBasicToken(token), amount);
    }

    // ERC20 receiver
    function receiveApproval(address from, uint256 amount, IERC20Token token, bytes data)
        public
    {
        require(data.length == 0);
        disburseAllowance(token, from, amount)
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
        require(amount > 0);
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

    function mulDiv(uint256 a, uint256 n, uint256 d)
        internal
        constant
        returns (uint256)
    {
        require(a < 2**128);
        require(d < 2**128);
        require(n <= d);

        uint256 s = a * n;

        // Correct rounding
        s += n / 2;

        uint256 f = s / d;

        return f;
    }
}
