// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A sample Raffle Contract
 * @author Prince Allwin
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */

contract Raffle is VRFConsumerBaseV2 {
    /** Custom Errors */
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle_RaffleNotOpen();

    /** Enum */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /** State Variables */
    //constant and immutable variables
    uint256 private immutable i_entranceFee;
    // @dev Duration of the lottery in seconds
    uint256 private immutable i_interval;
    // variables related to chainlink VRF
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;

    // storage variables
    uint256 private s_lastWinnerPickedTimeStamp;
    // since we have to pay one of the players, we have to make this as payable.
    address payable[] private s_players;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /** Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);

    /** Functions */
    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        address _vrfCoordinator,
        bytes32 _gasLane,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        s_raffleState = RaffleState.OPEN;
        s_lastWinnerPickedTimeStamp = block.timestamp;
        // VRF
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        i_gasLane = _gasLane;
        i_subscriptionId = _subscriptionId;
        i_callbackGasLimit = _callbackGasLimit;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) revert Raffle__NotEnoughEthSent();
        if (s_raffleState != RaffleState.OPEN) revert Raffle_RaffleNotOpen();
        s_players.push(payable(msg.sender));
        // msg.sender is not automatically considered payable
        // Therfore explicitly convert msg.sender to payable before pushing it into an array of address payable type.
        emit EnteredRaffle(msg.sender);
    }

    function pickWinner() public {
        // 1. Get a random number
        // 2. Use the random number to pick a winner
        // 3. The above 2 functions should be automatically called after X amount of time.
        //////////////////////////
        // check to see if enough time has passed.
        // block.timestamp will give the current time.
        // if lastTimeStamp + i_interval = 5 and block.timestamp = 4, then pickwinner will get executed.
        if (block.timestamp > (s_lastWinnerPickedTimeStamp + i_interval)) {
            s_raffleState = RaffleState.CALCULATING;
            uint256 requestId = i_vrfCoordinator.requestRandomWords(
                i_gasLane, // gas lane -> How much are we willing to spend
                i_subscriptionId,
                REQUEST_CONFIRMATIONS,
                i_callbackGasLimit,
                NUM_WORDS
            );
        }
        // Getting a random number from chainlink is 2 transaction function
        // 1. Request the RNG(Random Number Generation)
        // 2. Get the random number
    }

    // The above fn will be called by VRF automation
    // once pickwinner() is called
    // i_vrfCoordinator.requestRandomWords will be called with expected args
    // once requestRandomWords is called, fulfillRandomWords inside the VRFConsumerBaseV2 will be called by VrfCoordinator.
    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        uint256 indexOfWinner = _randomWords[0] % s_players.length;
        // if random no is 12454 and players.length is 15
        // then 12454 % 15 = 4, 4th index will be the winner
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        // Reset the lastWinnerPickedTimeStamp
        s_lastWinnerPickedTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        // The size of the new array is set to 0, indicating that it has no initial elements.
        emit PickedWinner(winner);
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) revert Raffle__TransferFailed();
    }

    /** Getter Functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
