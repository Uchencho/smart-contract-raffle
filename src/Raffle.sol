// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle contract
 * @author Uchenna Alozie
 * @notice This is an example of a raffle contract
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    // Errors
    error Raffle__NotEnoughETHSent(uint256 expected, uint256 actual);
    error Raffle__NotEnoughTimePassed();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 playersCount,
        RaffleState raffleState
    );
    error Raffle__IndexOutOfBounds();

    enum RaffleState {
        OPEN,
        CALCULATING_WINNER
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint16 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimestamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    // @dev The interval in seconds at which the raffle will be picked
    uint256 private immutable i_interval;

    // Events
    event RaffleSubscribed(address indexed player, uint256 amount);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimestamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        // for versions 0.8.26 and above, use this instead of the below (this is less gas efficient though)
        // require(msg.value >= i_entranceFee, NotEnoughETHSent());

        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHSent(i_entranceFee, msg.value);
        }

        s_players.push(payable(msg.sender));
        emit RaffleSubscribed(msg.sender, msg.value);
    }

    /**
     * @dev this is the function that the Chainlink nodes will call to see if the lottery
     * is ready to have a winner a picked. The following should be true in order for
     * UpkeepNeeded to be true
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. Implicitly, your subscription has LINK
     * @param -ignored
     * @return UpkeepNeeded - true if it is time to restart the lottery
     * @return - ignored
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool UpkeepNeeded, bytes memory /* performData */) {
        bool intervalHasPassed = (block.timestamp - s_lastTimestamp) >=
            i_interval;
        bool lotteryIsOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        UpkeepNeeded =
            intervalHasPassed &&
            lotteryIsOpen &&
            hasBalance &&
            hasPlayers;
        return (UpkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                s_raffleState
            );
        }

        s_raffleState = RaffleState.CALCULATING_WINNER;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestId); // redundant because the requestRandomWords function emits an event which contains the requestId
    }

    function fulfillRandomWords(
        uint256,
        uint256[] calldata randomWords
    ) internal override {
        // EFfects
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        // Interactions
        (bool callSuccess, ) = winner.call{value: address(this).balance}("");
        if (!callSuccess) {
            revert Raffle__TransferFailed();
        }
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 index) external view returns (address) {
        if (index >= s_players.length) {
            revert Raffle__IndexOutOfBounds();
        }
        return s_players[index];
    }
}
