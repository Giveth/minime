// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { MiniMeToken } from "../../contracts/MiniMeToken.sol";

contract AttackAccount {
    address public owner = msg.sender;
    MiniMeToken public token;

    constructor(MiniMeToken _token) {
        token = _token;
    }

    function attack(address _from, address _to, uint256 _amount) external {
        token.transferFrom(_from, _to, _amount);
    }
}
