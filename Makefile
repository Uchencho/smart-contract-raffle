include .env

.PHONY: test
test:
	forge test -vvvv

fund-subscription:
	forge script script/Interactions.s.sol:FundSubscription --rpc-url $(SEPOLIA_RPC_URL) --account $(KEY_NAME) --broadcast