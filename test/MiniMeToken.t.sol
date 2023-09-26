// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { Deploy } from "../script/Deploy.s.sol";
import { DeploymentConfig } from "../script/DeploymentConfig.s.sol";

import { TokenController } from "../contracts/TokenController.sol";
import { NotAuthorized } from "../contracts/Controlled.sol";
import {
    TransfersDisabled,
    InvalidDestination,
    NotEnoughBalance,
    NotEnoughSupply,
    NotEnoughAllowance,
    AllowanceAlreadySet,
    ControllerRejected,
    Overflow,
    ParentSnapshotNotReached,
    IERC20
} from "../contracts/MiniMeBase.sol";
import { MiniMeToken } from "../contracts/MiniMeToken.sol";
import { MiniMeTokenFactory } from "../contracts/MiniMeTokenFactory.sol";
import { ApproveAndCallFallBack } from "../contracts/ApproveAndCallFallBack.sol";

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
        assertEq(minimeToken.totalSupply(), 0, "total supply should be correct");
        vm.resumeGasMetering();
    }

    function _generateTokens(address to, uint256 amount) internal {
        vm.prank(deployer);
        minimeToken.generateTokens(to, amount);
    }
}

contract AcceptingController is TokenController {
    event Received(address, uint256);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function proxyPayment(address) public payable override returns (bool) {
        return true;
    }

    function onTransfer(address, address, uint256) public pure override returns (bool) {
        return true;
    }

    function onApprove(address, address, uint256) public pure override returns (bool) {
        return true;
    }
}

contract RejectingController is TokenController {
    function proxyPayment(address) public payable override returns (bool) {
        return false;
    }

    function onTransfer(address, address, uint256) public pure override returns (bool) {
        return false;
    }

    function onApprove(address, address, uint256) public pure override returns (bool) {
        return false;
    }
}

contract ReceiveTest is MiniMeTokenTest {
    function setUp() public virtual override {
        MiniMeTokenTest.setUp();
    }

    function testAcceptingEther() public {
        vm.pauseGasMetering();
        AcceptingController acceptingController = new AcceptingController();
        vm.prank(deployer);
        minimeToken.changeController(payable(address(acceptingController)));

        vm.deal(address(accounts[0]), 10 ether);
        vm.startPrank(address(accounts[0]));
        vm.resumeGasMetering();
        (bool result,) = payable(address(minimeToken)).call{ value: 1 ether }("");
        vm.pauseGasMetering();
        vm.stopPrank();

        assertTrue(result, "ether transfer should be successful");
        assertEq(address(minimeToken).balance, 0, "minimeToken balance should be correct");
        assertEq(address(acceptingController).balance, 1 ether, "acceptingController balance should be correct");
        assertEq(address(accounts[0]).balance, 9 ether, "account balance should be correct");
        vm.resumeGasMetering();
    }

    function testRejectingEther() public {
        vm.pauseGasMetering();
        RejectingController rejectingController = new RejectingController();
        vm.prank(deployer);
        minimeToken.changeController(payable(address(rejectingController)));

        vm.deal(address(accounts[0]), 10 ether);
        vm.startPrank(address(accounts[0]));
        vm.resumeGasMetering();
        (bool result,) = payable(address(minimeToken)).call{ value: 1 ether }("");
        vm.pauseGasMetering();
        vm.stopPrank();

        assertFalse(result, "ether transfer should be rejected");
        assertEq(address(minimeToken).balance, 0, "minimeToken balance should be correct");
        assertEq(address(rejectingController).balance, 0, "rejectingController balance should be correct");
        assertEq(address(accounts[0]).balance, 10 ether, "account balance should be correct");
        vm.resumeGasMetering();
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

    function testGenerateTokensSupplyOverflow() public {
        vm.pauseGasMetering();
        uint128 max_uint128;
        unchecked {
            max_uint128 = max_uint128 - 1;
        }
        _generateTokens(accounts[0], max_uint128);
        vm.expectRevert(Overflow.selector);
        _generateTokens(accounts[1], 1);
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

    function testRejectedTransfer() public {
        vm.pauseGasMetering();
        address payable rejectingController = payable(address(new RejectingController()));
        _generateTokens(accounts[0], 10);
        vm.prank(deployer);
        minimeToken.changeController(rejectingController);
        vm.prank(accounts[0]);
        vm.expectRevert(ControllerRejected.selector);
        vm.resumeGasMetering();
        minimeToken.transfer(accounts[1], 2);
        vm.pauseGasMetering();
        assertEq(minimeToken.balanceOf(accounts[0]), 10, "balance of sender shouldn't be reduced");
        assertEq(minimeToken.balanceOf(accounts[1]), 0, "balance of receiver shouldn't be increased");
        vm.resumeGasMetering();
    }

    function testTransferControllerZero() public {
        vm.pauseGasMetering();
        _generateTokens(accounts[0], 10);
        vm.prank(deployer);
        minimeToken.changeController(payable(address(0)));
        vm.prank(accounts[0]);
        vm.resumeGasMetering();
        minimeToken.transfer(accounts[1], 2);
        vm.pauseGasMetering();
        assertEq(minimeToken.balanceOf(accounts[0]), 8, "balance of sender should be reduced");
        assertEq(minimeToken.balanceOf(accounts[1]), 2, "balance of receiver should be increased");
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

    function testApproveAndCall() public {
        vm.pauseGasMetering();
        _generateTokens(accounts[0], 10);
        ApproverAccount approverAccount = new ApproverAccount(minimeToken);
        vm.startPrank(accounts[0]);
        vm.resumeGasMetering();
        minimeToken.approveAndCall(
            address(approverAccount), 2, abi.encodeWithSelector(approverAccount.depositToken1.selector, "message", 123)
        );
        vm.pauseGasMetering();
        assertEq(minimeToken.allowance(accounts[0], address(approverAccount)), 0, "allowance should be 0");
        assertEq(minimeToken.balanceOf(address(approverAccount)), 2, "approverAccount should have 2 tokens");
        assertEq(minimeToken.balanceOf(accounts[0]), 8, "balance of sender should be reduced");
        assertEq(approverAccount.message(), "message", "message should be correct");
        minimeToken.approveAndCall(
            address(approverAccount), 2, abi.encodeWithSelector(approverAccount.depositToken2.selector, true, "data")
        );
        assertEq(minimeToken.allowance(accounts[0], address(approverAccount)), 0, "allowance should be 0");
        assertEq(minimeToken.balanceOf(address(approverAccount)), 4, "approverAccount should have 2 tokens");
        assertEq(minimeToken.balanceOf(accounts[0]), 6, "balance of sender should be reduced");
        assertEq(approverAccount.data(), "data", "data should be correct");
        vm.expectRevert("ApproverAccount: invalid method");
        minimeToken.approveAndCall(
            address(approverAccount),
            2,
            abi.encodeWithSelector(approverAccount.unsupportedMethod.selector, true, "data")
        );
        vm.stopPrank();
        vm.resumeGasMetering();
    }

    function testRejectedApproval() public {
        vm.pauseGasMetering();
        address payable rejectingController = payable(address(new RejectingController()));
        _generateTokens(accounts[0], 10);
        vm.prank(deployer);
        minimeToken.changeController(rejectingController);
        vm.prank(accounts[0]);
        vm.expectRevert(ControllerRejected.selector);
        vm.resumeGasMetering();
        minimeToken.approve(accounts[1], 2);
        vm.pauseGasMetering();
        assertEq(minimeToken.allowance(accounts[0], accounts[1]), 0, "allowance should be 0");
        vm.resumeGasMetering();
    }
}

contract ApproverAccount is ApproveAndCallFallBack {
    IERC20 public token;

    string public message;
    bytes public data;

    constructor(IERC20 _token) {
        token = _token;
    }

    event ApprovalReceived(address _from, uint256 _amount, address _token, bytes _data);
    event TokenDeposit1(address indexed _from, uint256 _amount, string _message, uint256 _number);
    event TokenDeposit2(address indexed _from, uint256 _amount, bool _value, bytes _data);

    function receiveApproval(address _from, uint256 _amount, address _token, bytes memory _data) public override {
        emit ApprovalReceived(_from, _amount, _token, _data);
        require(_token == address(token), "ApproverAccount: token is not correct");
        bytes4 sig = abiDecodeSig(_data);
        bytes memory cdata = slice(_data, 4, _data.length - 4);
        if (sig == this.depositToken1.selector) {
            (string memory _message, uint256 _number) = abi.decode(cdata, (string, uint256));
            depositToken1(_from, _amount, _message, _number);
        } else if (sig == this.depositToken2.selector) {
            (bool _value, bytes memory _decodedData) = abi.decode(cdata, (bool, bytes));
            depositToken2(_from, _amount, _value, _decodedData);
        } else {
            revert("ApproverAccount: invalid method");
        }
    }

    function depositToken1(string memory _message, uint256 _number) external {
        depositToken1(msg.sender, token.allowance(msg.sender, address(this)), _message, _number);
    }

    function depositToken2(bool _value, bytes memory _data) external {
        depositToken2(msg.sender, token.allowance(msg.sender, address(this)), _value, _data);
    }

    function depositToken1(address _from, uint256 _amount, string memory _message, uint256 _number) internal {
        IERC20(token).transferFrom(_from, address(this), _amount);
        message = _message;
        emit TokenDeposit1(_from, _amount, _message, _number);
    }

    function depositToken2(address _from, uint256 _amount, bool _value, bytes memory _data) internal {
        IERC20(token).transferFrom(_from, address(this), _amount);
        data = _data;
        emit TokenDeposit2(_from, _amount, _value, _data);
    }

    function unsupportedMethod() external {
        revert("ApproverAccount: unsupported method");
    }
    /**
     * @dev decodes sig of abi encoded call
     * @param _data abi encoded data
     * @return sig (first 4 bytes)
     */

    function abiDecodeSig(bytes memory _data) private pure returns (bytes4 sig) {
        assembly {
            sig := mload(add(_data, add(0x20, 0)))
        }
    }

    /**
     * @dev get a slice of byte array
     * @param _bytes source
     * @param _start pointer
     * @param _length size to read
     * @return sliced bytes
     */
    function slice(bytes memory _bytes, uint256 _start, uint256 _length) private pure returns (bytes memory) {
        require(_bytes.length >= (_start + _length));

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
            case 0 {
                // Get a location of some free memory and store it in tempBytes as
                // Solidity does for memory variables.
                tempBytes := mload(0x40)

                // The first word of the slice result is potentially a partial
                // word read from the original array. To read it, we calculate
                // the length of that partial word and start copying that many
                // bytes into the array. The first word we copy will start with
                // data we don't care about, but the last `lengthmod` bytes will
                // land at the beginning of the contents of the new array. When
                // we're done copying, we overwrite the full first word with
                // the actual length of the slice.
                let lengthmod := and(_length, 31)

                // The multiplication in the next line is necessary
                // because when slicing multiples of 32 bytes (lengthmod == 0)
                // the following copy loop was copying the origin's length
                // and then ending prematurely not copying everything it should.
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                    // The multiplication in the next line has the same exact purpose
                    // as the one above.
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } { mstore(mc, mload(cc)) }

                mstore(tempBytes, _length)

                //update free-memory pointer
                //allocating the array padded to 32 bytes like the compiler does now
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            //if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)

                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
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

    function testDestroyTokensNotEnoughSupply() public {
        vm.pauseGasMetering();
        // ensure `accounts[0]` has tokens
        _generateTokens(accounts[0], 10);

        vm.prank(deployer);
        vm.resumeGasMetering();
        vm.expectRevert(NotEnoughSupply.selector);
        minimeToken.destroyTokens(accounts[0], 11);
        vm.pauseGasMetering();
        assertEq(minimeToken.totalSupply(), 10, "total supply should be correct");
        assertEq(minimeToken.balanceOf(accounts[0]), 10, "balance of account should be reduced");
        vm.resumeGasMetering();
    }

    function testDestroyTokensNotEnoughBalance() public {
        vm.pauseGasMetering();
        // ensure `accounts[0]` has tokens
        _generateTokens(accounts[0], 10);
        _generateTokens(accounts[1], 10);

        vm.expectRevert(NotEnoughBalance.selector);
        vm.prank(deployer);
        vm.resumeGasMetering();
        minimeToken.destroyTokens(accounts[0], 11);
        vm.pauseGasMetering();
        assertEq(minimeToken.totalSupply(), 20, "total supply should be correct");
        assertEq(minimeToken.balanceOf(accounts[0]), 10, "balance of account should be reduced");
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
        vm.prank(deployer);
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

        vm.startPrank(deployer);
        clone.generateTokens(accounts[0], 5);
        clone.generateTokens(accounts[1], 5);
        clone.generateTokens(accounts[2], 5);
        clone.generateTokens(accounts[3], 5);
        assertEq(clone.totalSupply(), 35, "total supply should be correct");

        uint256 thirdNextBlock = block.number + 3;
        vm.roll(thirdNextBlock);

        clone.generateTokens(accounts[0], 5);
        clone.generateTokens(accounts[1], 5);
        clone.generateTokens(accounts[2], 5);
        clone.generateTokens(accounts[3], 5);

        assertEq(clone.totalSupply(), 55, "total supply should be correct");
        assertEq(clone.totalSupplyAt(currentBlock - 1), 0, "total supply at current block-1 should be correct");
        assertEq(clone.totalSupplyAt(currentBlock), 7, "total supply at current block should be correct");
        assertEq(clone.totalSupplyAt(thirdNextBlock), 55, "total supply at thirdNextBlock should be correct");

        assertEq(
            clone.balanceOfAt(accounts[0], currentBlock - 1),
            0,
            "balance of account 0 at current block-1 should be correct"
        );
        assertEq(
            clone.balanceOfAt(accounts[1], currentBlock - 1),
            0,
            "balance of account 1 at current block-1 should be correct"
        );
        assertEq(
            clone.balanceOfAt(accounts[2], currentBlock - 1),
            0,
            "balance of account 2 at current block-1 should be correct"
        );
        assertEq(
            clone.balanceOfAt(accounts[3], currentBlock - 1),
            0,
            "balance of account 3 at current block-1 should be correct"
        );

        assertEq(
            clone.balanceOfAt(accounts[0], currentBlock), 7, "balance of account 0 at current block should be correct"
        );
        assertEq(
            clone.balanceOfAt(accounts[1], currentBlock), 0, "balance of account 1 at current block should be correct"
        );
        assertEq(
            clone.balanceOfAt(accounts[2], currentBlock), 0, "balance of account 2 at current block should be correct"
        );
        assertEq(
            clone.balanceOfAt(accounts[3], currentBlock), 0, "balance of account 3 at current block should be correct"
        );

        assertEq(
            clone.balanceOfAt(accounts[0], thirdNextBlock),
            17,
            "balance of account 0 at third next block should be correct"
        );
        assertEq(
            clone.balanceOfAt(accounts[1], thirdNextBlock),
            13,
            "balance of account 1 at third next block should be correct"
        );
        assertEq(
            clone.balanceOfAt(accounts[2], thirdNextBlock),
            15,
            "balance of account 2 at third next block should be correct"
        );
        assertEq(
            clone.balanceOfAt(accounts[3], thirdNextBlock),
            10,
            "balance of account 3 at third next block should be correct"
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

    function testCloneFutureSnapshot() public {
        vm.pauseGasMetering();
        _generateTokens(accounts[0], 10);

        vm.prank(accounts[3]);
        MiniMeToken clone = new MiniMeToken(
          minimeTokenFactory, 
          minimeToken, 
          block.number+1, 
          "TestFutureSnapshot", 
          18, 
          "TST", 
          true
        );
        vm.expectRevert(ParentSnapshotNotReached.selector);
        vm.prank(accounts[0]);
        vm.resumeGasMetering();
        clone.transfer(accounts[1], 2);
        vm.pauseGasMetering();
        assertEq(clone.balanceOf(accounts[0]), 10, "balance of account 0 should not change");
        assertEq(clone.balanceOf(accounts[1]), 0, "balance of account 1 should not change");
        vm.roll(block.number + 2);
        vm.prank(accounts[0]);
        vm.resumeGasMetering();
        clone.transfer(accounts[1], 2);
        vm.pauseGasMetering();
        assertEq(clone.balanceOf(accounts[0]), 8, "balance of account 0 should be correct");
        assertEq(clone.balanceOf(accounts[1]), 2, "balance of account 1 should be correct");

        vm.resumeGasMetering();
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
        minimeToken.claimTokens(IERC20(address(0)));
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

contract TestSnapshotReads is MiniMeTokenTest {
    function setUp() public virtual override {
        MiniMeTokenTest.setUp();
    }

    function testSnapshotReads() public {
        assertEq(minimeToken.totalSupply(), 0, "initial total supply should be correct");
        assertEq(minimeToken.balanceOf(accounts[0]), 0, "initial balance of account 0 should be correct");
        assertEq(minimeToken.balanceOf(accounts[1]), 0, "initial balance of account 1 should be correct");
        assertEq(minimeToken.balanceOf(accounts[2]), 0, "initial balance of account 2 should be correct");
        assertEq(minimeToken.balanceOf(accounts[3]), 0, "initial balance of account 3 should be correct");

        _generateTokens(accounts[0], 10);
        _generateTokens(accounts[1], 5);
        _generateTokens(accounts[2], 3);
        _generateTokens(accounts[3], 1);

        uint256 currentBlock = block.number;
        uint256 nextBlock = currentBlock + 1;
        uint256 secondNextBlock = currentBlock + 2;
        uint256 thirdNextBlock = currentBlock + 3;

        vm.roll(nextBlock);
        _generateTokens(accounts[0], 2);
        _generateTokens(accounts[1], 1);
        _generateTokens(accounts[2], 1);
        _generateTokens(accounts[3], 1);

        vm.roll(secondNextBlock);
        _generateTokens(accounts[0], 1);
        _generateTokens(accounts[1], 1);
        _generateTokens(accounts[2], 1);

        vm.roll(thirdNextBlock);
        _generateTokens(accounts[0], 1);
        _generateTokens(accounts[1], 1);

        assertEq(minimeToken.totalSupply(), 29, "total supply should be correct");
        assertEq(minimeToken.balanceOf(accounts[0]), 14, "balance of account 0 should be correct");
        assertEq(minimeToken.balanceOf(accounts[1]), 8, "balance of account 1 should be correct");
        assertEq(minimeToken.balanceOf(accounts[2]), 5, "balance of account 2 should be correct");
        assertEq(minimeToken.balanceOf(accounts[3]), 2, "balance of account 3 should be correct");

        assertEq(minimeToken.totalSupplyAt(currentBlock), 19, "total supply at current block should be correct");
        assertEq(minimeToken.totalSupplyAt(nextBlock), 24, "total supply at next block should be correct");
        assertEq(minimeToken.totalSupplyAt(secondNextBlock), 27, "total supply at second next block should be correct");
        assertEq(minimeToken.totalSupplyAt(thirdNextBlock), 29, "total supply at third next block should be correct");

        assertEq(
            minimeToken.balanceOfAt(accounts[0], currentBlock),
            10,
            "balance of account 0 at current block should be correct"
        );
        assertEq(
            minimeToken.balanceOfAt(accounts[1], currentBlock),
            5,
            "balance of account 1 at current block should be correct"
        );
        assertEq(
            minimeToken.balanceOfAt(accounts[2], currentBlock),
            3,
            "balance of account 2 at current block should be correct"
        );
        assertEq(
            minimeToken.balanceOfAt(accounts[3], currentBlock),
            1,
            "balance of account 3 at current block should be correct"
        );

        assertEq(
            minimeToken.balanceOfAt(accounts[0], nextBlock), 12, "balance of account 0 at next block should be correct"
        );
        assertEq(
            minimeToken.balanceOfAt(accounts[1], nextBlock), 6, "balance of account 1 at next block should be correct"
        );
        assertEq(
            minimeToken.balanceOfAt(accounts[2], nextBlock), 4, "balance of account 2 at next block should be correct"
        );
        assertEq(
            minimeToken.balanceOfAt(accounts[3], nextBlock), 2, "balance of account 3 at next block should be correct"
        );

        assertEq(
            minimeToken.balanceOfAt(accounts[0], secondNextBlock),
            13,
            "balance of account 0 at second next block should be correct"
        );
        assertEq(
            minimeToken.balanceOfAt(accounts[1], secondNextBlock),
            7,
            "balance of account 1 at second next block should be correct"
        );
        assertEq(
            minimeToken.balanceOfAt(accounts[2], secondNextBlock),
            5,
            "balance of account 2 at second next block should be correct"
        );
        assertEq(
            minimeToken.balanceOfAt(accounts[3], secondNextBlock),
            2,
            "balance of account 3 at second next block should be correct"
        );

        assertEq(
            minimeToken.balanceOfAt(accounts[0], thirdNextBlock),
            14,
            "balance of account 0 at third next block should be correct"
        );
        assertEq(
            minimeToken.balanceOfAt(accounts[1], thirdNextBlock),
            8,
            "balance of account 1 at third next block should be correct"
        );
        assertEq(
            minimeToken.balanceOfAt(accounts[2], thirdNextBlock),
            5,
            "balance of account 2 at third next block should be correct"
        );
        assertEq(
            minimeToken.balanceOfAt(accounts[3], thirdNextBlock),
            2,
            "balance of account 3 at third next block should be correct"
        );

        assertEq(
            minimeToken.balanceOfAt(accounts[0], currentBlock - 1),
            0,
            "balance of account 0 at previous block should be correct"
        );
        assertEq(
            minimeToken.balanceOfAt(accounts[1], currentBlock - 1),
            0,
            "balance of account 1 at previous block should be correct"
        );
        assertEq(
            minimeToken.balanceOfAt(accounts[2], currentBlock - 1),
            0,
            "balance of account 2 at previous block should be correct"
        );
        assertEq(
            minimeToken.balanceOfAt(accounts[3], currentBlock - 1),
            0,
            "balance of account 3 at previous block should be correct"
        );

        assertEq(
            minimeToken.balanceOfAt(accounts[0], thirdNextBlock + 1),
            14,
            "balance of account 0 at next block should be correct"
        );
        assertEq(
            minimeToken.balanceOfAt(accounts[1], thirdNextBlock + 1),
            8,
            "balance of account 1 at next block should be correct"
        );
        assertEq(
            minimeToken.balanceOfAt(accounts[2], thirdNextBlock + 1),
            5,
            "balance of account 2 at next block should be correct"
        );
        assertEq(
            minimeToken.balanceOfAt(accounts[3], thirdNextBlock + 1),
            2,
            "balance of account 3 at next block should be correct"
        );
    }
}

import {
    ERC2612InvalidSigner,
    ERC2612ExpiredSignature,
    ECDSA,
    NotEnoughBalance,
    NotEnoughAllowance
} from "../contracts/MiniMeBase.sol";

contract TestPermit is MiniMeTokenTest {
    SigUtils internal sigUtils;
    uint256 internal ownerPrivateKey = 0xA11CE;
    uint256 internal spenderPrivateKey = 0xB0B;
    address internal owner = vm.addr(ownerPrivateKey);
    address internal spender = vm.addr(spenderPrivateKey);

    function setUp() public virtual override {
        MiniMeTokenTest.setUp();

        sigUtils = new SigUtils(minimeToken.DOMAIN_SEPARATOR());
    }

    function testPermit() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: 0,
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        minimeToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        assertEq(minimeToken.allowance(owner, spender), 1e18);
        assertEq(minimeToken.nonces(owner), 1);
    }

    function testRevertExpiredPermit() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: minimeToken.nonces(owner),
            deadline: block.timestamp - 1 seconds
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        vm.expectRevert(abi.encodeWithSelector(ERC2612ExpiredSignature.selector, permit.deadline));
        minimeToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function testRevertInvalidSigner() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: minimeToken.nonces(owner),
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(spenderPrivateKey, digest); // spender signs owner's approval

        vm.expectRevert(
            abi.encodeWithSelector(ERC2612InvalidSigner.selector, ECDSA.recover(digest, v, r, s), permit.owner)
        );
        minimeToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function testRevertInvalidNonce() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: 1, // owner nonce stored on-chain is 0
            deadline: block.timestamp + 1 days
        });
        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        SigUtils.Permit memory permitNeeded = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: 0, // owner nonce stored on-chain is 0
            deadline: block.timestamp + 1 days
        });
        bytes32 digestNeeded = sigUtils.getTypedDataHash(permitNeeded);

        vm.expectRevert(
            abi.encodeWithSelector(ERC2612InvalidSigner.selector, ECDSA.recover(digestNeeded, v, r, s), permit.owner)
        );
        minimeToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function testRevertSignatureReplay() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: minimeToken.nonces(owner),
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        minimeToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        SigUtils.Permit memory permitNeeded = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: minimeToken.nonces(owner),
            deadline: block.timestamp + 1 days
        });

        bytes32 digestNeeded = sigUtils.getTypedDataHash(permitNeeded);
        vm.expectRevert(
            abi.encodeWithSelector(ERC2612InvalidSigner.selector, ECDSA.recover(digestNeeded, v, r, s), permit.owner)
        );
        minimeToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function testTransferFromLimitedPermit() public {
        _generateTokens(owner, 1e18);
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: 0,
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        minimeToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(spender);
        minimeToken.transferFrom(owner, spender, 1e18);

        assertEq(minimeToken.balanceOf(owner), 0);
        assertEq(minimeToken.balanceOf(spender), 1e18);
        assertEq(minimeToken.allowance(owner, spender), 0);
    }

    function testTransferFromMaxPermit() public {
        _generateTokens(owner, 1e18);
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: type(uint256).max,
            nonce: 0,
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        minimeToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(spender);
        minimeToken.transferFrom(owner, spender, 1e18);

        assertEq(minimeToken.balanceOf(owner), 0);
        assertEq(minimeToken.balanceOf(spender), 1e18);
        assertEq(minimeToken.allowance(owner, spender), type(uint256).max - 1e18);
    }

    function testInvalidAllowance() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 5e17, // approve only 0.5 tokens
            nonce: 0,
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        minimeToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(spender);
        vm.expectRevert(NotEnoughAllowance.selector);
        minimeToken.transferFrom(owner, spender, 1e18); // attempt to transfer 1 token
    }

    function testInvalidBalance() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 2e18, // approve 2 tokens
            nonce: 0,
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        minimeToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
        vm.prank(spender);
        vm.expectRevert(NotEnoughBalance.selector);
        minimeToken.transferFrom(owner, spender, 2e18); // attempt to transfer 2 tokens (owner only owns 1)
    }
}

contract SigUtils {
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    // computes the hash of a permit
    function getStructHash(Permit memory _permit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(PERMIT_TYPEHASH, _permit.owner, _permit.spender, _permit.value, _permit.nonce, _permit.deadline)
        );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(Permit memory _permit) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(_permit)));
    }
}
