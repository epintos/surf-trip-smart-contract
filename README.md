## SurfTrip Solidity Smart Contract

Developed a smart contract to organize surf trips, allowing surfers to deposit ETH or USDC to cover trip expenses.
- The deposit has a mininum trip fee that is defined in ETH by the organizer.
- Surfers can deposit in wUSDC. The trip fee is calculated using Chainlink ETH/USD price feed.
- Surfers can withdraw all the funds before the deadline.
- The organizer can set a deadline and on that day withdraw all the funds.

Note: This is a practice project where I explore and experiment with various Solidity concepts.

## Usage

### Install

```shell
$ make install
```

### Test

```shell
$ make test
```

### Deploy

```shell
$ make deploy-anvil
```

```shell
$ make deploy-sepolia
```

### Fund metamask or others

```shell
$ make fund-account
```
