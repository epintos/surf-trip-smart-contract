// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Script} from "lib/forge-std/src/Script.sol";
import {SurfTrip} from "src/SurfTrip.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeploySurfTrip is Script {
    function run() public {
        deployContract();
    }

    function deployContract() public returns (SurfTrip, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vm.startBroadcast();
        SurfTrip surfTrip = new SurfTrip(config.tripFee);
        vm.stopBroadcast();

        return (surfTrip, helperConfig);
    }
}
