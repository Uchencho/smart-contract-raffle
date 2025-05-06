include .env

.PHONY: test
test:
	forge test -vvvv

fund-subscription:
	forge script script/Interactions.s.sol:FundSubscription --rpc-url $(SEPOLIA_RPC_URL) --account $(KEY_NAME) --broadcast

generate-report:
	forge coverage --report debug > coverage.txt

run-fork-test:
	forge test --fork-url $(SEPOLIA_RPC_URL)

run-fork-test-verbose:
	forge test --fork-url $(SEPOLIA_RPC_URL) -vvvv

build:; forge build

install:; forge install cyfrin/foundry-devops@v0.2.2 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@v0.6.1 --no-commit && forge install foundry-rs/forge-std@v1.8.2 --no-commit && forge install transmissions11/solmate@v6 --no-commit
