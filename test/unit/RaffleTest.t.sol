// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;
    address public PLAYER = makeAddr("PLAYER");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    event RaffleSubscribed(address indexed player, uint256 amount);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();

        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getConfig();
        entranceFee = networkConfig.entranceFee;
        interval = networkConfig.interval;
        vrfCoordinator = networkConfig.vrfCoordinator;
        gasLane = networkConfig.gasLane;
        subscriptionId = networkConfig.subscriptionId;
        callbackGasLimit = networkConfig.callbackGasLimit;
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // set the time to be after the interval
        vm.roll(block.number + 1); // set the block number to be after the current block number
        _; // meaning running the above BEFORE the function
    }

    // skips fork tests because the current test uses mock and that would fail on a fork URL
    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWithoutEnoughEth() public {
        // act
        vm.prank(PLAYER); // gotten from the forge cheat codes

        // assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__NotEnoughETHSent.selector,
                entranceFee, // expected
                0 // actual (no ETH sent)
            )
        );

        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerEntrance() public {
        // arrange
        vm.prank(PLAYER);

        // act
        raffle.enterRaffle{value: entranceFee}();

        // assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        // arrange
        vm.prank(PLAYER);

        // act
        bool hasFirstIndexedParam = true;
        bool hasSecondParam = false; // or has second indexed param
        bool hasThirdParam = false; // or has third indexed param
        bool hasFourthParam = true; // or has a non indexed param
        address addressOfEmittingEvent = address(raffle);

        vm.expectEmit(
            hasFirstIndexedParam,
            hasSecondParam,
            hasThirdParam,
            hasFourthParam,
            addressOfEmittingEvent
        );
        emit RaffleSubscribed(PLAYER, entranceFee);

        // assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testPlayersNotAllowedToEnterRaffleWhileRaffleIsCalculatingWinner()
        public
    {
        // arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // set the time to be after the interval
        vm.roll(block.number + 1); // set the block number to be after the current block number
        raffle.performUpkeep("");

        // act // assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); // will revert because the raffle is not open and you are trying to enter it
    }

    function testCheckUpkeepReturnsFalseIfItHasNoBalanceAndNoPlayers() public {
        // arrange
        vm.warp(block.timestamp + interval + 1); // set the time to be after the interval
        vm.roll(block.number + 1); // set the block number to be after the current block number

        // act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public {
        // arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // set the time to be after the interval
        vm.roll(block.number + 1); // set the block number to be after the current block number
        raffle.performUpkeep("");

        // act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    function testPerformUpkeepRevertsIfUpkeepIsNotNeeded() public {
        // arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        uint256 currentBalance = entranceFee;
        uint256 numberOfPlayers = 1;
        Raffle.RaffleState rState = Raffle.RaffleState.OPEN;

        // reverting because checkUpkeep returns false which is because the timestamp is not after the interval
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numberOfPlayers,
                rState
            )
        );
        raffle.performUpkeep("");
    }

    function testEntranceFeeIsCorrect() public view {
        // act
        assert(raffle.getEntranceFee() == entranceFee);
    }

    function testRaffleStateIsCalculatingAfterPerformUpkeep() public {
        // arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // set the time to be after the interval
        vm.roll(block.number + 1); // set the block number to be after the current block number
        raffle.performUpkeep("");

        // assert
        assert(
            raffle.getRaffleState() == Raffle.RaffleState.CALCULATING_WINNER
        );
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestID()
        public
        raffleEnteredAndTimePassed
    {
        // Act
        vm.recordLogs(); // records all emitted events
        raffle.performUpkeep("");
        Vm.Log[] memory recordedLogs = vm.getRecordedLogs();

        // vrf coordinator emits RandomWordsRequested and the request id is one of the non indexed fields so it
        // be stored in the data field, with all the other non indexed fields
        (uint256 requestId, , , , ) = abi.decode(
            recordedLogs[0].data,
            (uint256, uint256, uint16, uint32, uint32)
        );

        bytes32 customRequestId = recordedLogs[1].topics[1]; // requestID we emitted, the redundant one

        // Assert
        assert(uint256(customRequestId) > 0);
        assert(uint256(customRequestId) == uint256(requestId)); // just showing that there is no need to emit ours
        assert(
            raffle.getRaffleState() == Raffle.RaffleState.CALCULATING_WINNER
        );
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipFork {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        // Arrange
        uint256 additionalEntrants = 4;
        uint256 startingIndex = 1;

        address expectedWinner = address(uint160(1));
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // hoax will prank as player and then deal 1 ether to the player
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimestamp = raffle.getLastTimestamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs(); // records all emitted events
        raffle.performUpkeep("");
        Vm.Log[] memory recordedLogs = vm.getRecordedLogs();

        (uint256 requestId, , , , ) = abi.decode(
            recordedLogs[0].data,
            (uint256, uint256, uint16, uint32, uint32)
        );

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(raffle)
        );

        recordedLogs = vm.getRecordedLogs();
        bytes32 winnerPicked = recordedLogs[1].topics[1];
        address emittedWinner = address(uint160(uint256(winnerPicked)));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState rState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimestamp = raffle.getLastTimestamp();
        uint256 prize = entranceFee + (additionalEntrants * entranceFee);

        assert(recentWinner == expectedWinner);
        assert(emittedWinner == recentWinner); // assert that the winner picked is the same as the recent winner
        assert(rState == Raffle.RaffleState.OPEN);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimestamp > startingTimestamp);
    }
}
