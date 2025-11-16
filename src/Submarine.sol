// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title Submarine
/// @notice Abstract contract that enforces a recurring 1 DOT fee to a collector
///         every `feeIntervalInBlocks` blocks once the inheriting contract holds
///         at least 1 DOT. Intended to be inherited by treasury-like vaults.
abstract contract Submarine {
    /// @notice 1 DOT on PolkaVM chains
    uint256 public constant FEE_AMOUNT = 1 ether;

    /// @notice Address receiving the recurring DOT fee
    address public immutable feeCollector;

    /// @notice Number of blocks that must elapse between fee payments
    uint64 public immutable feeIntervalInBlocks;

    /// @notice Block number when the last fee payment executed (or activation block)
    uint256 public lastPaymentBlock = 0;

    event SubmarineActivated(uint256 indexed blockNumber);
    event SubmarineFeePaid(
        address indexed collector,
        uint256 amount,
        uint256 indexed blockNumber
    );

    error InvalidCollector();
    error InvalidInterval();
    error FeeTransferFailed();

    constructor(address feeCollector_, uint64 feeIntervalInBlocks_) {
        if (feeCollector_ == address(0)) revert InvalidCollector();
        if (feeIntervalInBlocks_ == 0) revert InvalidInterval();
        feeCollector = feeCollector_;
        feeIntervalInBlocks = feeIntervalInBlocks_;
    }

    /// @notice Public hook anyone can call to attempt paying the fee when due
    /// @return paid True when a payment was executed during this call
    function runSubmarine() public returns (bool paid) {
        return _maybePayFee();
    }

    /// @notice Internal helper for inheriting contracts to trigger fee logic
    /// @return paid True when a payment was executed
    function _submarineHook() internal returns (bool paid) {
        return _maybePayFee();
    }

    /// @notice Returns the block number when the next payment becomes due
    /// @dev Returns 0 when payments have not yet been activated (no DOT balance)
    function nextPaymentBlock() public view returns (uint256) {
        return lastPaymentBlock + feeIntervalInBlocks;
    }

    function _maybePayFee() internal returns (bool paid) {
        uint256 balance = address(this).balance;

        if (block.number < lastPaymentBlock + feeIntervalInBlocks) {
            return false;
        }

        if (balance < FEE_AMOUNT) {
            return false;
        }

        lastPaymentBlock = block.number;
        (bool success, ) = feeCollector.call{value: FEE_AMOUNT}("");
        if (!success) revert FeeTransferFailed();

        emit SubmarineFeePaid(feeCollector, FEE_AMOUNT, block.number);
        return true;
    }
}
