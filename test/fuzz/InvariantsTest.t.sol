// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import { Test, console2 } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { SurfTrip } from "src/SurfTrip.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { DeploySurfTrip } from "script/DeploySurfTrip.s.sol";
import { Handler } from "./Handler.t.sol";
import { ERC20Mock } from
    "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/mocks/ERC20Mock.sol";

contract InvariantsTest is StdInvariant, Test {
    SurfTrip surfTrip;
    HelperConfig helperConfig;
    DeploySurfTrip deploySurfTrip;
    Handler handler;
    address wUSDC;
    address wETHUSDPriceFeed;
    uint256 tripFee;

    function setUp() public {
        deploySurfTrip = new DeploySurfTrip();
        (surfTrip, helperConfig) = deploySurfTrip.deployContract(msg.sender);
        (tripFee, wETHUSDPriceFeed, wUSDC) = helperConfig.activeNetworkConfig();
        handler = new Handler(surfTrip, helperConfig, this, deploySurfTrip);
        targetContract(address(handler));
    }

    function invariant_openToWithdrawBeforeDeadine() public view {
        uint256 tokenBalance = ERC20Mock(wUSDC).balanceOf(address(surfTrip));
        uint256 ethBalance = address(surfTrip).balance;
        assert(tokenBalance + ethBalance >= 0);
    }

    function invariant_gettersShouldNotRevert() public view {
        surfTrip.getDeadline();
        surfTrip.getOrganizer();
        surfTrip.getTripFee();
        surfTrip.getSurferBalance(msg.sender);
        surfTrip.getValueInETH(wUSDC, 1 ether);
        surfTrip.getCollateralTokenPriceFeed(wUSDC);
        surfTrip.getSupportedTokens();
    }
}
