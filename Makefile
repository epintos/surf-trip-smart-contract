-include .env

.PHONY: all test deploy

build :; forge build

test :; forge test

test-fork-sepolia :; @forge test --fork-url $(SEPOLIA_RPC_URL)

install :
	forge install foundry-rs/forge-std@v1.9.5 --no-commit && \
	forge install openzeppelin/openzeppelin-contracts@v5.2.0 --no-commit && \
	forge install smartcontractkit/chainlink-brownie-contracts@1.3.0 --no-commit

deploy-sepolia :
	@forge script script/DeploySurfTrip.s.sol:DeploySurfTrip --rpc-url $(SEPOLIA_RPC_URL) --account $(SEPOLIA_ACCOUNT) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

deploy-anvil :
	@forge script script/DeploySurfTrip.s.sol:DeploySurfTrip --rpc-url $(RPC_URL) --account $(ANVIL_ACCOUNT) --broadcast -vvvv

fund-account :
	cast send $(SEPOLIA_ACCOUNT_ADDRESS) --value 0.01ether --rpc-url $(RPC_URL) --account $(ANVIL_ACCOUNT)
