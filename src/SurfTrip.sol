// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title SurfTrip
 * @author Esteban Pintos
 * @notice This contract allows the Organizer of a surf trip to collect deposits from surfers. In certail deadline,
 * the organizer can withdraw all the deposits. If the deadline is not met, surfers can withdraw their deposits.
 */
contract SurfTrip is Ownable, ReentrancyGuard {
    /// ERRORS ///
    error SurfTrip__DeadlineAlreadySet();
    error SurfTrip__DepositIsTooLow();
    error SurfTrip__NotEnoughDeposits();
    error SurfTrip__RefundFailed();
    error SurfTrip__DeadlineMet();
    error SurfTrip__WithdrawFailed();
    error SurfTrip__NeedsToBeMoreThanZero();
    error SurfTrip__TokenNotSupported();
    error SurfTrip__RefundIsTooHigh();

    /// STATE VARIABLES ///
    uint256 private immutable i_tripFeeInETH;
    uint256 private s_deadline;
    bool private s_deadlineSet;
    address[] private s_surfers;
    mapping(address surfer => uint256 balance) private s_surfersETHBalance;
    mapping(address surfer => mapping(address token => uint256 balance)) private s_surfersERC20Balances;
    mapping(address token => address priceFeed) private s_tokenPriceFeeds;
    address[] private s_supportedERC20Tokens;
    uint256 private constant PRICE_FEED_PRECISION = 1e8;
    uint256 private constant PRECISION = 1e18;

    /// EVENTS ///
    event DepositMade(address indexed surfer, uint256 indexed amount, uint256 indexed newSurferBalance);
    event DeadlineSet(uint256 indexed deadline);
    event RefundMade(address indexed surfer);
    event WithdrawMade(address indexed host);
    event OrganizerChanged(address indexed previousOrganizer, address indexed newOrganizer);

    /// MODIFIERS ///
    modifier beforeDeadline() {
        if (s_deadlineSet && block.timestamp >= s_deadline) {
            revert SurfTrip__DeadlineMet();
        }
        _;
    }

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert SurfTrip__NeedsToBeMoreThanZero();
        }
        _;
    }

    modifier supportedToken(address token) {
        if (s_tokenPriceFeeds[token] == address(0)) {
            revert SurfTrip__TokenNotSupported();
        }
        _;
    }

    /// FUNCTIONS ///

    // CONSTRUCTOR
    constructor(
        uint256 tripFeeInETH,
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses
    )
        Ownable(msg.sender)
    {
        i_tripFeeInETH = tripFeeInETH;
        for (uint256 index = 0; index < tokenAddresses.length; index++) {
            s_supportedERC20Tokens.push(tokenAddresses[index]);
            s_tokenPriceFeeds[tokenAddresses[index]] = priceFeedAddresses[index];
        }
    }

    // EXTERNAL FUNCTIONS
    function setDeadline(uint256 _days) external onlyOwner {
        if (s_deadlineSet) {
            revert SurfTrip__DeadlineAlreadySet();
        } else {
            s_deadline = block.timestamp + _days * 1 days;
            s_deadlineSet = true;
            emit DeadlineSet(s_deadline);
        }
    }

    /**
     * @notice Refunds the deposits to the surfer if the deadline is not met.
     */
    function refund() external beforeDeadline nonReentrant {
        for (uint256 index = 0; index < s_supportedERC20Tokens.length; index++) {
            address token = s_supportedERC20Tokens[index];
            uint256 tokenBalance = s_surfersERC20Balances[msg.sender][token];
            if (tokenBalance != 0) {
                bool transferSuccess = IERC20(token).transfer(msg.sender, tokenBalance);
                if (!transferSuccess) {
                    revert SurfTrip__RefundFailed();
                }
                s_surfersERC20Balances[msg.sender][token] = 0;
            }
        }
        uint256 ethBalance = s_surfersETHBalance[msg.sender];
        if (ethBalance != 0) {
            s_surfersETHBalance[msg.sender] = 0;
            (bool success,) = msg.sender.call{ value: ethBalance }("");
            if (!success) {
                revert SurfTrip__RefundFailed();
            }
        }
        emit RefundMade(msg.sender);
    }

    function withdraw() external onlyOwner nonReentrant {
        for (uint256 index = 0; index < s_surfers.length; index++) {
            address surfer = s_surfers[index];
            s_surfersETHBalance[surfer] = 0;
            for (uint256 tokenIndex = 0; tokenIndex < s_supportedERC20Tokens.length; tokenIndex++) {
                address token = s_supportedERC20Tokens[tokenIndex];
                s_surfersERC20Balances[surfer][token] = 0;
            }
        }
        s_deadlineSet = false;
        delete s_surfers;

        for (uint256 index = 0; index < s_supportedERC20Tokens.length; index++) {
            address token = s_supportedERC20Tokens[index];
            uint256 tokenBalance = IERC20(token).balanceOf(address(this));
            if (tokenBalance != 0) {
                bool transferSuccess = IERC20(token).transfer(msg.sender, tokenBalance);
                if (!transferSuccess) {
                    revert SurfTrip__WithdrawFailed();
                }
            }
        }

        uint256 currentETHBalance = address(this).balance;
        (bool success,) = msg.sender.call{ value: currentETHBalance }("");
        if (!success) {
            revert SurfTrip__WithdrawFailed();
        }
        emit WithdrawMade(msg.sender);
    }

    function changeOrganizer(address newOrganizer) external onlyOwner {
        address previousOrganizer = owner();
        transferOwnership(newOrganizer);
        emit OrganizerChanged(previousOrganizer, newOrganizer);
    }

    receive() external payable {
        if (s_surfersETHBalance[msg.sender] != 0 && msg.value < i_tripFeeInETH) {
            revert SurfTrip__DepositIsTooLow();
        }
        s_surfers.push(msg.sender);
        s_surfersETHBalance[msg.sender] += msg.value;
        emit DepositMade(msg.sender, msg.value, s_surfersETHBalance[msg.sender]);
    }

    // PUBLIC FUNCTIONS

    function deposit(address token, uint256 amount) public nonReentrant supportedToken(token) beforeDeadline {
        uint256 surferBalanceInETH = _getSurferBalance(msg.sender);
        uint256 amountInETH = _getValueInETH(token, amount);
        if (surferBalanceInETH + amountInETH < i_tripFeeInETH) {
            revert SurfTrip__DepositIsTooLow();
        }
        if (s_surfersERC20Balances[msg.sender][token] == 0) {
            s_surfers.push(msg.sender);
        }
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        s_surfersERC20Balances[msg.sender][token] += amount;
        emit DepositMade(msg.sender, amount, surferBalanceInETH + amountInETH);
    }

    // PRIVATE & INTERNAL VIEW FUNCTIONS
    function _getValueInETH(address token, uint256 amount) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokenPriceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (amount / (uint256(price) * PRICE_FEED_PRECISION)) * PRECISION;
    }

    function _getSurferBalance(address surfer) public view returns (uint256 amount) {
        for (uint256 index = 0; index < s_supportedERC20Tokens.length; index++) {
            address token = s_supportedERC20Tokens[index];
            if (s_surfersERC20Balances[surfer][token] != 0) {
                amount += _getValueInETH(token, s_surfersERC20Balances[surfer][token]);
            }
        }
        amount += s_surfersETHBalance[surfer];
    }

    // PUBLIC & EXTERNAL VIEW FUNCTIONS
    function getTripFee() external view returns (uint256) {
        return i_tripFeeInETH;
    }

    function getOrganizer() external view returns (address) {
        return owner();
    }

    function getDeadline() external view returns (uint256) {
        return s_deadline;
    }

    function getSurfer(uint256 index) public view returns (address) {
        return s_surfers[index];
    }

    /**
     * @notice Returns the balance of a surfer in ETH, including all tokens.
     */
    function getSurferBalance(address surfer) external view returns (uint256 amount) {
        return _getSurferBalance(surfer);
    }

    function getSurferTokenBalance(address token, address surfer) external view returns (uint256) {
        return s_surfersERC20Balances[surfer][token];
    }

    function getSurferETHBalance(address surfer) external view returns (uint256) {
        return s_surfersETHBalance[surfer];
    }

    function getValueInETH(address token, uint256 amount) external view returns (uint256) {
        return _getValueInETH(token, amount);
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_tokenPriceFeeds[token];
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return s_supportedERC20Tokens;
    }
}
