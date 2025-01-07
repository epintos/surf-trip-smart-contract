-include .env

.PHONY: all test deploy

build :; forge build

test :; forge test

deploy-sepolia :
	@forge script script/DeploySurfTrip.s.sol:DeploySurfTrip --rpc-url $(SEPOLIA_RPC_URL) --account $(SEPOLIA_ACCOUNT) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

deploy-anvil :
	@forge script script/DeploySurfTrip.s.sol:DeploySurfTrip --rpc-url $(RPC_URL) --account $(ANVIL_ACCOUNT) --broadcast -vvvv
