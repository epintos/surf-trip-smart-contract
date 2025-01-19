// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import { Test, console2 } from "forge-std/Test.sol";
import { SurfTrip } from "src/SurfTrip.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { InvariantsTest } from "./InvariantsTest.t.sol";
import { DeploySurfTrip } from "script/DeploySurfTrip.s.sol";
import { ERC20Mock } from
    "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/mocks/ERC20Mock.sol";
import { MockV3Aggregator } from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract Handler is Test {
    SurfTrip surfTrip;
    uint256 MAX_DEPOSIT_SIZE = 60 ether;
    address[] surfersWithDeposits;
    uint256 MIN_DEPOSIT = 40 ether;
    HelperConfig helperConfig;
    InvariantsTest invariantsTest;
    DeploySurfTrip deploySurf;
    MockV3Aggregator ethUSDPriceFeed;
    ERC20Mock wUSDC;

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
        address[] memory supportedToken = surfTrip.getSupportedTokens();
        wUSDC = ERC20Mock(supportedToken[0]);
        ethUSDPriceFeed = MockV3Aggregator(surfTrip.getCollateralTokenPriceFeed(address(wUSDC)));
    }

    function deposit(uint256 amount) public payable {
        // TODO: Is there a better way to do this?
        vm.assume(msg.sender != address(helperConfig));
        vm.assume(msg.sender != address(invariantsTest));
        vm.assume(msg.sender != address(deploySurf));
        vm.assume(msg.sender != address(surfTrip));
        vm.assume(msg.sender != address(this));
        amount = bound(amount, MIN_DEPOSIT, MAX_DEPOSIT_SIZE);
        // vm.deal(address(msg.sender), amount);
        vm.startPrank(msg.sender);
        ERC20Mock(wUSDC).approve(address(surfTrip), amount);
        ERC20Mock(wUSDC).mint(msg.sender, amount);
        surfTrip.deposit(address(wUSDC), amount);
        vm.stopPrank();
        surfersWithDeposits.push(msg.sender);
    }

    function refund(uint256 seed) public {
        // TODO: Is there a better way to do this?
        vm.assume(msg.sender != address(helperConfig));
        vm.assume(msg.sender != address(invariantsTest));
        vm.assume(msg.sender != address(deploySurf));
        vm.assume(msg.sender != address(surfTrip));
        vm.assume(msg.sender != address(this));
        vm.assume(surfersWithDeposits.length > 0);
        address surfer = surfersWithDeposits[seed % surfersWithDeposits.length];
        vm.prank(surfer);
        surfTrip.refund();
    }

    // Helper functions
    // function _makeTransferAccordingFromSeed(uint256 seed) internal view returns (address) {
    //     if (seed % 2 == 0) {
    //         return address(wUSDC);
    //     }
    //     return surfTrip.getSupportedTokens()[seed % surfTrip.getSupportedTokens().length];
    // }
}
