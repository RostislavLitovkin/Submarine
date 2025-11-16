# Submarine

Submarine is a smart contract that helps developers earn money through a subscription-based model. If the deployed smart contract owns tokens, each month a part is sent to the creator of the contract

## Installation

### Foundry (recommended)

```shell
forge install plutolabs/Submarine
```

This makes the contracts importable via:

```solidity
import {Submarine} from "Submarine/src/Submarine.sol";
import {Treasury} from "Submarine/src/Treasury.sol";
```

### NPM package

```shell
npm install @plutolabs/submarine
```

Then point your Solidity import path (via `remappings.txt` or your build tool) to `node_modules/@plutolabs/submarine`.

## Contract functionality

### `Submarine.sol` (fee engine)
- **Constructor args**
    - `feeCollector`: recipient of every 1 DOT payment (non-zero address enforced).
    - `feeIntervalInBlocks`: block spacing between payments (e.g. ~30-day cadence).
- **State**
    - `lastPaymentBlock`: starts at 0 and is updated every time a fee is paid.
    - `nextPaymentBlock()`: convenience getter returning `lastPaymentBlock + interval`.
- **Core flow**
    - `_submarineHook()` / `runSubmarine()` attempt a payout.
    - If the contract balance is below 1 DOT or the interval hasn’t elapsed, the hook exits quietly.
    - Once both conditions are satisfied, exactly 1 DOT is transferred to `feeCollector` and an event is emitted.
- **Safety guards**
    - Zero-address collectors and zero intervals are rejected at construction.
    - Transfers revert if the low-level call fails, preventing silent fund loss.

### `Treasury.sol` (DOT vault + fee engine)
- Owner-only vault that inherits `Submarine`.
- **Public entry points**
    - `deposit()` & `receive()`: accept DOT, log a `Deposited` event, and invoke the Submarine hook.
    - `withdraw(address,uint256)`: owner can send DOT to any address (non-zero) with balance checks; hook executes after the transfer.
    - `tickSubmarine()`: owner helper to manually run the fee hook without moving funds.
    - `runSubmarine()`: inherited public trigger so any keeper can enforce the schedule.
- **Views**
    - `treasuryBalance()` returns current holdings.
    - `lastPaymentBlock()`/`nextPaymentBlock()` inherited from `Submarine` reveal timing.

**Activation behavior**

The first time the Treasury balance reaches at least 1 DOT, the next run of `_submarineHook()` sets `lastPaymentBlock` and waits the configured interval. Every subsequent deposit/withdrawal automatically attempts a payout, so there is no need for external cron jobs unless you want guaranteed on-time payments via `runSubmarine()`.

## Quick usage

1. Deploy `Treasury` supplying the fee collector and the desired block interval.
2. Fund the contract with at least 1 DOT. The Submarine engine activates as soon as the balance crosses the threshold, but the first payout only occurs after the interval has elapsed.
3. Call `runSubmarine()` (or let regular deposits/withdrawals trigger `_submarineHook()`) every interval to release the 1 DOT fee, provided enough DOT is available.
4. Use `withdraw` to move any remaining DOT as the owner.

## Example: integrating Submarine in your own contract

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Submarine} from "./src/Submarine.sol";

contract CreatorVault is Submarine {
    address public owner;

    constructor(address feeCollector, uint64 feeInterval) Submarine(feeCollector, feeInterval) {
        owner = msg.sender;
    }

    receive() external payable {
        _submarineHook(); // attempt to pay the fee every time funds arrive
    }

    function withdraw(uint256 amount) external {
        require(msg.sender == owner, "not owner");
        payable(owner).transfer(amount);
        _submarineHook();
    }
}
```

Deployment & usage walkthrough:

1. Deploy `CreatorVault` (or the provided `Treasury`) with your DOT creator wallet as `feeCollector` and choose a block interval (e.g., 216_000 blocks ≈ 30 days).
2. Fund the contract with user deposits. As soon as it holds ≥ 1 DOT, the next `_submarineHook()` run schedules the fee window.
3. Either:
    - Let normal user interactions trigger `_submarineHook()` implicitly, or
    - Run `runSubmarine()` from any keeper/cron job right after each interval to guarantee payment timing.
4. Track payouts using the emitted `SubmarineFeePaid` events.

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://paritytech.github.io/foundry-book-polkadot/

## Commands

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy Treasury

```shell
forge create src/Treasury.sol:Treasury \
    --rpc-url <INSERT_RPC_URL> \
    --private-key <INSERT_PRIVATE_KEY> \
    --constructor-args <FEE_COLLECTOR_ADDRESS> <FEE_INTERVAL_BLOCKS> \
    --resolc
```

Use your preferred block interval (e.g. `216000` ≈ 30 days at 6s block time). After deployment, send at least 1 DOT to the Treasury to activate Submarine and optionally schedule external keepers to call `runSubmarine()` each interval.

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
