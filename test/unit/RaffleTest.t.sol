// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

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
            callbackGasLimit
        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    //////////////////////////////////////
    // enterRaffle
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
}
