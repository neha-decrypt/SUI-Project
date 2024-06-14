sui client new-env --alias devnet --rpc https://fullnode.devnet.sui.io:443

sui client switch --env devnet

sui move build

sui client publish --gas-budget 100000000