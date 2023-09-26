// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { Deploy } from "../script/Deploy.s.sol";
import { DeploymentConfig } from "../script/DeploymentConfig.s.sol";

import { MiniMeToken } from "../contracts/MiniMeToken.sol";
import { MiniMeTokenFactory } from "../contracts/MiniMeToken.sol";

contract MiniMeTokenTest is Test {
    DeploymentConfig internal deploymentConfig;
    MiniMeTokenFactory internal minimeTokenFactory;
    MiniMeToken internal minimeToken;

    address internal deployer;

    address[] internal accounts;

    function setUp() public virtual {
        Deploy deployment = new Deploy();
        (deploymentConfig, minimeTokenFactory, minimeToken) = deployment.run();
        (deployer,,,,,,) = deploymentConfig.activeNetworkConfig();

        accounts = new address[](4);
        accounts[0] = makeAddr("account0");
        accounts[1] = makeAddr("account1");
        accounts[2] = makeAddr("account2");
        accounts[3] = makeAddr("account3");
    }

    function testDeployment() public {
        (, address parentToken, uint256 parentSnapShotBlock, string memory name, uint8 decimals, string memory symbol,)
        = deploymentConfig.activeNetworkConfig();
        assertEq(minimeToken.name(), name);
        assertEq(minimeToken.symbol(), symbol);
        assertEq(minimeToken.decimals(), decimals);
        assertEq(minimeToken.controller(), deployer);
        assertEq(address(minimeToken.parentToken()), parentToken);
        assertEq(minimeToken.parentSnapShotBlock(), parentSnapShotBlock);
    }

    function _generateTokens(address to, uint256 amount) internal {
        vm.prank(deployer);
        minimeToken.generateTokens(to, amount);
    }
}

contract GenerateTokensTest is MiniMeTokenTest {
    function setUp() public virtual override {
        MiniMeTokenTest.setUp();
    }

    function test_RevertWhen_SenderIsNotController() public {
        vm.expectRevert();
        minimeToken.generateTokens(accounts[0], 10);
    }

    function testGenerateTokens() public {
        vm.resumeGasMetering();
        _generateTokens(accounts[0], 10);
        vm.pauseGasMetering();
        assertEq(minimeToken.totalSupply(), 10);
        assertEq(minimeToken.balanceOf(accounts[0]), 10);
        vm.resumeGasMetering();
    }
}

contract TransferTest is MiniMeTokenTest {
    function setUp() public virtual override {
        MiniMeTokenTest.setUp();
    }

    function testTransfer() public {
        vm.pauseGasMetering();
        uint256 currentBlock = block.number;
        uint256 nextBlock = currentBlock + 1;

        _generateTokens(accounts[0], 10);

        // enforce the next block
        vm.roll(nextBlock);

        vm.prank(accounts[0]);

        vm.resumeGasMetering();
        minimeToken.transfer(accounts[1], 2);
        vm.pauseGasMetering();

        assertEq(minimeToken.totalSupply(), 10);
        assertEq(minimeToken.balanceOf(accounts[0]), 8);
        assertEq(minimeToken.balanceOf(accounts[1]), 2);

        // check balance at original block
        assertEq(minimeToken.balanceOfAt(accounts[0], currentBlock), 10);
        vm.resumeGasMetering();
    }
    
}

contract AllowanceTest is MiniMeTokenTest {
    function setUp() public virtual override {
        MiniMeTokenTest.setUp();
    }

    function testAllowance() public {
        vm.pauseGasMetering();
        vm.prank(accounts[0]);
        vm.resumeGasMetering();
        minimeToken.approve(accounts[1], 2);
        vm.pauseGasMetering();
        uint256 allowed = minimeToken.allowance(accounts[0], accounts[1]);
        assertEq(allowed, 2);

        uint256 currentBlock = block.number;
        uint256 nextBlock = currentBlock + 1;

        // ensure `accounts[0]` has tokens
        _generateTokens(accounts[0], 10);

        // enforce the next block
        vm.roll(nextBlock);

        vm.prank(accounts[1]);
        minimeToken.transferFrom(accounts[0], accounts[2], 1);

        allowed = minimeToken.allowance(accounts[0], accounts[1]);
        assertEq(allowed, 1);

        assertEq(minimeToken.totalSupply(), 10);
        assertEq(minimeToken.balanceOf(accounts[0]), 9);
        assertEq(minimeToken.balanceOf(accounts[2]), 1);

        // check balance at blocks
        assertEq(minimeToken.balanceOfAt(accounts[0], currentBlock), 10);
        assertEq(minimeToken.balanceOfAt(accounts[0], nextBlock), 9);
        assertEq(minimeToken.balanceOfAt(accounts[2], nextBlock), 1);
        vm.resumeGasMetering();
    }
}

contract DestroyTokensTest is MiniMeTokenTest {
    function setUp() public virtual override {
        MiniMeTokenTest.setUp();
    }

    function testDestroyTokens() public {
        vm.pauseGasMetering();
        // ensure `accounts[0]` has tokens
        _generateTokens(accounts[0], 10);

        vm.prank(deployer);
        vm.resumeGasMetering();
        minimeToken.destroyTokens(accounts[0], 3);
        vm.pauseGasMetering();
        assertEq(minimeToken.totalSupply(), 7);
        assertEq(minimeToken.balanceOf(accounts[0]), 7);
        vm.resumeGasMetering();
    }
}

contract CreateCloneTokenTest is MiniMeTokenTest {
    function setUp() public virtual override {
        MiniMeTokenTest.setUp();
    }

    function _createClone() internal returns (MiniMeToken clone) {
        return new MiniMeToken(
          minimeTokenFactory, 
          minimeToken, 
          block.number, 
          "Clone Token 1",
          18,
          "MMTc",
          true);
    }

    function testCreateCloneToken() public {
        vm.pauseGasMetering();
        // fund some accounts to later check if cloned token has same balances
        uint256 currentBlock = block.number;
        _generateTokens(accounts[0], 7);
        uint256 nextBlock = block.number + 1;
        vm.roll(nextBlock);
        _generateTokens(accounts[1], 3);
        uint256 secondNextBlock = block.number + 2;
        vm.roll(secondNextBlock);
        _generateTokens(accounts[2], 5);
        vm.resumeGasMetering();
        MiniMeToken clone = _createClone();
        vm.pauseGasMetering();
        assertEq(address(clone.parentToken()), address(minimeToken));
        assertEq(clone.parentSnapShotBlock(), block.number);
        assertEq(clone.totalSupply(), 15);
        assertEq(clone.balanceOf(accounts[0]), 7);
        assertEq(clone.balanceOf(accounts[1]), 3);
        assertEq(clone.balanceOf(accounts[2]), 5);

        assertEq(clone.totalSupplyAt(currentBlock), 7);
        assertEq(clone.totalSupplyAt(nextBlock), 10);

        assertEq(clone.balanceOfAt(accounts[0], currentBlock), 7);
        assertEq(clone.balanceOfAt(accounts[1], currentBlock), 0);
        assertEq(clone.balanceOfAt(accounts[2], currentBlock), 0);

        assertEq(clone.balanceOfAt(accounts[0], nextBlock), 7);
        assertEq(clone.balanceOfAt(accounts[1], nextBlock), 3);
        assertEq(clone.balanceOfAt(accounts[2], nextBlock), 0);

        assertEq(clone.balanceOfAt(accounts[0], secondNextBlock), 7);
        assertEq(clone.balanceOfAt(accounts[1], secondNextBlock), 3);
        assertEq(clone.balanceOfAt(accounts[2], secondNextBlock), 5);
        vm.resumeGasMetering();
    }

    function testGenerateTokens() public {
        vm.pauseGasMetering();
        _generateTokens(accounts[0], 10);

        vm.prank(deployer);
        MiniMeToken clone = _createClone();
        assertEq(clone.totalSupply(), 10);

        vm.prank(deployer);
        vm.resumeGasMetering();
        clone.generateTokens(accounts[0], 5);
    }
}
