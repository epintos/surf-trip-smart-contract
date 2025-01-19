// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import { Script } from "lib/forge-std/src/Script.sol";
import { SurfTrip } from "src/SurfTrip.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";

contract DeploySurfTrip is Script {
    function run() public {
        deployContract(msg.sender);
    }

    function deployContract(address deployer) public returns (SurfTrip, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vm.startBroadcast(deployer);
        SurfTrip surfTrip = new SurfTrip(config.tripFee);
        surfTrip.transferOwnership(deployer);
        vm.stopBroadcast();

        return (surfTrip, helperConfig);
    }
}
