module staking::staking {
    use sui::object::{Self, ID, UID};
    use sui::event;
    use sui::transfer;
    use sui::bag::{Self,Bag,contains};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::clock::{Self, Clock};
    use sui::balance::{Self, Balance};

    public struct CreateStakePoolEvent has copy, drop {
        staking_pool_id: object::ID,
    }

    public struct RemoveStakerEvent has copy, drop {
        user: address,
    }
    
    public struct CreateStakeLockEvent has copy, drop {
        staking_lock_id: object::ID,
        amount: u64,
        lock_time: u64,
        staking_start_timestamp: u64,
    }
    
    public struct ExtendStakeLockEvent has copy, drop {
        staking_lock_id: object::ID,
        amount: u64,
        lock_time: u64,
        staking_start_timestamp: u64,
    }
    
    public struct WithdrawStakeEvent has copy, drop {
        staking_lock_id: object::ID,
        amount: u64,
    }
    
    public struct Staker has store, drop {
        stake_balance: u64,
        user: address
    }

    public struct StakingPool<phantom T0> has store, key {
        id: object::UID,
        stake_balance: balance::Balance<T0>,
        stakers: bag::Bag,
        users: vector<Staker>,
        total_reward: u64,
    }
    
    public struct StakingLock has store, key {
        id: object::UID,
        amount: u64,
        staking_start_timestamp: u64,
        lock_time: u64,
        last_distribution_timestamp: u64,
    }
    
    public struct AdminCap has key {
        id: object::UID,
    }
    
    public entry fun create_stake<T0>(arg0: &AdminCap, arg1: coin::Coin<T0>, arg3: &mut tx_context::TxContext) {
        let v0 = StakingPool<T0>{
            id                         : object::new(arg3), 
            stake_balance              : coin::into_balance<T0>(arg1), 
            stakers                    : bag::new(arg3), 
            users                      : vector::empty<Staker>(),
            total_reward               : 0, 
        };
        let v1 = CreateStakePoolEvent{staking_pool_id: object::uid_to_inner(&v0.id)};
        event::emit<CreateStakePoolEvent>(v1);
        transfer::public_share_object<StakingPool<T0>>(v0);
    }
    
    public entry fun deposit_stake<T0>(arg0: &AdminCap, arg1: &mut StakingPool<T0>, arg2: coin::Coin<T0>, arg3: &mut tx_context::TxContext) {
        balance::join<T0>(&mut arg1.stake_balance, coin::into_balance<T0>(arg2));
    }

    public fun get_pending_rewards<T0>(arg0: &StakingPool<T0>, user: address, clock: &Clock): u64 {
        assert!(bag::contains<address>(&arg0.stakers, user), 1004);
        let staking_lock = bag::borrow<address, StakingLock>(&arg0.stakers, user);

        let current_timestamp = clock::timestamp_ms(clock);
        let staking_duration_seconds = (current_timestamp - staking_lock.staking_start_timestamp) / 1000;

        // Calculate reward based on duration and rate
        let reward_rate_per_second = 1; // 0.0001% per second as an integer factor
        let pending_rewards = (staking_lock.amount * staking_duration_seconds * reward_rate_per_second) / 1_000_000; // Use integer math

        pending_rewards
    }
    
    // public fun get_staking_projected_balance<T0>(arg0: &StakingPool<T0>, arg1: address, arg2: &clock::Clock) : u64 {
    //     assert!(bag::contains<address>(&arg0.stakers, arg1), 1004);
    //     let v0 = bag::borrow<address, StakingLock>(&arg0.stakers, arg1);
    //     let v1 = clock::timestamp_ms(arg2);
    //     if (v0.lock_time == 0) {
    //         0
    //     } else {
    //         let v3 = if (v0.staking_start_timestamp + v0.lock_time > v1) {
    //             v1 - v0.staking_start_timestamp
    //         } else {
    //             v0.lock_time
    //         };
    //         v0.vesomis * (v0.lock_time - v3) / v0.lock_time
    //     }
    // }
    
    fun init(arg0: &mut tx_context::TxContext) {
        let v0 = AdminCap{id: object::new(arg0)};
        transfer::transfer<AdminCap>(v0, tx_context::sender(arg0));
    }
    
    public entry fun stake<T0>(arg0: &mut StakingPool<T0>, arg2: u64, arg3: coin::Coin<T0>, arg4: &clock::Clock, arg5: &mut tx_context::TxContext) {
        // assert!(arg2 <= 104, 1001);
        let v0 = coin::into_balance<T0>(arg3);
        let v1 = balance::value<T0>(&v0);
        let v4 = StakingLock{
            id                          : object::new(arg5), 
            amount                      : v1, 
            staking_start_timestamp     : clock::timestamp_ms(arg4), 
            lock_time                   : arg2, 
            last_distribution_timestamp : clock::timestamp_ms(arg4),
        };
        balance::join<T0>(&mut arg0.stake_balance, v0);
        let v5 = CreateStakeLockEvent{
            staking_lock_id         : object::uid_to_inner(&v4.id), 
            amount                  : v4.amount, 
            lock_time               : v4.lock_time, 
            staking_start_timestamp : v4.staking_start_timestamp,
        };
        event::emit<CreateStakeLockEvent>(v5);
        bag::add<address, StakingLock>(&mut arg0.stakers, tx_context::sender(arg5), v4);
        let staker = Staker {
        stake_balance: v1,
        user: tx_context::sender(arg5),
        };
        vector::push_back<Staker>(&mut arg0.users, staker);
    }
    
    public entry fun unstake<T0>(arg0: &mut StakingPool<T0>, arg3: &clock::Clock, arg4: &mut tx_context::TxContext) {
        let v0 = bag::remove<address, StakingLock>(&mut arg0.stakers, tx_context::sender(arg4));
        let v1 = clock::timestamp_ms(arg3);
        
        let staking_duration_seconds = (v1 - v0.staking_start_timestamp) / 1000;

    // Calculate reward based on duration and rate
        let reward_rate_per_second = 1; // 0.0001% per second as an integer factor
        let reward_amount = (v0.amount * staking_duration_seconds * reward_rate_per_second) / 1_000_000; // Use integer math

        // Withdraw the staked amount along with the reward
        let mut v4 = coin::take<T0>(&mut arg0.stake_balance, v0.amount, arg4);
        coin::join<T0>(&mut v4, coin::take<T0>(&mut arg0.stake_balance, reward_amount, arg4));
        transfer::public_transfer<coin::Coin<T0>>(v4, tx_context::sender(arg4));
       
        let v5 = WithdrawStakeEvent{
            staking_lock_id : object::uid_to_inner(&v0.id), 
            amount          : v0.amount,
        };
        event::emit<WithdrawStakeEvent>(v5);
        let StakingLock {
            id                          : v6,
            amount                      : _,
            staking_start_timestamp     : _,
            lock_time                   : _,
            last_distribution_timestamp : _,
        } = v0;

        
        
        // Remove staker from the users vector
        let len = vector::length<Staker>(&arg0.users);
        object::delete(v6);
        let mut i = 0;
        while (i < len) {
            let staker = vector::borrow<Staker>(&arg0.users, i);
            if (staker.user == tx_context::sender(arg4)) {
                let staker_removed = vector::swap_remove<Staker>(&mut arg0.users, i);
                let _consumed = staker_removed.stake_balance; // or any other field or use a function to consume it
                event::emit<RemoveStakerEvent>(RemoveStakerEvent{user: staker_removed.user});
                break
            };
            i = i + 1;
        };
        
        
    }
    
    
    public entry fun withdraw_stake<T0>(arg0: &AdminCap, arg1: &mut StakingPool<T0>, arg2: &mut tx_context::TxContext) {
        transfer::public_transfer<coin::Coin<T0>>(coin::from_balance<T0>(balance::withdraw_all<T0>(&mut arg1.stake_balance), arg2), tx_context::sender(arg2));
    }
    
    // decompiled from Move bytecode v6
}
