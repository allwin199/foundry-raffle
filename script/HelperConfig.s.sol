// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaEthConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, // 30seconds
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 3294,
            callbackGasLimit: 500000, //500,000 gas
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
        });
        return sepoliaEthConfig;
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // In Solidity, the default value for a struct member of type address is address(0),
        // which represents the Ethereum zero address or an uninitialized address.
        // Therefore, the default value of vrfCoordinator in the NetworkConfig struct will be address(0).
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }
        // If the address is detected as address(0)
        // then it will go ahead and run the below code
        // if not it will return already deployed mock.

        // Deploying mocks to work on local chain
        // If the address is address(0), this will execute
        uint96 baseFee = 0.25 ether; // 0.25 LINK
        uint96 gasPriceLink = 1e9; //1 GWEI LINK
        vm.startBroadcast();
        VRFCoordinatorV2Mock vRFCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        NetworkConfig memory anvilEthConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, //30s
            vrfCoordinator: address(vRFCoordinatorV2Mock),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, // dummy_one
            subscriptionId: 0, // our script will add this!
            callbackGasLimit: 500000,
            link: address(link),
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
        return anvilEthConfig;
    }
}
