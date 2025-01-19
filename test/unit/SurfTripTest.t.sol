// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import { Test, console2 } from "lib/forge-std/src/Test.sol";
import { SurfTrip } from "src/SurfTrip.sol";
import { Vm } from "forge-std/Vm.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { DeploySurfTrip } from "script/DeploySurfTrip.s.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract SurfTripTest is Test {
    SurfTrip public surfTrip;
    uint256 public TRIP_FEE = 0.01 ether;
    address public DEPLOYER;
    address public SURFER = makeAddr("Surfer");
    uint256 public DEADLINE = 2;
    uint256 public STARTING_TIMESTAP = 1;
    uint256 public STARTING_SURFER_BALANCE = 10 ether;

    event DepositMade(address indexed surfer, uint256 indexed amount, uint256 indexed newSurferBalance);
    event DeadlineSet(uint256 indexed deadline);
    event RefundMade(address indexed surfer, uint256 indexed amount, uint256 indexed surferBalanceLeft);
    event WithdrawMade(address indexed host, uint256 indexed amountWithdraw);
    event OrganizerChanged(address indexed previousOrganizer, address indexed newOrganizer);

    function setUp() public {
        DEPLOYER = msg.sender;
        (surfTrip,) = new DeploySurfTrip().deployContract(DEPLOYER);
        vm.warp(STARTING_TIMESTAP);
        vm.prank(DEPLOYER);
        surfTrip.setDeadline(DEADLINE);
    }

    modifier surferContribution() {
        vm.startPrank(SURFER);
        vm.deal(SURFER, STARTING_SURFER_BALANCE);
        surfTrip.deposit{ value: TRIP_FEE }();
        vm.stopPrank();
        _;
    }

    // GETTERS
    function testGetTripFee() public view {
        assertEq(surfTrip.getTripFee(), TRIP_FEE);
    }

    function testGetOrganizer() public view {
        assertEq(surfTrip.getOrganizer(), DEPLOYER);
    }

    function testGetSurferBalance() public surferContribution {
        assertEq(surfTrip.getSurferBalance(SURFER), TRIP_FEE);
    }

    function testGetDeadline() public view {
        assertEq(surfTrip.getDeadline(), STARTING_TIMESTAP + DEADLINE * 1 days);
    }

    // SET DEADLINE
    function testSetDeadlineBySomeoneElseFails() public {
        vm.prank(SURFER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, SURFER));
        surfTrip.setDeadline(DEADLINE);
    }

    function testSetDeadlineEmitsEvent() public {
        vm.startPrank(DEPLOYER);
        surfTrip.withdraw(); // Resets s_deadlineSet
        vm.expectEmit(true, false, false, false, address(surfTrip));
        emit DeadlineSet(STARTING_TIMESTAP + DEADLINE * 1 days);
        surfTrip.setDeadline(DEADLINE);
        vm.stopPrank();
    }

    function testSetDeadlineWhenAlreadySetFails() public {
        vm.prank(DEPLOYER);
        vm.expectRevert(SurfTrip.SurfTrip__DeadlineAlreadySet.selector);
        surfTrip.setDeadline(DEADLINE);
    }

    // DEPOSIT
    function testDepositAddsContributorBalance() public {
        vm.startPrank(SURFER);
        vm.deal(SURFER, STARTING_SURFER_BALANCE);
        surfTrip.deposit{ value: TRIP_FEE }();
        assertEq(surfTrip.getSurferBalance(SURFER), TRIP_FEE);
        surfTrip.deposit{ value: TRIP_FEE }();
        vm.stopPrank();
        assertEq(surfTrip.getSurferBalance(SURFER), TRIP_FEE * 2);
        assertEq(address(surfTrip).balance, TRIP_FEE * 2);
    }

    function testDepositAddsSurferToArrayOfSurfers() public surferContribution {
        assertEq(surfTrip.getSurfer(0), SURFER);
    }

    function testDepositFailsIfDepositIsNotEnough() public {
        vm.prank(SURFER);
        vm.deal(SURFER, STARTING_SURFER_BALANCE);
        vm.expectRevert(abi.encodeWithSelector(SurfTrip.SurfTrip__DepositIsTooLow.selector, TRIP_FEE));
        surfTrip.deposit{ value: TRIP_FEE - 1 }();
    }

    function testDepositEmitsEvent() public {
        vm.prank(SURFER);
        vm.deal(SURFER, STARTING_SURFER_BALANCE);
        vm.expectEmit(true, true, true, false, address(surfTrip));
        emit DepositMade(SURFER, TRIP_FEE, TRIP_FEE);
        surfTrip.deposit{ value: TRIP_FEE }();
    }

    // REFUND
    function testRefundFailsIfDeadlineHasPassed() public {
        vm.warp(STARTING_TIMESTAP + DEADLINE * 2 days);
        vm.startPrank(SURFER);
        vm.expectRevert(SurfTrip.SurfTrip__DeadlineMet.selector);
        surfTrip.refund(TRIP_FEE);
        vm.stopPrank();
    }

    function testRefundFailsIfAmountIsZero() public {
        vm.startPrank(SURFER);
        vm.expectRevert(SurfTrip.SurfTrip__NeedsToBeMoreThanZero.selector);
        surfTrip.refund(0);
        vm.stopPrank();
    }

    function testRefundFailsIfNotEnoughtSurferBalance() public surferContribution {
        vm.startPrank(SURFER);
        vm.expectRevert(SurfTrip.SurfTrip__NotEnoughDeposits.selector);
        surfTrip.refund(TRIP_FEE + 1);
        vm.stopPrank();
    }

    function testRefundRefundsAmountToSurfer() public surferContribution {
        uint256 startingBalance = address(SURFER).balance;
        vm.startPrank(SURFER);
        surfTrip.refund(TRIP_FEE);
        vm.stopPrank();
        uint256 newBalance = address(SURFER).balance;
        assertEq(newBalance, startingBalance + TRIP_FEE);
    }

    function testRefundReducesSurferDepositsBalance() public surferContribution {
        uint256 startingBalance = surfTrip.getSurferBalance(SURFER);
        vm.startPrank(SURFER);
        surfTrip.refund(TRIP_FEE);
        vm.stopPrank();
        uint256 newBalance = surfTrip.getSurferBalance(SURFER);
        assertEq(newBalance, startingBalance - TRIP_FEE);
    }

    function testRefundEmitsEvent() public surferContribution {
        vm.startPrank(SURFER);
        vm.expectEmit(true, true, true, false, address(surfTrip));
        emit RefundMade(SURFER, TRIP_FEE, 0);
        surfTrip.refund(TRIP_FEE);
        vm.stopPrank();
    }

    // WITHDRAW
    function testWithdrawFailsIfNotOrganizer() public {
        vm.startPrank(SURFER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, SURFER));
        surfTrip.withdraw();
        vm.stopPrank();
    }

    function testWithdrawRemovesTheSurfersBalances() public surferContribution {
        vm.prank(DEPLOYER);
        surfTrip.withdraw();
        assertEq(surfTrip.getSurferBalance(SURFER), 0);
    }

    function testWithdrawEmitsEvent() public {
        vm.startPrank(DEPLOYER);
        uint256 balance = address(surfTrip).balance;
        vm.expectEmit(true, true, false, false, address(surfTrip));
        emit WithdrawMade(DEPLOYER, balance);
        surfTrip.withdraw();
        vm.stopPrank();
    }

    function testWithdrawSendsMoneyToOrganizer() public surferContribution {
        uint256 organizerStartingBalance = address(DEPLOYER).balance;
        uint256 startingContractBalance = address(surfTrip).balance;
        vm.prank(DEPLOYER);
        surfTrip.withdraw();
        assertEq(address(surfTrip).balance, 0);
        assertEq(address(DEPLOYER).balance, organizerStartingBalance + startingContractBalance);
    }

    // CHANGE ORGANIZER
    function testChangeOrganizerFailsIfCalledBySomeoneElse() public {
        vm.prank(SURFER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, SURFER));
        surfTrip.changeOrganizer(SURFER);
    }

    function testChangeOrganizerChangesOrganizer() public {
        vm.prank(DEPLOYER);
        surfTrip.changeOrganizer(SURFER);
        assertEq(surfTrip.getOrganizer(), SURFER);
    }

    function testChangeOrganizerEmitsEvent() public {
        vm.prank(DEPLOYER);
        vm.expectEmit(true, true, false, false, address(surfTrip));
        emit OrganizerChanged(DEPLOYER, SURFER);
        surfTrip.changeOrganizer(SURFER);
    }

    // RECEIVE
    function testReceiveAddsSurferBalance() public {
        vm.prank(SURFER);
        vm.deal(SURFER, STARTING_SURFER_BALANCE);
        (bool success,) = address(surfTrip).call{ value: TRIP_FEE }("");
        assertEq(success, true);
        assertEq(surfTrip.getSurfer(0), SURFER);
    }
}
