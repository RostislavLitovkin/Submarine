// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title Treasury - Native DOT custody vault for PolkaVM
/// @notice Collects native DOT deposits and restricts withdrawals to the
///         contract owner (the deployer)
contract Treasury {
    /// @notice Owner address that can move the DOT held by this contract
    address public immutable owner;

    /// @dev Emitted whenever DOT is deposited into the treasury
    event Deposited(address indexed from, uint256 amount);

    /// @dev Emitted whenever the owner sends DOT out of the treasury
    event Withdrawn(address indexed to, uint256 amount);

    error NotOwner();
    error InvalidRecipient();
    error InsufficientBalance();

    constructor() {
        owner = msg.sender;
    }

    /// @notice Accept plain DOT transfers without calldata
    receive() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    /// @notice Accept DOT deposits via explicit function call
    function deposit() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    /// @notice Sends DOT from the treasury balance to the chosen recipient
    /// @param recipient Address receiving the DOT
    /// @param amount Amount of DOT (in wei) to transfer
    function withdraw(address payable recipient, uint256 amount) external onlyOwner {
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount > address(this).balance) revert InsufficientBalance();

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "DOT transfer failed");

        emit Withdrawn(recipient, amount);
    }

    /// @notice Convenience helper returning the DOT held by this contract
    function treasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }
}
