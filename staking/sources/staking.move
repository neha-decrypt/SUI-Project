module Staking::staking {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::tx_context::TxContext;
    use sui::object::{Self, ID, UID};
   
    // Define the staker struct to hold staker information
    public struct Staker has copy, store {
        address: address,
        balance: u64,
    }

    // Define the storage for staking contract
    public struct TStakingContract has store, key {
        id: UID,
        stakers: vector<Staker>,
    }

    // Initialization function
    fun init(ctx: &mut TxContext) {
        let con =TStakingContract {
            id: object::new(ctx),
            stakers: vector::empty(),
        };
        let sender = tx_context::sender(ctx);
        // con
        // let remaining_coin = coin::split(&mut payment, MINT_COST, ctx);
        transfer::public_transfer(con, sender);
    }

    // Public entry function to stake tokens
    public entry fun stake<COIN>( mut payment: Coin<COIN>, contract: &mut TStakingContract, ctx: &mut TxContext) {
        // Ensure staking amount is greater than zero
        let amount = payment.value();
        assert!(amount > 0, 101);
        let treasury_address = @0xc943ad1b5ea2e60372572795b32b3241bb4e680e68667a7abebcbab7b092cf5b;
        // Get sender's address
        let sender = ctx.sender();

        // Check if sender is already a staker
        let mut is_existing_staker = false;
        let mut staker_index = 0;
        let mut _staker_balance = 0;

        let stakers_len = vector::length(&contract.stakers);
        let mut i = 0;
        while (i < stakers_len) {
            let staker = vector::borrow(&contract.stakers, i);
            if (staker.address == sender) {
                is_existing_staker = true;
                staker_index = i;
                _staker_balance = staker.balance + amount;
                break
            };
            i = i + 1;
        };

        // If sender is already staking, update staked balance
        if (is_existing_staker) {
            let mut _staker = vector::borrow_mut(&mut contract.stakers, staker_index);
            _staker.balance = _staker.balance + amount;
        } else {
            // If sender is a new staker, add them to stakers vector
            let new_staker = Staker {
                address: sender,
                balance: amount
            };
            vector::push_back(&mut contract.stakers, new_staker);
        };
        transfer::public_transfer(payment, treasury_address);
}
}