module staking::staking {
    use sui::object::{Self, ID, UID};
    use sui::event;
    use sui::transfer;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::clock::{Self, Clock};
    use sui::balance::{Self, Balance};

    public struct CreateStakePoolEvent has copy, drop {
        staking_pool_id: object::ID,
    }

    public struct RemoveStakerEvent has copy, drop {
        user: address,
    }
    
    
    public struct ExtendStakeLockEvent has copy, drop {
        staking_lock_id: object::ID,
        amount: u64,
        lock_time: u64,
        staking_start_timestamp: u64,
    }
    
    public struct WithdrawStakeEvent has copy, drop {
        amount: u64,
    }
    
    public struct Staker has store, drop {
        stake_balance: u64,
        user: address,
        staking_start_timestamp: u64,
        last_withdraw_timestamp: u64,
        reward_earned: u64,
    }

    public struct StakingPool<phantom T0> has store, key {
        id: object::UID,
        stake_balance: balance::Balance<T0>,
        users: vector<Staker>,
        total_reward: u64,
    }
    
    public struct AdminCap has key {
        id: object::UID,
    }
    
      
    fun init(arg0: &mut tx_context::TxContext) {
        let v0 = AdminCap{id: object::new(arg0)};
        transfer::transfer<AdminCap>(v0, tx_context::sender(arg0));
    }

    public entry fun create_stake<T0>(arg0: &AdminCap, arg1: coin::Coin<T0>, arg3: &mut tx_context::TxContext) {
        let v0 = StakingPool<T0>{
            id                         : object::new(arg3), 
            stake_balance              : coin::into_balance<T0>(arg1), 
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
        let mut i = 0;
        let len = vector::length<Staker>(&arg0.users);
        
        while (i < len) {
            let staker = vector::borrow<Staker>(&arg0.users, i);
            if (staker.user == user) {
                let current_timestamp = clock::timestamp_ms(clock);
                let staking_duration_seconds = (current_timestamp - staker.last_withdraw_timestamp) / 1000;

                // Calculate reward based on duration and rate
                let reward_rate_per_second = 1; // 0.0001% per second as an integer factor
                let pending_rewards = (staker.stake_balance * staking_duration_seconds * reward_rate_per_second) / 1_000_000; // Use integer math

                return pending_rewards
            };
            i = i + 1
        };
        
        // If user is not found, return 0 rewards.
        0
    }

    public entry fun claim_pending_rewards<T0>(arg0: &mut StakingPool<T0>,arg2: &Clock, arg3: &mut tx_context::TxContext) {
        let rewards = get_pending_rewards(arg0, tx_context::sender(arg3), arg2);
        let reward_coins = coin::take<T0>(&mut arg0.stake_balance, rewards, arg3);
        transfer::public_transfer<coin::Coin<T0>>(reward_coins, tx_context::sender(arg3));

        // Update last_withdraw_timestamp for the user
        let len = vector::length<Staker>(&arg0.users);
        let mut i = 0;
        while (i < len) {
            let staker = vector::borrow_mut<Staker>(&mut arg0.users, i);
            if (staker.user == tx_context::sender(arg3)) {
                staker.last_withdraw_timestamp = clock::timestamp_ms(arg2);
                staker.reward_earned = staker.reward_earned+rewards;
                break
            };
            i = i + 1
        }
    }
  
    
    public entry fun stake<T0>(arg0: &mut StakingPool<T0>, arg2: coin::Coin<T0>, arg3: &clock::Clock, arg4: &mut tx_context::TxContext) {
        let v0 = coin::into_balance<T0>(arg2);
        let v1 = balance::value<T0>(&v0);

        let staker = Staker {
            stake_balance: v1,
            user: tx_context::sender(arg4),
            staking_start_timestamp: clock::timestamp_ms(arg3),
            last_withdraw_timestamp: clock::timestamp_ms(arg3),
            reward_earned: 0,
        };

        balance::join<T0>(&mut arg0.stake_balance, v0);

        vector::push_back<Staker>(&mut arg0.users, staker);
    }
    
    public entry fun unstake<T0>(arg0: &mut StakingPool<T0>, arg3: &clock::Clock, arg4: &mut tx_context::TxContext) {
        let mut i = 0;
        let len = vector::length<Staker>(&arg0.users);
        
        while (i < len) {
            let staker = vector::borrow<Staker>(&arg0.users, i);
            if (staker.user == tx_context::sender(arg4)) {

               let reward_amount = get_pending_rewards(arg0, tx_context::sender(arg4), arg3);

                // Withdraw the staked amount along with the reward
                let mut v4 = coin::take<T0>(&mut arg0.stake_balance, staker.stake_balance, arg4);
                coin::join<T0>(&mut v4, coin::take<T0>(&mut arg0.stake_balance, reward_amount, arg4));
                transfer::public_transfer<coin::Coin<T0>>(v4, tx_context::sender(arg4));

                let v5 = WithdrawStakeEvent{
                    amount          : staker.stake_balance,
                };
                event::emit<WithdrawStakeEvent>(v5);

                // Remove staker from the users vector
                let staker_removed = vector::swap_remove<Staker>(&mut arg0.users, i);
                let _consumed = staker_removed.stake_balance; // or any other field or use a function to consume it
                event::emit<RemoveStakerEvent>(RemoveStakerEvent{user: staker_removed.user});
                break
            };
            i = i + 1
        };
    }

    public entry fun withdraw_stake<T0>(arg0: &AdminCap, arg1: &mut StakingPool<T0>, arg2: &mut tx_context::TxContext) {
        transfer::public_transfer<coin::Coin<T0>>(coin::from_balance<T0>(balance::withdraw_all<T0>(&mut arg1.stake_balance), arg2), tx_context::sender(arg2));
    }
}
