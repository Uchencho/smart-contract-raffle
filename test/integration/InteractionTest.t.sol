// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";

contract InteractionTest is Test {
    HelperConfig.NetworkConfig public networkConfig;
    Raffle public raffle;
    address public PLAYER = makeAddr("PLAYER");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 subscriptionID;

    function setUp() external {
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        HelperConfig helperConfig = new HelperConfig();
        networkConfig = helperConfig.getConfig();
    }

    modifier subscriptionCreated() {
        CreateSubscription createSubscription = new CreateSubscription();
        subscriptionID = createSubscription.createSubscription(
            networkConfig.vrfCoordinator,
            networkConfig.account
        );
        _;
    }

    modifier raffleCreated() {
        Raffle raffleClient = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            subscriptionID,
            networkConfig.callbackGasLimit
        );
        raffle = raffleClient;
        _;
    }

    function testCreateSubscriptionUsingConfigIsSuccessful() public {
        CreateSubscription createSubscription = new CreateSubscription();
        uint256 subId = createSubscription.createSubscriptionUsingConfig();
        assert(subId > 0);
    }

    function testCreateSubscriptionIsSuccessful() public {
        CreateSubscription createSubscription = new CreateSubscription();
        uint256 subId = createSubscription.createSubscription(
            networkConfig.vrfCoordinator,
            PLAYER
        );
        assert(subId > 0);
    }

    function testFundSubscriptionIsSuccessful() public subscriptionCreated {
        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(
            networkConfig.vrfCoordinator,
            subscriptionID,
            networkConfig.link,
            networkConfig.account
        );
    }

    function testAddConsumerIsSuccessful()
        public
        subscriptionCreated
        raffleCreated
    {
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            networkConfig.vrfCoordinator,
            subscriptionID,
            networkConfig.account
        );
    }
}
