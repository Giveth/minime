pragma solidity ^0.4.13;

import './IERC20Token.sol';

contract IApproveAndCallFallback {

    function receiveApproval(
        address from,
        uint256 amount,
        IERC20Token token,
        bytes data
    )
        public;

}
