// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract RaffleTest is Test {
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
}
