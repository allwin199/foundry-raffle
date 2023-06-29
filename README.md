# Foundry Raffle Contract

## About

This code is to create a proveably random smart contract lottery.

## Layout

### Layout of Contract:

-   version
-   imports
-   errors
-   interfaces, libraries, contracts
-   Type declarations
-   State variables
-   Events
-   Modifiers
-   Functions

### Layout of Functions:

-   constructor
-   receive function (if exists)
-   fallback function (if exists)
-   external
-   public
-   internal
-   private
-   view & pure functions

## What we want it to do?

1. Users can enter by paying for a ticket.
    1. The ticket fees are going to go to the winner during the draw.
2. After X period of time, the lottery will automatically draw a winner.
    1. This will be done programatically.
3. This will be implemented using Chainlink VRF & Chainlink Automation
    1. Chainlink VRF -> Randomness
    2. Chainlink Automation - > Time based trigger

## Test!

1. Write some deploy scripts
2. Write our tests
    1. Work on a local chain
    2. Work on a Forked Testnet
    3. Work on a Forked Mainnet
