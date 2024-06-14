module Staking::staking {
    use sui::coin::{Self, Coin, TreasuryCap,zero,split,join,burn};
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
        // let sender = tx_context::sender(ctx);
        // con
        // let remaining_coin = coin::split(&mut payment, MINT_COST, ctx);
        transfer::share_object(con);
    }

    // Public entry function to stake tokens
    public entry fun stake<COIN>( payment: Coin<COIN>, contract: &mut TStakingContract, ctx: &mut TxContext) {
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
        transfer::public_transfer(payment, sui::object::uid_to_address(&contract.id));
}

 // Public entry function to unstake tokens
    public entry fun unstake<COIN>(
        contract: &mut TStakingContract,
        ctx: &mut TxContext
    ) {
        // Get sender's address
        let sender = ctx.sender();

        // Check if sender is a staker
        let mut staker_index: u64 = 0;
        let mut found: bool = false;

        let stakers_len = vector::length(&contract.stakers);
        let mut i = 0;
        while (i < stakers_len) {
            let staker = vector::borrow(&contract.stakers, i);
            if (staker.address == sender) {
                found = true;
                staker_index = i;
                break
            };
            i = i + 1;
        };

        assert!(found, 102); // Ensure sender is a staker

        // Retrieve staker's balance and remove staker from the stakers vector
        // let staker = vector::remove(&mut contract.stakers, staker_index);
        let amount = 10000;

        // Create a new coin with the staked amount
        // Create a new coin with the unstaked amount
         let mut zero_coin = zero<COIN>(ctx);
        let new_coin= split(&mut zero_coin, amount, ctx);
        
        // Transfer staked coins back to the sender
        transfer::public_transfer(new_coin, sender);
        transfer::public_transfer(zero_coin, sender);
    }

}