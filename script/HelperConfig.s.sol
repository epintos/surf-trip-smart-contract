// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import { Script } from "lib/forge-std/src/Script.sol";
import { MockV3Aggregator } from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import { ERC20Mock } from
    "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/mocks/ERC20Mock.sol";

abstract contract CodeConstants {
    uint256 public constant SEPOLIA_CHAIN_ID = 11_155_111;
    uint256 public constant LOCAL_CHAIN_ID = 31_337;
    int256 public constant ETH_USD_PRICE = 4000e8;
    uint256 public constant wUSDC_INITIAL_BALANCE = 1000e8;
    uint8 public constant DECIMALS = 8;
    uint256 public constant TRIP_FEE = 0.01 ether;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 tripFee;
        address wETHUSDPriceFeed;
        address wUSDC;
    }

    NetworkConfig public activeNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaETHConfig();
        } else if (block.chainid == LOCAL_CHAIN_ID) {
            activeNetworkConfig = getOrCreateAnvilETHConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepoliaETHConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            tripFee: TRIP_FEE,
            wETHUSDPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wUSDC: 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8
        });
    }

    function getOrCreateAnvilETHConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.wETHUSDPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUSDPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ERC20Mock wUSDCMock = new ERC20Mock("Wrapped USDC", "wUSDC", msg.sender, wUSDC_INITIAL_BALANCE);
        vm.stopBroadcast();
        return
            NetworkConfig({ tripFee: TRIP_FEE, wETHUSDPriceFeed: address(ethUSDPriceFeed), wUSDC: address(wUSDCMock) });
    }
}
