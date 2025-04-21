// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract CodeConstants {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    address constant SEPOLIA_VRF_COORDINATOR =
        address(0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B);
    bytes32 constant SEPOLIA_KEY_HASH =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant ETH_SEPOLIA_ENTRY_FEE = 0.01 ether;

    /* VRF Mock Values*/
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__NoConfigForChainId(uint256 chainId);

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilETHConfig();
        }
        NetworkConfig memory cfg = networkConfigs[chainId];
        if (cfg.vrfCoordinator != address(0)) {
            return cfg;
        }
        revert HelperConfig__NoConfigForChainId(chainId);
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: ETH_SEPOLIA_ENTRY_FEE, // 1e16
                interval: 30, // 30 seconds
                vrfCoordinator: SEPOLIA_VRF_COORDINATOR,
                gasLane: SEPOLIA_KEY_HASH,
                callbackGasLimit: 500000, // 500,000 gas
                subscriptionId: 0,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
    }

    function getOrCreateAnvilETHConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UINT_LINK
        );
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: ETH_SEPOLIA_ENTRY_FEE,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: SEPOLIA_KEY_HASH, // doesn't matter
            callbackGasLimit: 500000, // doesn't matter
            subscriptionId: 0,
            link: address(0)
        });
        return localNetworkConfig;
    }
}
