// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import { Test, console2 } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { SurfTrip } from "src/SurfTrip.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { DeploySurfTrip } from "script/DeploySurfTrip.s.sol";
import { Handler } from "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
    SurfTrip surfTrip;
    HelperConfig helperConfig;
    DeploySurfTrip deploySurfTrip;
    Handler handler;

    function setUp() public {
        deploySurfTrip = new DeploySurfTrip();
        (surfTrip, helperConfig) = deploySurfTrip.deployContract(msg.sender);
        handler = new Handler(surfTrip, helperConfig, this, deploySurfTrip);
        targetContract(address(handler));
    }

    function invariant_openToWithdrawBeforeDeadine() public view {
        assert(surfTrip.getBalance() >= 0);
    }

    function invariant_gettersShouldNotRevert() public view {
        surfTrip.getDeadline();
        surfTrip.getOrganizer();
        surfTrip.getTripFee();
        surfTrip.getBalance();
    }
}
