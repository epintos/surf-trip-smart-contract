// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

/**
 * @title SurfTrip
 * @author Esteban Pintos
 * @notice This contract allows the Organizer of a surf trip to collect deposits from surfers. In certail deadline,
 * the organizer can withdraw all the deposits. If the deadline is not met, surfers can withdraw their deposits.
 */
contract SurfTrip {
    error SurfTrip_NotOrganizer();
    error SurfTrip__DeadlineAlreadySet();
    error SurfTrip__DepositIsTooLow(uint256 tripFee);
    error SurfTrip__NotEnoughDeposits();
    error SurfTrip__RefundFailed();
    error SurfTrip__DeadlineMet();
    error SurfTrip__WithdrawFailed();

    uint256 private immutable i_tripFee;
    address private s_organizer;
    uint256 private s_deadline;
    bool private s_deadlineSet;
    address[] private s_surfers;
    mapping(address user => uint256) private s_surfersBalances;

    event DepositMade(address indexed surfer, uint256 indexed amount, uint256 indexed newSurferBalance);
    event DeadlineSet(uint256 indexed deadline);
    event RefundMade(address indexed surfer, uint256 indexed amount, uint256 indexed surferBalanceLeft);
    event WithdrawMade(address indexed host, uint256 indexed amountWithdraw);
    event OrganizerChanged(address indexed previousOrganizer, address indexed newOrganizer);

    constructor(uint256 tripFee) {
        i_tripFee = tripFee;
        s_organizer = msg.sender;
    }

    modifier onlyOrganizer() {
        if (msg.sender != s_organizer) {
            revert SurfTrip_NotOrganizer();
        }
        _;
    }

    modifier beforeDeadline() {
        if (block.timestamp >= s_deadline) {
            revert SurfTrip__DeadlineMet();
        }
        _;
    }

    function deposit() public payable {
        if (msg.value < i_tripFee) {
            revert SurfTrip__DepositIsTooLow(i_tripFee);
        }
        if (s_surfersBalances[msg.sender] == 0) {
            s_surfers.push(msg.sender);
        }
        s_surfersBalances[msg.sender] += msg.value;
        emit DepositMade(msg.sender, msg.value, s_surfersBalances[msg.sender]);
    }

    function setDeadline(uint256 _days) external onlyOrganizer {
        if (s_deadlineSet) {
            revert SurfTrip__DeadlineAlreadySet();
        } else {
            s_deadline = block.timestamp + _days * 1 days;
            s_deadlineSet = true;
            emit DeadlineSet(s_deadline);
        }
    }

    function refund(uint256 amount) external beforeDeadline {
        uint256 surferBalance = s_surfersBalances[msg.sender];
        if (surferBalance < amount) {
            revert SurfTrip__NotEnoughDeposits();
        }
        (bool success,) = msg.sender.call{ value: amount }("");
        s_surfersBalances[msg.sender] -= amount;
        if (!success) {
            revert SurfTrip__RefundFailed();
        }
        emit RefundMade(msg.sender, amount, surferBalance - amount);
    }

    function withdraw() external onlyOrganizer {
        for (uint256 index = 0; index < s_surfers.length; index++) {
            address surfer = s_surfers[index];
            s_surfersBalances[surfer] = 0;
        }
        s_deadlineSet = false;
        delete s_surfers;

        uint256 currentBalance = address(this).balance;
        emit WithdrawMade(msg.sender, currentBalance);
        (bool success,) = msg.sender.call{ value: currentBalance }("");
        if (!success) {
            revert SurfTrip__WithdrawFailed();
        }
    }

    function changeOrganizer(address newOrganizer) external onlyOrganizer {
        address previousOrganizer = s_organizer;
        s_organizer = newOrganizer;
        emit OrganizerChanged(previousOrganizer, newOrganizer);
    }

    receive() external payable {
        deposit();
    }

    /* Getter functions */
    function getTripFee() external view returns (uint256) {
        return i_tripFee;
    }

    function getOrganizer() external view returns (address) {
        return s_organizer;
    }

    function getDeadline() external view returns (uint256) {
        return s_deadline;
    }

    function getSurferBalance(address surfer) external view returns (uint256) {
        return s_surfersBalances[surfer];
    }

    function getSurfer(uint256 index) public view returns (address) {
        return s_surfers[index];
    }
}
