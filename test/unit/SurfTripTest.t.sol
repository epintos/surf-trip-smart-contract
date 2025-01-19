// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import { Test, console2 } from "lib/forge-std/src/Test.sol";
import { SurfTrip } from "src/SurfTrip.sol";
import { Vm } from "forge-std/Vm.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { DeploySurfTrip } from "script/DeploySurfTrip.s.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20Mock } from
    "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/mocks/ERC20Mock.sol";

contract SurfTripTest is Test {
    SurfTrip public surfTrip;
    HelperConfig public helperConfig;
    address public DEPLOYER;
    address public SURFER = makeAddr("Surfer");
    uint256 public DEADLINE = 2;
    uint256 public STARTING_TIMESTAP = 1;
    uint256 public STARTING_SURFER_BALANCE = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 100 ether;
    address public wUSDC;
    address public wETHUSDPriceFeed;
    uint256 public tripFee;
    uint256 public constant SURFER_DEPOSIT = 40 ether; // Minimum deposit at $4000 per ETH

    event DepositMade(address indexed surfer, uint256 indexed amount, uint256 indexed newSurferBalance);
    event DeadlineSet(uint256 indexed deadline);
    event RefundMade(address indexed surfer);
    event WithdrawMade(address indexed host);
    event OrganizerChanged(address indexed previousOrganizer, address indexed newOrganizer);

    function setUp() public {
        DEPLOYER = msg.sender;
        (surfTrip, helperConfig) = new DeploySurfTrip().deployContract(DEPLOYER);
        (tripFee, wETHUSDPriceFeed, wUSDC) = helperConfig.activeNetworkConfig();
        vm.warp(STARTING_TIMESTAP);
        vm.prank(DEPLOYER);
        surfTrip.setDeadline(DEADLINE);

        ERC20Mock(wUSDC).mint(SURFER, STARTING_ERC20_BALANCE); // wUSDC
        vm.deal(SURFER, STARTING_SURFER_BALANCE); // ETH
    }

    modifier surferTokenContribution() {
        vm.startPrank(SURFER);
        ERC20Mock(wUSDC).approve(address(surfTrip), SURFER_DEPOSIT);
        surfTrip.deposit(wUSDC, SURFER_DEPOSIT);
        vm.stopPrank();
        _;
    }

    modifier surferETHContribution() {
        vm.startPrank(SURFER);
        (bool success,) = address(surfTrip).call{ value: tripFee }("");
        assertEq(success, true);
        vm.stopPrank();
        _;
    }

    // GETTERS
    function testGetTripFee() public view {
        assertEq(surfTrip.getTripFee(), tripFee);
    }

    function testGetOrganizer() public view {
        assertEq(surfTrip.getOrganizer(), DEPLOYER);
    }

    function testGetSurferBalance() public surferTokenContribution {
        assertEq(surfTrip.getSurferBalance(SURFER), surfTrip.getValueInETH(wUSDC, SURFER_DEPOSIT));
    }

    function testGetDeadline() public view {
        assertEq(surfTrip.getDeadline(), STARTING_TIMESTAP + DEADLINE * 1 days);
    }

    /// SET DEADLINE ///
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

    /// DEPOSIT ///
    function testDepositAddsContributorBalance() public surferTokenContribution {
        assertEq(surfTrip.getSurferTokenBalance(wUSDC, SURFER), SURFER_DEPOSIT);
        assertEq(ERC20Mock(wUSDC).balanceOf(address(surfTrip)), SURFER_DEPOSIT);
    }

    function testDepositAddsSurferToArrayOfSurfers() public surferTokenContribution {
        assertEq(surfTrip.getSurfer(0), SURFER);
    }

    function testDepositFailsIfDepositIsNotEnough() public {
        vm.startPrank(SURFER);
        ERC20Mock(wUSDC).approve(address(surfTrip), SURFER_DEPOSIT);
        vm.expectRevert(SurfTrip.SurfTrip__DepositIsTooLow.selector);
        surfTrip.deposit(wUSDC, tripFee);
        vm.stopPrank();
    }

    function testDepositEmitsEvent() public {
        vm.startPrank(SURFER);
        ERC20Mock(wUSDC).approve(address(surfTrip), SURFER_DEPOSIT);
        vm.expectEmit(true, true, true, false, address(surfTrip));
        emit DepositMade(SURFER, SURFER_DEPOSIT, surfTrip.getValueInETH(wUSDC, SURFER_DEPOSIT));
        surfTrip.deposit(wUSDC, SURFER_DEPOSIT);
        vm.stopPrank();
    }

    /// REFUND ///
    function testRefundFailsIfDeadlineHasPassed() public {
        vm.warp(STARTING_TIMESTAP + DEADLINE * 2 days);
        vm.startPrank(SURFER);
        vm.expectRevert(SurfTrip.SurfTrip__DeadlineMet.selector);
        surfTrip.refund();
        vm.stopPrank();
    }

    function testRefundRefundsAmountToSurfer() public surferTokenContribution surferETHContribution {
        uint256 startingBalance = ERC20Mock(wUSDC).balanceOf(SURFER);
        uint256 startingETHBalance = address(SURFER).balance;
        vm.startPrank(SURFER);
        surfTrip.refund();
        vm.stopPrank();
        uint256 newBalance = ERC20Mock(wUSDC).balanceOf(SURFER);
        uint256 newETHBalance = address(SURFER).balance;
        vm.startPrank(SURFER);
        assertEq(newBalance, startingBalance + SURFER_DEPOSIT);
        assertEq(newETHBalance, startingETHBalance + tripFee);
    }

    function testRefundReducesSurferDepositsBalance() public surferTokenContribution {
        uint256 startingBalance = surfTrip.getSurferTokenBalance(wUSDC, SURFER);
        vm.startPrank(SURFER);
        surfTrip.refund();
        vm.stopPrank();
        uint256 newBalance = surfTrip.getSurferTokenBalance(wUSDC, SURFER);
        assertEq(newBalance, startingBalance - SURFER_DEPOSIT);
    }

    function testRefundEmitsEvent() public surferTokenContribution {
        vm.startPrank(SURFER);
        vm.expectEmit(true, false, false, false, address(surfTrip));
        emit RefundMade(SURFER);
        surfTrip.refund();
        vm.stopPrank();
    }

    /// WITHDRAW ///
    function testWithdrawFailsIfNotOrganizer() public {
        vm.startPrank(SURFER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, SURFER));
        surfTrip.withdraw();
        vm.stopPrank();
    }

    function testWithdrawRemovesTheSurfersBalances() public surferTokenContribution surferETHContribution {
        vm.startPrank(DEPLOYER);
        surfTrip.withdraw();
        assertEq(surfTrip.getSurferBalance(SURFER), 0);
        vm.stopPrank();
    }

    function testWithdrawEmitsEvent() public {
        vm.startPrank(DEPLOYER);
        vm.expectEmit(true, false, false, false, address(surfTrip));
        emit WithdrawMade(DEPLOYER);
        surfTrip.withdraw();
        vm.stopPrank();
    }

    function testWithdrawSendsMoneyToOrganizer() public surferTokenContribution surferETHContribution {
        uint256 organizerStartingBalance = ERC20Mock(wUSDC).balanceOf(address(DEPLOYER));
        uint256 surferStartingBalance = surfTrip.getSurferTokenBalance(wUSDC, SURFER);
        uint256 organizerStartingETHBalance = address(DEPLOYER).balance;
        uint256 surferStartingETHBalance = surfTrip.getSurferETHBalance(SURFER);
        vm.prank(DEPLOYER);
        surfTrip.withdraw();
        assertEq(ERC20Mock(wUSDC).balanceOf(address(DEPLOYER)), organizerStartingBalance + surferStartingBalance);
        assertEq(address(DEPLOYER).balance, organizerStartingETHBalance + surferStartingETHBalance);
    }

    /// CHANGE ORGANIZER ///
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

    /// RECEIVE ///
    function testReceiveAddsSurferBalance() public surferETHContribution {
        assertEq(surfTrip.getSurferBalance(SURFER), tripFee);
        assertEq(surfTrip.getSurfer(0), SURFER);
    }

    function testReceiveAddsETHBalance() public surferETHContribution {
        assertEq(address(surfTrip).balance, tripFee);
    }

    function testReceiveEmitsEvent() public {
        vm.startPrank(SURFER);
        vm.expectEmit(true, true, true, false, address(surfTrip));
        emit DepositMade(SURFER, tripFee, tripFee);
        (bool success,) = address(surfTrip).call{ value: tripFee }("");
        assertEq(success, true);
        vm.stopPrank();
    }
}
