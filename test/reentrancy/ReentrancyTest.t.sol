// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { Deploy } from "../../script/Deploy.s.sol";
import { DeploymentConfig } from "../../script/DeploymentConfig.s.sol";
import { AttackController } from "./AttackController.sol";
import { AttackAccount } from "./AttackAccount.sol";
import { MiniMeToken } from "../../contracts/MiniMeToken.sol";

contract ReentrancyTest is Test {
    AttackController internal attackController;
    AttackAccount internal attackAccount;
    MiniMeToken internal minimeToken;
    DeploymentConfig internal deploymentConfig;
    address internal deployer;
    address internal attackerEOA = makeAddr("attackerEOA");

    function setUp() public {
        Deploy deployment = new Deploy();
        (deploymentConfig,, minimeToken) = deployment.run();
        (deployer,,,,,,) = deploymentConfig.activeNetworkConfig();

        vm.prank(attackerEOA);
        attackAccount = new AttackAccount(minimeToken);
        attackController = new AttackController(attackerEOA, attackAccount);
    }

    function testAttack() public {
        address sender = makeAddr("sender");
        address receiver = address(attackAccount);

        uint256 fundsAmount = 10_000;
        uint256 allowanceAmount = fundsAmount * 6;
        uint256 sendAmount = fundsAmount;

        // ensure `sender` has funds
        vm.prank(deployer);
        minimeToken.generateTokens(sender, fundsAmount);

        // change controller to AttackController
        vm.prank(deployer);
        minimeToken.changeController(payable(address(attackController)));

        // sender sends tokens to receiver
        vm.prank(sender);
        minimeToken.approve(receiver, allowanceAmount);

        attackAccount.attack(sender, receiver, sendAmount);

        assertEq(minimeToken.balanceOf(attackController.attackerEOA()), 0, "Attacker EOA should not receive any funds");
        assertEq(minimeToken.balanceOf(sender), fundsAmount - sendAmount, "Sender should have expected funds");
        assertEq(minimeToken.balanceOf(receiver), sendAmount, "Receiver should have expected funds");
    }
}
