// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Vm.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /* Events */
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;
    // vrf
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,

        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    //////////////////////////////////////
    // enterRaffle                    ////
    /////////////////////////////////////

    function testRaffleRevertIfNotEnoughEthSent() public {
        //Arrange
        vm.prank(PLAYER);
        //Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector); // It is expecting the next line should revert
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        assertEq(raffle.getPlayer(0), PLAYER);
    }

    function testEventsOnEntrance() public {
        vm.prank(PLAYER);
        //////////////////////
        // function expectEmit(
        //     bool checkTopic1,
        //     bool checkTopic2,
        //     bool checkTopic3,
        //     bool checkData
        // ) external;
        vm.expectEmit(true, false, false, true, address(raffle));
        // Here we are checking only one indexed parameter
        // so 1st is true, next 2 are false
        // there is no checkdata here, it is also false
        // finally we pass the address of the emitter
        //////////////////////
        // we have to manually emit the event
        emit EnteredRaffle(PLAYER);
        //////////////////////
        // Finally, the actual function call
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        // first we need to change raffle state from OPEN to CALCULATING
        // to do that we have to call performupkeep and checkupkeep functions
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // vm.warp Sets block.timestamp.
        vm.warp(block.timestamp + interval + 1);
        // we are simulating in such a way that enough time has passed for checkupkeep to be called
        vm.roll(block.number + 1); // manually adding extra blocks
        ///////////////////
        raffle.performUpkeep("");
        // since performUpkeep is called, RaffleState will be changed to Calculating
        // Now if a new player try to enter the raffle, will not be allowed.
        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    //////////////////////////////////////
    // checkUpkeep                   ////
    /////////////////////////////////////

    function testCheckUpkeepReturnsFalseIfIthasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleIsNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
        // by calling performupkeep,
        // rafflestate is changed to calculating
        // now if we directly call checkupkeep
        // raffle state will not be in open state, so it will return false

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpKeepReturnsFalseIfNotEnoughTimeHasntPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsTrueWhenParametersAreGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    //////////////////////////////////////
    // performUpkeep                 ////
    /////////////////////////////////////

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTrue()
        public
        raffleEnteredAndTimePassed
    {
        // Act / Assert
        raffle.performUpkeep("");
        // if the above line dosen't revert
        // then this test is considered as pass
    }

    function testPerformUpKeepRevertsIfCheckUpKeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0; // 0 --> OPEN

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        // for custom errors, this is the way
        raffle.performUpkeep("");
    }

    function testPerformUpKeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        // Act
        vm.recordLogs();
        // record logs will record all the logs automatically
        raffle.performUpkeep(""); // this will emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // getRecordedLogs will give all the logs that got recently emitted
        bytes32 requestId = entries[1].topics[1];
        // all logs are recorded as bytes32
        // entries[0] will be the event emitted from vrfCoordinatorMock
        // topics[0] will be event itself
        // we need requestId, so topics[1]

        Raffle.RaffleState rState = raffle.getRaffleState();

        // Assert
        assert(uint256(requestId) > 0);
        // this way we can make sure that requestId was actually generated

        assert(uint256(rState) == 1);
        // 0 -> OPEN
        // 1 -> CALCULATING
    }

    //////////////////////////////////////
    // fulfillRandomWords             ////
    /////////////////////////////////////

    modifier skipFork() {
        if (block.chainid != 31337) return;
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpKeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipFork {
        // Act
        // we are making mocks to call the fulfillRandomWords fn
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
        // randomRequestId will be created by foundry
        // it will call this fulfillRandomWords many times with many random numbers
        // this method is called Fuzz Testing
        // this test is failing because, request Id is not created by chainlinkVRF
        // we are randomly creating it
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        // Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1; //raffleEnteredAndTimePassed will be index 0
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i)); // address(1) --> address(5)
            hoax(player, STARTING_PLAYER_BALANCE);
            // hoax is combination of
            // vm.prank(player);
            // vm.deal(player, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        // check testPerformUpKeepUpdatesRaffleStateAndEmitsRequestId for more details on log
        // chainlink node will return requestId

        uint256 previousTimeStamp = raffle.getLastWinnerPickedTimeStamp();

        // pretend to be chainlink vrf to get random number & pick winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );
        // here instead of passing a random requestId
        // we are passing the requestId created by chainlinkVRF

        // Assert

        // once the fulfillRandomWords is called by chainlinkVRF

        // RaffleState should be reset to OPEN
        assert(uint256(raffle.getRaffleState()) == 0);

        assert(raffle.getRecentWinner() != address(0));
        // address(0) will be the initalized address
        // if a new winner is picker, it should be updated correctly

        assert(raffle.getLengthOfPlayers() == 0);
        // players arrays should be reset to 0

        assert(raffle.getLastWinnerPickedTimeStamp() > previousTimeStamp);
        // current timestamp should be greater than previoustimestamp

        console.log(raffle.getRecentWinner().balance);
        console.log(STARTING_PLAYER_BALANCE + prize);
        assert(
            raffle.getRecentWinner().balance ==
                STARTING_PLAYER_BALANCE + prize - entranceFee
        );
    }
}
