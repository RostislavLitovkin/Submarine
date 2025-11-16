// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../src/Treasury.sol";

contract TreasuryTest is Test {
    Treasury internal treasury;
    address internal ownerAddr;
    address internal depositor = address(0xBEEF);

    function setUp() public {
        treasury = new Treasury();
        ownerAddr = address(this);
    }

    receive() external payable {}

    function testOwnerIsDeployer() public {
        assertEq(treasury.owner(), ownerAddr);
    }

    function testDepositIncreasesBalance() public {
        uint256 amount = 3 ether;
        _seedTreasury(amount);
        assertEq(treasury.treasuryBalance(), amount);
    }

    function testReceiveFunctionAcceptsDot() public {
        uint256 amount = 1 ether;
        vm.deal(depositor, amount);
        vm.prank(depositor);
        (bool ok,) = address(treasury).call{value: amount}("");
        assertTrue(ok);
        assertEq(address(treasury).balance, amount);
    }

    function testOnlyOwnerCanWithdraw() public {
        uint256 amount = 2 ether;
        _seedTreasury(amount);

        address attacker = address(0xCAFE);
        vm.prank(attacker);
        vm.expectRevert(Treasury.NotOwner.selector);
        treasury.withdraw(payable(attacker), 1 ether);
    }

    function testOwnerWithdrawsSuccessfully() public {
        uint256 amount = 2 ether;
        _seedTreasury(amount);

        uint256 ownerBalanceBefore = ownerAddr.balance;
        treasury.withdraw(payable(ownerAddr), 1 ether);

        assertEq(ownerAddr.balance, ownerBalanceBefore + 1 ether);
        assertEq(address(treasury).balance, amount - 1 ether);
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

    function _seedTreasury(uint256 amount) internal {
        vm.deal(depositor, amount);
        vm.prank(depositor);
        treasury.deposit{value: amount}();
    }
}
