// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , , uint256 deployerKey) = helperConfig
            .activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerKey);
        // to create a subscription we need vrfCoordinator address
        // we are getting this from helperconfig
    }

    function createSubscription(
        address _vrfCoordinator,
        uint256 _deployerkey
    ) public returns (uint64) {
        console.log("Creating Subscription on ChainId: ", block.chainid);
        vm.startBroadcast(_deployerkey);
        uint64 subId = VRFCoordinatorV2Mock(_vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your sub Id is: ", subId);
        console.log("Please update subscriptionId in HelperConfig.s.sol");
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subscriptionId, link, deployerKey);
        // to fund a subscription, we need the subscriptionId, vrfCoordinator and link address
        // link token is the contract, that we are going to call on for funding subscription
    }

    function fundSubscription(
        address _vrfCoordinator,
        uint64 _subscriptionId,
        address _link,
        uint256 _deployerKey
    ) public {
        console.log("Funding Subscription", _subscriptionId);
        console.log("Using VRFCoordinator", _vrfCoordinator);
        console.log("On ChainId", block.chainid);
        // we are deploying a mock link token for local chain
        if (block.chainid == 31337) {
            vm.startBroadcast(_deployerKey);
            VRFCoordinatorV2Mock(_vrfCoordinator).fundSubscription(
                _subscriptionId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(_deployerKey);
            LinkToken(_link).transferAndCall(
                _vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(_subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address _raffle,
        address _vrfCoordinator,
        uint64 _subscriptionId,
        uint256 _deployerKey
    ) public {
        console.log("Adding consumer contract: ", _raffle);
        console.log("Using vrfCoordinator: ", _vrfCoordinator);
        console.log("On ChainId: ", block.chainid);
        // now private key will be responsible for adding for the consumer
        vm.startBroadcast(_deployerKey);
        VRFCoordinatorV2Mock(_vrfCoordinator).addConsumer(
            _subscriptionId,
            _raffle
        );
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address _raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(_raffle, vrfCoordinator, subscriptionId, deployerKey);
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffle);
    }
}
