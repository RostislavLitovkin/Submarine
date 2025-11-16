// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../src/Treasury.sol";

contract TreasuryTest is Test {
    Treasury internal treasury;
    address internal ownerAddr;
    address internal depositor = address(0xBEEF);
    address internal feeCollector = address(0xFEE);

    uint64 internal constant FEE_INTERVAL = 5;

    function setUp() public {
        ownerAddr = address(this);
        treasury = new Treasury(feeCollector, FEE_INTERVAL);
        vm.deal(depositor, 100 ether);
        vm.deal(ownerAddr, 10 ether);
        vm.deal(feeCollector, 0);
    }

    receive() external payable {}

    function testOwnerIsDeployer() public view {
        assertEq(treasury.owner(), ownerAddr);
    }

    function testDepositIncreasesBalance() public {
        uint256 amount = 3 ether;
        _seedTreasury(amount);
        assertEq(treasury.treasuryBalance(), amount);
    }

    function testReceiveFunctionAcceptsDot() public {
        uint256 amount = 1 ether;
        vm.prank(depositor);
        (bool ok,) = address(treasury).call{value: amount}("");
        assertTrue(ok);
        assertEq(address(treasury).balance, amount);
    }

    function testOnlyOwnerCanWithdraw() public {
        _seedTreasury(2 ether);

        address attacker = address(0xCAFE);
        vm.prank(attacker);
        vm.expectRevert(Treasury.NotOwner.selector);
        treasury.withdraw(payable(attacker), 1 ether);
    }

    function testOwnerWithdrawsSuccessfully() public {
        _seedTreasury(2 ether);

        uint256 ownerBalanceBefore = ownerAddr.balance;
        treasury.withdraw(payable(ownerAddr), 1 ether);

        assertEq(ownerAddr.balance, ownerBalanceBefore + 1 ether);
        assertEq(address(treasury).balance, 1 ether);
    }

    function testWithdrawRevertsWhenBalanceTooLow() public {
        _seedTreasury(1 ether);
        vm.expectRevert(Treasury.InsufficientBalance.selector);
        treasury.withdraw(payable(ownerAddr), 2 ether);
    }

    function testWithdrawRevertsWhenRecipientZero() public {
        _seedTreasury(1 ether);
        vm.expectRevert(Treasury.InvalidRecipient.selector);
        treasury.withdraw(payable(address(0)), 0.5 ether);
    }

    function testSubmarineKeepsLastPaymentZeroWhenBelowFee() public {
        _seedTreasury(0.5 ether);
        assertEq(treasury.lastPaymentBlock(), 0);
        assertEq(treasury.nextPaymentBlock(), FEE_INTERVAL);

        _advanceBlocks(FEE_INTERVAL);
        bool paid = treasury.runSubmarine();

        assertFalse(paid);
        assertEq(treasury.lastPaymentBlock(), 0);
        assertEq(feeCollector.balance, 0);
    }

    function testSubmarineRequiresIntervalBeforeFirstPayment() public {
        _seedTreasury(1 ether);

        assertEq(treasury.lastPaymentBlock(), 0);
        assertEq(treasury.nextPaymentBlock(), FEE_INTERVAL);

        bool paidImmediately = treasury.runSubmarine();
        assertFalse(paidImmediately);
        assertEq(treasury.lastPaymentBlock(), 0);
        assertEq(feeCollector.balance, 0);

        _advanceBlocks(FEE_INTERVAL);
        uint256 collectorBefore = feeCollector.balance;
        vm.prank(depositor);
        bool paidAfterInterval = treasury.runSubmarine();

        assertTrue(paidAfterInterval);
        assertEq(feeCollector.balance, collectorBefore + 1 ether);
        assertEq(treasury.lastPaymentBlock(), block.number);
        assertEq(treasury.nextPaymentBlock(), block.number + FEE_INTERVAL);
    }

    function testSubmarinePaysAfterInterval() public {
        _seedTreasury(3 ether);

        _advanceBlocks(FEE_INTERVAL);
        uint256 collectorBefore = feeCollector.balance;
        treasury.tickSubmarine();

        assertEq(feeCollector.balance, collectorBefore + 1 ether);
        assertEq(treasury.treasuryBalance(), 2 ether);
        assertEq(treasury.lastPaymentBlock(), block.number);
    }

    function testRunSubmarineExternalCaller() public {
        _seedTreasury(2 ether);
        _advanceBlocks(FEE_INTERVAL);

        vm.prank(depositor);
        bool paid = treasury.runSubmarine();

        assertTrue(paid);
        assertEq(feeCollector.balance, 1 ether);
    }

    function testSubmarineSkipsWhenInsufficientBalance() public {
        _seedTreasury(1 ether);
        treasury.withdraw(payable(ownerAddr), 1 ether);

        _advanceBlocks(FEE_INTERVAL);
        bool paid = treasury.runSubmarine();

        assertFalse(paid);
        assertEq(feeCollector.balance, 0);
    }

    function _seedTreasury(uint256 amount) internal {
        vm.prank(depositor);
        treasury.deposit{value: amount}();
    }

    function _advanceBlocks(uint256 blockAmount) internal {
        vm.roll(block.number + blockAmount);
    }
}
