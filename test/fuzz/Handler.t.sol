// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import { Test, console2 } from "forge-std/Test.sol";
import { SurfTrip } from "src/SurfTrip.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { InvariantsTest } from "./InvariantsTest.t.sol";
import { DeploySurfTrip } from "script/DeploySurfTrip.s.sol";

contract Handler is Test {
    SurfTrip surfTrip;
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;
    address[] surfersWithDeposits;
    HelperConfig helperConfig;
    InvariantsTest invariantsTest;
    DeploySurfTrip deploySurf;

    constructor(
        SurfTrip _surfTrip,
        HelperConfig _helperConfig,
        InvariantsTest _invariantsTest,
        DeploySurfTrip _deploySurf
    ) {
        surfTrip = _surfTrip;
        helperConfig = _helperConfig;
        invariantsTest = _invariantsTest;
        deploySurf = _deploySurf;
    }

    function deposit(uint256 amount) public payable {
        // Is there a better way to do this?
        vm.assume(msg.sender != address(helperConfig));
        vm.assume(msg.sender != address(invariantsTest));
        vm.assume(msg.sender != address(deploySurf));
        vm.assume(msg.sender != address(surfTrip));
        vm.assume(msg.sender != address(this));
        amount = bound(amount, surfTrip.getTripFee(), surfTrip.getTripFee() + MAX_DEPOSIT_SIZE);
        vm.deal(address(msg.sender), amount);
        vm.prank(msg.sender);
        surfTrip.deposit{ value: amount }();
        surfersWithDeposits.push(msg.sender);
        console2.log(msg.sender);
    }

    function refund(uint256 seed, uint256 amount) public {
        // Is there a better way to do this?
        vm.assume(msg.sender != address(helperConfig));
        vm.assume(msg.sender != address(invariantsTest));
        vm.assume(msg.sender != address(deploySurf));
        vm.assume(msg.sender != address(surfTrip));
        vm.assume(msg.sender != address(this));
        vm.assume(surfersWithDeposits.length > 0);
        address surfer = surfersWithDeposits[seed % surfersWithDeposits.length];
        vm.assume(surfTrip.getSurferBalance(surfer) >= surfTrip.getTripFee());
        amount = bound(amount, surfTrip.getTripFee(), surfTrip.getSurferBalance(surfer));
        vm.prank(surfer);
        surfTrip.refund(amount);
    }
}
