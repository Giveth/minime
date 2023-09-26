// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { Deploy } from "../script/Deploy.s.sol";
import { DeploymentConfig } from "../script/DeploymentConfig.s.sol";

import { NotAuthorized } from "../contracts/Controlled.sol";
import {
    MiniMeToken,
    TransfersDisabled,
    InvalidDestination,
    NotEnoughBalance,
    NotEnoughAllowance,
    AllowanceAlreadySet
} from "../contracts/MiniMeToken.sol";
import { MiniMeTokenFactory } from "../contracts/MiniMeTokenFactory.sol";

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
        vm.pauseGasMetering();
        assertEq(minimeToken.name(), name, "name should be correct");
        assertEq(minimeToken.symbol(), symbol, "symbol should be correct");
        assertEq(minimeToken.decimals(), decimals, "decimals should be correct");
        assertEq(minimeToken.controller(), deployer, "controller should be correct");
        assertEq(address(minimeToken.parentToken()), parentToken, "parent token should be correct");
        assertEq(minimeToken.parentSnapShotBlock(), parentSnapShotBlock, "parent snapshot block should be correct");
        vm.resumeGasMetering();
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
        vm.expectRevert(NotAuthorized.selector);
        minimeToken.generateTokens(accounts[0], 10);
    }

    function testGenerateTokens() public {
        _generateTokens(accounts[0], 10);
        vm.pauseGasMetering();
        assertEq(minimeToken.totalSupply(), 10, "total supply should be correct");
        assertEq(minimeToken.balanceOf(accounts[0]), 10, "receiver should have balance");
        vm.resumeGasMetering();
    }
}

contract TransferTest is MiniMeTokenTest {
    function setUp() public virtual override {
        MiniMeTokenTest.setUp();
    }

    function testMultipleTransferToSame() public {
        vm.pauseGasMetering();
        _generateTokens(accounts[0], 10);
        _generateTokens(accounts[1], 10);
        vm.roll(block.number + 1);

        vm.prank(accounts[0]);
        vm.resumeGasMetering();
        minimeToken.transfer(accounts[2], 2);
        vm.pauseGasMetering();

        vm.prank(accounts[1]);
        vm.resumeGasMetering();
        minimeToken.transfer(accounts[2], 2);
        vm.pauseGasMetering();

        assertEq(minimeToken.balanceOf(accounts[0]), 8, "balance of sender 0 should be reduced");
        assertEq(minimeToken.balanceOf(accounts[1]), 8, "balance of sender 1 should be reduced");
        assertEq(minimeToken.balanceOf(accounts[2]), 4, "balance of receiver should be increased");

        vm.resumeGasMetering();
    }

    function testMultipleTransferToSame2() public {
        vm.pauseGasMetering();
        _generateTokens(accounts[0], 10);
        _generateTokens(accounts[1], 10);
        _generateTokens(accounts[2], 1);
        vm.roll(block.number + 1);

        vm.prank(accounts[0]);
        vm.resumeGasMetering();
        minimeToken.transfer(accounts[2], 2);
        vm.pauseGasMetering();

        vm.prank(accounts[1]);
        vm.resumeGasMetering();
        minimeToken.transfer(accounts[2], 2);
        vm.pauseGasMetering();

        assertEq(minimeToken.balanceOf(accounts[0]), 8, "balance of sender 0 should be reduced");
        assertEq(minimeToken.balanceOf(accounts[1]), 8, "balance of sender 1 should be reduced");
        assertEq(minimeToken.balanceOf(accounts[2]), 5, "balance of receiver should be increased");

        vm.resumeGasMetering();
    }

    function testDoubleTransfer() public {
        vm.pauseGasMetering();

        _generateTokens(accounts[0], 10);
        vm.roll(block.number + 1);
        vm.startPrank(accounts[0]);
        vm.resumeGasMetering();
        minimeToken.transfer(accounts[1], 2);
        minimeToken.transfer(accounts[1], 2);
        vm.pauseGasMetering();
        vm.stopPrank();

        assertEq(minimeToken.balanceOf(accounts[0]), 6, "balance of sender should be reduced");
        assertEq(minimeToken.balanceOf(accounts[1]), 4, "balance of receiver should be increased");

        vm.resumeGasMetering();
    }

    function testDoubleTransfer2() public {
        vm.pauseGasMetering();

        _generateTokens(accounts[0], 10);
        _generateTokens(accounts[1], 1);
        vm.roll(block.number + 1);
        vm.startPrank(accounts[0]);
        vm.resumeGasMetering();
        minimeToken.transfer(accounts[1], 2);
        minimeToken.transfer(accounts[1], 2);
        vm.pauseGasMetering();
        vm.stopPrank();

        assertEq(minimeToken.balanceOf(accounts[0]), 6, "balance of sender should be reduced");
        assertEq(minimeToken.balanceOf(accounts[1]), 5, "balance of receiver should be increased");

        vm.resumeGasMetering();
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

        assertEq(minimeToken.totalSupply(), 10, "total supply should be correct");
        assertEq(minimeToken.balanceOf(accounts[0]), 8, "balance of sender should be reduced");
        assertEq(minimeToken.balanceOf(accounts[1]), 2, "balance of receiver should be increased");

        assertEq(minimeToken.balanceOfAt(accounts[0], currentBlock), 10, "balance at original block should be correct");
        vm.resumeGasMetering();
    }

    function testTransfer2() public {
        vm.pauseGasMetering();
        uint256 currentBlock = block.number;
        uint256 nextBlock = currentBlock + 1;

        _generateTokens(accounts[0], 10);
        _generateTokens(accounts[1], 1);

        // enforce the next block
        vm.roll(nextBlock);

        vm.prank(accounts[0]);

        vm.resumeGasMetering();
        minimeToken.transfer(accounts[1], 2);
        vm.pauseGasMetering();

        assertEq(minimeToken.balanceOf(accounts[0]), 8, "balance of sender should be reduced");
        assertEq(minimeToken.balanceOf(accounts[1]), 3, "balance of receiver should be increased");

        vm.resumeGasMetering();
    }

    function testInvalidDestinationTransfer() public {
        vm.pauseGasMetering();
        _generateTokens(accounts[0], 10);
        vm.expectRevert(InvalidDestination.selector);
        vm.prank(accounts[0]);
        vm.resumeGasMetering();
        minimeToken.transfer(address(0), 2);
    }

    function testInvalidDestinationTransfer2() public {
        vm.pauseGasMetering();
        _generateTokens(accounts[0], 10);
        vm.expectRevert(InvalidDestination.selector);
        vm.prank(accounts[0]);
        vm.resumeGasMetering();
        minimeToken.transfer(address(minimeToken), 2);
    }

    function testTransferDisabled() public {
        vm.pauseGasMetering();
        _generateTokens(accounts[0], 10);
        vm.prank(deployer);
        minimeToken.enableTransfers(false);
        vm.prank(accounts[0]);
        vm.expectRevert(TransfersDisabled.selector);
        vm.resumeGasMetering();
        minimeToken.transfer(accounts[1], 2);
        vm.pauseGasMetering();
        assertEq(minimeToken.balanceOf(accounts[0]), 10, "balance of sender shouldn't be reduced");
        assertEq(minimeToken.balanceOf(accounts[1]), 0, "balance of receiver shouldn't be increased");
        vm.resumeGasMetering();
    }

    function testTransferFromDisabled() public {
        vm.pauseGasMetering();
        _generateTokens(accounts[0], 10);
        vm.prank(accounts[0]);
        minimeToken.approve(accounts[1], 2);
        vm.prank(deployer);
        minimeToken.enableTransfers(false);
        vm.prank(accounts[1]);
        vm.expectRevert(TransfersDisabled.selector);
        vm.resumeGasMetering();
        minimeToken.transferFrom(accounts[0], accounts[1], 2);
        vm.pauseGasMetering();
        assertEq(minimeToken.balanceOf(accounts[0]), 10, "balance of sender shouldn't be reduced");
        assertEq(minimeToken.balanceOf(accounts[1]), 0, "balance of receiver shouldn't be increased");
        vm.resumeGasMetering();
    }

    function testTransferNoBalance() public {
        vm.pauseGasMetering();
        vm.prank(accounts[0]);
        vm.expectRevert(NotEnoughBalance.selector);
        vm.resumeGasMetering();
        minimeToken.transfer(accounts[1], 2);
        vm.pauseGasMetering();
        assertEq(minimeToken.balanceOf(accounts[0]), 0, "balance of sender shouldn't be reduced");
        assertEq(minimeToken.balanceOf(accounts[1]), 0, "balance of receiver shouldn't be increased");
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
        assertEq(allowed, 2, "allowance should be correct");

        uint256 currentBlock = block.number;
        uint256 nextBlock = currentBlock + 1;

        // ensure `accounts[0]` has tokens
        _generateTokens(accounts[0], 10);

        // enforce the next block
        vm.roll(nextBlock);

        vm.prank(accounts[1]);
        minimeToken.transferFrom(accounts[0], accounts[2], 1);

        allowed = minimeToken.allowance(accounts[0], accounts[1]);
        assertEq(allowed, 1, "allowance should be reduced");

        assertEq(minimeToken.totalSupply(), 10, "total supply should be correct");
        assertEq(minimeToken.balanceOf(accounts[0]), 9, "balance of sender should be reduced");
        assertEq(minimeToken.balanceOf(accounts[2]), 1, "balance of receiver should be increased");

        // check balance at blocks
        assertEq(minimeToken.balanceOfAt(accounts[0], currentBlock), 10, "balance at original block should be correct");
        assertEq(minimeToken.balanceOfAt(accounts[0], nextBlock), 9, "balance at next block should be correct");
        assertEq(minimeToken.balanceOfAt(accounts[2], nextBlock), 1, "balance at next block should be correct");
        vm.resumeGasMetering();
    }

    function testNoAllowance() public {
        vm.pauseGasMetering();
        _generateTokens(accounts[0], 10);
        vm.prank(accounts[1]);
        uint256 allowed = minimeToken.allowance(accounts[0], accounts[1]);
        assertEq(allowed, 0, "allowance should be correct");
        vm.expectRevert(NotEnoughAllowance.selector);
        vm.resumeGasMetering();
        minimeToken.transferFrom(accounts[0], accounts[1], 1);
    }

    function testApproveTransferDisabled() public {
        vm.pauseGasMetering();
        _generateTokens(accounts[0], 10);
        vm.prank(deployer);
        minimeToken.enableTransfers(false);
        vm.prank(accounts[0]);
        vm.expectRevert(TransfersDisabled.selector);
        vm.resumeGasMetering();
        minimeToken.approve(accounts[1], 2);
        vm.pauseGasMetering();
        assertEq(minimeToken.allowance(accounts[0], accounts[1]), 0, "allowance should be 0");
        vm.resumeGasMetering();
    }

    function testAllowanceAlreadySet() public {
        vm.pauseGasMetering();
        _generateTokens(accounts[0], 10);
        vm.startPrank(accounts[0]);
        vm.resumeGasMetering();
        minimeToken.approve(accounts[1], 2);
        vm.pauseGasMetering();
        assertEq(minimeToken.allowance(accounts[0], accounts[1]), 2, "allowance should be 2");
        vm.expectRevert(AllowanceAlreadySet.selector);
        vm.resumeGasMetering();
        minimeToken.approve(accounts[1], 3);
        vm.pauseGasMetering();
        vm.stopPrank();
        assertEq(minimeToken.allowance(accounts[0], accounts[1]), 2, "allowance should stay 2");
        vm.resumeGasMetering();
    }

    function testAllowanceReset() public {
        vm.pauseGasMetering();
        _generateTokens(accounts[0], 10);
        vm.startPrank(accounts[0]);
        vm.resumeGasMetering();
        minimeToken.approve(accounts[1], 2);
        vm.pauseGasMetering();
        assertEq(minimeToken.allowance(accounts[0], accounts[1]), 2, "allowance should be 2");
        vm.resumeGasMetering();
        minimeToken.approve(accounts[1], 0);
        vm.pauseGasMetering();
        assertEq(minimeToken.allowance(accounts[0], accounts[1]), 0, "allowance should be 0");
        vm.resumeGasMetering();
        minimeToken.approve(accounts[1], 3);
        vm.pauseGasMetering();
        vm.stopPrank();
        assertEq(minimeToken.allowance(accounts[0], accounts[1]), 3, "allowance should be 3");
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
        assertEq(minimeToken.totalSupply(), 7, "total supply should be correct");
        assertEq(minimeToken.balanceOf(accounts[0]), 7, "balance of account should be reduced");
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
        assertEq(address(clone.parentToken()), address(minimeToken), "parent token should be correct");
        assertEq(clone.parentSnapShotBlock(), block.number, "parent snapshot block should be correct");
        assertEq(clone.totalSupply(), 15, "total supply should be correct");
        assertEq(clone.balanceOf(accounts[0]), 7, "balance of account 0 should be correct");
        assertEq(clone.balanceOf(accounts[1]), 3, "balance of account 1 should be correct");
        assertEq(clone.balanceOf(accounts[2]), 5, "balance of account 2 should be correct");

        assertEq(clone.totalSupplyAt(currentBlock), 7, "total supply at current block should be correct");
        assertEq(clone.totalSupplyAt(nextBlock), 10, "total supply at next block should be correct");

        assertEq(
            clone.balanceOfAt(accounts[0], currentBlock), 7, "balance of account 0 at current block should be correct"
        );
        assertEq(
            clone.balanceOfAt(accounts[1], currentBlock), 0, "balance of account 1 at current block should be correct"
        );
        assertEq(
            clone.balanceOfAt(accounts[2], currentBlock), 0, "balance of account 2 at current block should be correct"
        );

        assertEq(clone.balanceOfAt(accounts[0], nextBlock), 7, "balance of account 0 at next block should be correct");
        assertEq(clone.balanceOfAt(accounts[1], nextBlock), 3, "balance of account 1 at next block should be correct");
        assertEq(clone.balanceOfAt(accounts[2], nextBlock), 0, "balance of account 2 at next block should be correct");

        assertEq(
            clone.balanceOfAt(accounts[0], secondNextBlock),
            7,
            "balance of account 0 at second next block should be correct"
        );
        assertEq(
            clone.balanceOfAt(accounts[1], secondNextBlock),
            3,
            "balance of account 1 at second next block should be correct"
        );
        assertEq(
            clone.balanceOfAt(accounts[2], secondNextBlock),
            5,
            "balance of account 2 at second next block should be correct"
        );
        vm.resumeGasMetering();
    }

    function testGenerateTokens() public {
        vm.pauseGasMetering();
        _generateTokens(accounts[0], 10);

        vm.prank(deployer);
        MiniMeToken clone = _createClone();
        assertEq(clone.totalSupply(), 10, "total supply should be correct");

        vm.prank(deployer);
        vm.resumeGasMetering();
        clone.generateTokens(accounts[0], 5);
        assertEq(clone.totalSupply(), 15, "total supply should be correct");
    }
}

contract ClaimTokensTest is MiniMeTokenTest {
    function setUp() public virtual override {
        MiniMeTokenTest.setUp();
    }

    function testClaimERC20() public {
        vm.pauseGasMetering();
        vm.startPrank(deployer);
        MiniMeToken claimTest = new MiniMeToken(
          minimeTokenFactory, 
          MiniMeToken(payable(address(0))), 
          0, 
          "TestClaim", 
          18, 
          "TST", 
          true
        );
        claimTest.generateTokens(address(minimeToken), 1234);

        assertEq(claimTest.balanceOf(address(minimeToken)), 1234, "claimTest minimeToken balance should be correct");
        assertEq(claimTest.balanceOf(address(deployer)), 0, "claimTest deployer balance should be correct");

        vm.resumeGasMetering();
        minimeToken.claimTokens(claimTest);
        vm.pauseGasMetering();

        vm.stopPrank();

        assertEq(claimTest.balanceOf(address(minimeToken)), 0, "claimTest minimeToken balance should be correct");
        assertEq(claimTest.balanceOf(address(deployer)), 1234, "claimTest deployer balance should be correct");
        vm.resumeGasMetering();
    }

    function testClaimETH() public {
        vm.pauseGasMetering();
        vm.startPrank(deployer);
        vm.deal(address(minimeToken), 1234);
        assertEq(address(minimeToken).balance, 1234, "minimeToken balance should be correct");
        assertEq(address(deployer).balance, 0, "deployer balance should be correct");

        vm.resumeGasMetering();
        minimeToken.claimTokens(MiniMeToken(payable(address(0))));
        vm.pauseGasMetering();

        assertEq(address(minimeToken).balance, 0, "minimeToken balance should be correct");
        assertEq(address(deployer).balance, 1234, "deployer balance should be correct");

        vm.stopPrank();
        vm.resumeGasMetering();
    }

    function testClaimSelf() public {
        vm.pauseGasMetering();
        vm.startPrank(deployer);
        minimeToken.generateTokens(address(minimeToken), 1234);
        assertEq(minimeToken.balanceOf(address(minimeToken)), 1234, "minimeToken minimeToken balance should be 1234");
        assertEq(minimeToken.balanceOf(address(deployer)), 0, "minimeToken deployer balance should be 0");

        vm.resumeGasMetering();
        minimeToken.claimTokens(minimeToken);
        vm.pauseGasMetering();

        assertEq(minimeToken.balanceOf(address(minimeToken)), 0, "minimeToken minimeToken balance should be 0");
        assertEq(minimeToken.balanceOf(address(deployer)), 1234, "minimeToken deployer balance should be 1234");
        vm.stopPrank();
        vm.resumeGasMetering();
    }
}
