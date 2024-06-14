module staking::staking {
    use sui::object::{Self, ID, UID};
    use sui::event;
    use sui::transfer;
    use sui::bag::{Self,Bag,contains};
    use sui::coin::{Self, Coin, TreasuryCap};
    use vesomis::vesomis;
    use sui::clock::{Self, Clock};
    use sui::balance::{Self, Balance};

    public struct CreateStakePoolEvent has copy, drop {
        staking_pool_id: object::ID,
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
    
    public struct StakingPool<phantom T0> has store, key {
        id: object::UID,
        stake_balance: balance::Balance<T0>,
        stakers: bag::Bag,
        total_vesomis: u64,
        total_reward: u64,
        unstake_times_for_fluxtime: u64,
    }
    
    public struct StakingLock has store, key {
        id: object::UID,
        amount: u64,
        weeks: u64,
        staking_start_timestamp: u64,
        lock_time: u64,
        multiplier: u64,
        vesomis: u64,
        last_distribution_timestamp: u64,
    }
    
    public struct AdminCap has key {
        id: object::UID,
    }
    
    // public entry fun change_plan<T0>(arg0: &mut StakingPool<T0>, arg1: &mut vesomis::Supply, arg2: vesomis::VeSomis, arg3:&mut u64, arg4: coin::Coin<T0>, arg5: &clock::Clock, arg6: &mut tx_context::TxContext) {
    //     assert!(arg3 <= 104, 1001);
    //     assert!(bag::contains<address>(&arg0.stakers, tx_context::sender(arg6)), 1004);
    //     let mut v0 = bag::remove<address, StakingLock>(&mut arg0.stakers, tx_context::sender(arg6));
    //     assert!(v0.weeks <= arg3, 1001);
    //     transfer::public_transfer<coin::Coin<T0>>(coin::take<T0>(&mut arg0.stake_balance, ((((v0.amount * v0.multiplier / 10000) as u256) * ((clock::timestamp_ms(arg5) - v0.last_distribution_timestamp) as u256) / (31536000000 as u256)) as u64), arg6), tx_context::sender(arg6));
    //     let v1 =coin::into_balance<T0>(arg4);
    //    balance::join<T0>(&mut arg0.stake_balance, v1);
    //     v0.amount = v0.amount +balance::value<T0>(&v1);
    //     let (v2, v3) = weeks((v0.amount as u256), arg3);
    //     vesomis::join(&mut arg2, vesomis::mint(arg1, v3 - v0.vesomis, arg6));
    //     vesomis::transfer(arg2, arg6);
    //     v0.multiplier = v2;
    //     v0.vesomis = v3;
    //     v0.weeks = arg3;
    //     v0.last_distribution_timestamp =clock::timestamp_ms(arg5);
    //     v0.lock_time = arg3 * 604800000;
    //    bag::add<address, StakingLock>(&mut arg0.stakers,tx_context::sender(arg6), v0);
    // }
    
    public entry fun change_stake<T0>(arg0: &AdminCap, arg1: &mut StakingPool<T0>, arg2: u64, arg3: &mut tx_context::TxContext) {
        arg1.unstake_times_for_fluxtime = arg2;
    }
    
    public entry fun create_stake<T0>(arg0: &AdminCap, arg1: coin::Coin<T0>, arg2: u64, arg3: &mut tx_context::TxContext) {
        let v0 = StakingPool<T0>{
            id                         : object::new(arg3), 
            stake_balance              : coin::into_balance<T0>(arg1), 
            stakers                    : bag::new(arg3), 
            total_vesomis              : 0, 
            total_reward               : 0, 
            unstake_times_for_fluxtime : arg2,
        };
        let v1 = CreateStakePoolEvent{staking_pool_id: object::uid_to_inner(&v0.id)};
        event::emit<CreateStakePoolEvent>(v1);
        transfer::public_share_object<StakingPool<T0>>(v0);
    }
    
    public entry fun deposit_stake<T0>(arg0: &AdminCap, arg1: &mut StakingPool<T0>, arg2: coin::Coin<T0>, arg3: &mut tx_context::TxContext) {
        balance::join<T0>(&mut arg1.stake_balance, coin::into_balance<T0>(arg2));
    }
    
    public fun get_stake_lock<T0>(arg0: &StakingPool<T0>, arg1: address) : &StakingLock {
        assert!(bag::contains<address>(&arg0.stakers, arg1), 1004);
        bag::borrow<address, StakingLock>(&arg0.stakers, arg1)
    }
    
    public fun get_staking_projected_balance<T0>(arg0: &StakingPool<T0>, arg1: address, arg2: &clock::Clock) : u64 {
        assert!(bag::contains<address>(&arg0.stakers, arg1), 1004);
        let v0 = bag::borrow<address, StakingLock>(&arg0.stakers, arg1);
        let v1 = clock::timestamp_ms(arg2);
        if (v0.lock_time == 0) {
            0
        } else {
            let v3 = if (v0.staking_start_timestamp + v0.lock_time > v1) {
                v1 - v0.staking_start_timestamp
            } else {
                v0.lock_time
            };
            v0.vesomis * (v0.lock_time - v3) / v0.lock_time
        }
    }
    
    fun init(arg0: &mut tx_context::TxContext) {
        let v0 = AdminCap{id: object::new(arg0)};
        transfer::transfer<AdminCap>(v0, tx_context::sender(arg0));
    }
    
    public entry fun stake<T0>(arg0: &mut StakingPool<T0>, arg1: &mut vesomis::Supply, arg2: u64, arg3: coin::Coin<T0>, arg4: &clock::Clock, arg5: &mut tx_context::TxContext) {
        // assert!(arg2 <= 104, 1001);
        let v0 = coin::into_balance<T0>(arg3);
        let v1 = balance::value<T0>(&v0);
        let (v2, v3) = weeks((v1 as u256), arg2);
        let v4 = StakingLock{
            id                          : object::new(arg5), 
            amount                      : v1, 
            weeks                       : arg2, 
            staking_start_timestamp     : clock::timestamp_ms(arg4), 
            lock_time                   : arg2, 
            multiplier                  : v2, 
            vesomis                     : v3, 
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
        vesomis::transfer(vesomis::mint(arg1, v3, arg5), arg5);
        bag::add<address, StakingLock>(&mut arg0.stakers, tx_context::sender(arg5), v4);
    }
    
    public entry fun unstake<T0>(arg0: &mut StakingPool<T0>, arg1: &mut vesomis::Supply, arg2: vesomis::VeSomis, arg3: &clock::Clock, arg4: &mut tx_context::TxContext) {
        let v0 = bag::remove<address, StakingLock>(&mut arg0.stakers, tx_context::sender(arg4));
        let v1 = if (v0.weeks == 0) {
            assert!(v0.staking_start_timestamp + v0.lock_time <= clock::timestamp_ms(arg3), 1002);
            clock::timestamp_ms(arg3)
        } else {
            let v2 = v0.staking_start_timestamp + v0.lock_time;
            assert!(v2 <= clock::timestamp_ms(arg3), 1002);
            v2
        };
        let v3 = v0.amount;
        let mut v4 = coin::take<T0>(&mut arg0.stake_balance, v0.amount, arg4);
        coin::join<T0>(&mut v4, coin::take<T0>(&mut arg0.stake_balance, ((((v3 * v0.multiplier / 10000) as u256) * ((v1 - v0.last_distribution_timestamp) as u256) / (31536000000 as u256)) as u64), arg4));
        transfer::public_transfer<coin::Coin<T0>>(v4, tx_context::sender(arg4));
        assert!(vesomis::amount(&arg2) >= v0.vesomis, 1003);
        vesomis::burn(arg1, arg2, arg4);
        let v5 = WithdrawStakeEvent{
            staking_lock_id : object::uid_to_inner(&v0.id), 
            amount          : v3,
        };
        event::emit<WithdrawStakeEvent>(v5);
        let StakingLock {
            id                          : v6,
            amount                      : _,
            weeks                       : _,
            staking_start_timestamp     : _,
            lock_time                   : _,
            multiplier                  : _,
            vesomis                     : _,
            last_distribution_timestamp : _,
        } = v0;
        object::delete(v6);
    }
    
    public fun weeks(arg0: u256, arg1: u64) : (u64, u64) {
        let (v0, v1) = if (arg1 == 0) {
            (100 * 1, arg0 * 40 * 10000)
        } else {
            let (v2, v3) = if (arg1 == 1) {
                (143 * 1, arg0 * 70 * 10000)
            } else {
                let (v4, v5) = if (arg1 == 2) {
                    (182 * 1, arg0 * 80 * 10000)
                } else {
                    let (v6, v7) = if (arg1 == 3) {
                        (222 * 1, arg0 * 100 * 10000)
                    } else {
                        let (v8, v9) = if (arg1 == 4) {
                            (261 * 1, arg0 * 120 * 10000)
                        } else {
                            let (v10, v11) = if (arg1 == 5) {
                                (301 * 1, arg0 * 140 * 10000)
                            } else {
                                let (v12, v13) = if (arg1 == 6) {
                                    (340 * 1, arg0 * 160 * 10000)
                                } else {
                                    let (v14, v15) = if (arg1 == 7) {
                                        (380 * 1, arg0 * 180 * 10000)
                                    } else {
                                        let (v16, v17) = if (arg1 == 8) {
                                            (419 * 1, arg0 * 190 * 10000)
                                        } else {
                                            let (v18, v19) = if (arg1 == 9) {
                                                (459 * 1, arg0 * 210 * 10000)
                                            } else {
                                                let (v20, v21) = if (arg1 == 10) {
                                                    (499 * 1, arg0 * 230 * 10000)
                                                } else {
                                                    let (v22, v23) = if (arg1 == 11) {
                                                        (538 * 1, arg0 * 250 * 10000)
                                                    } else {
                                                        let (v24, v25) = if (arg1 == 12) {
                                                            (578 * 1, arg0 * 270 * 10000)
                                                        } else {
                                                            let (v26, v27) = if (arg1 == 13) {
                                                                (617 * 1, arg0 * 290 * 10000)
                                                            } else {
                                                                let (v28, v29) = if (arg1 == 14) {
                                                                    (657 * 1, arg0 * 300 * 10000)
                                                                } else {
                                                                    let (v30, v31) = if (arg1 == 15) {
                                                                        (696 * 1, arg0 * 320 * 10000)
                                                                    } else {
                                                                        let (v32, v33) = if (arg1 == 16) {
                                                                            (736 * 1, arg0 * 340 * 10000)
                                                                        } else {
                                                                            let (v34, v35) = if (arg1 == 17) {
                                                                                (775 * 1, arg0 * 360 * 10000)
                                                                            } else {
                                                                                let (v36, v37) = if (arg1 == 18) {
                                                                                    (815 * 1, arg0 * 380 * 10000)
                                                                                } else {
                                                                                    let (v38, v39) = if (arg1 == 19) {
                                                                                        (854 * 1, arg0 * 400 * 10000)
                                                                                    } else {
                                                                                        let (v40, v41) = if (arg1 == 20) {
                                                                                            (894 * 1, arg0 * 410 * 10000)
                                                                                        } else {
                                                                                            let (v42, v43) = if (arg1 == 21) {
                                                                                                (933 * 1, arg0 * 430 * 10000)
                                                                                            } else {
                                                                                                let (v44, v45) = if (arg1 == 22) {
                                                                                                    (973 * 1, arg0 * 450 * 10000)
                                                                                                } else {
                                                                                                    let (v46, v47) = if (arg1 == 23) {
                                                                                                        (1013 * 1, arg0 * 470 * 10000)
                                                                                                    } else {
                                                                                                        let (v48, v49) = if (arg1 == 24) {
                                                                                                            (1052 * 1, arg0 * 490 * 10000)
                                                                                                        } else {
                                                                                                            let (v50, v51) = if (arg1 == 25) {
                                                                                                                (1092 * 1, arg0 * 510 * 10000)
                                                                                                            } else {
                                                                                                                let (v52, v53) = if (arg1 == 26) {
                                                                                                                    (1131 * 1, arg0 * 520 * 10000)
                                                                                                                } else {
                                                                                                                    let (v54, v55) = if (arg1 == 27) {
                                                                                                                        (1171 * 1, arg0 * 540 * 10000)
                                                                                                                    } else {
                                                                                                                        let (v56, v57) = if (arg1 == 28) {
                                                                                                                            (1201 * 1, arg0 * 560 * 10000)
                                                                                                                        } else {
                                                                                                                            let (v58, v59) = if (arg1 == 29) {
                                                                                                                                (1250 * 1, arg0 * 580 * 10000)
                                                                                                                            } else {
                                                                                                                                let (v60, v61) = if (arg1 == 30) {
                                                                                                                                    (1289 * 1, arg0 * 600 * 10000)
                                                                                                                                } else {
                                                                                                                                    let (v62, v63) = if (arg1 == 31) {
                                                                                                                                        (1329 * 1, arg0 * 610 * 10000)
                                                                                                                                    } else {
                                                                                                                                        let (v64, v65) = if (arg1 == 32) {
                                                                                                                                            (1368 * 1, arg0 * 630 * 10000)
                                                                                                                                        } else {
                                                                                                                                            let (v66, v67) = if (arg1 == 33) {
                                                                                                                                                (1408 * 1, arg0 * 650 * 10000)
                                                                                                                                            } else {
                                                                                                                                                let (v68, v69) = if (arg1 == 34) {
                                                                                                                                                    (1448 * 1, arg0 * 670 * 10000)
                                                                                                                                                } else {
                                                                                                                                                    let (v70, v71) = if (arg1 == 35) {
                                                                                                                                                        (1487 * 1, arg0 * 690 * 10000)
                                                                                                                                                    } else {
                                                                                                                                                        let (v72, v73) = if (arg1 == 36) {
                                                                                                                                                            (1527 * 1, arg0 * 710 * 10000)
                                                                                                                                                        } else {
                                                                                                                                                            let (v74, v75) = if (arg1 == 37) {
                                                                                                                                                                (1566 * 1, arg0 * 730 * 10000)
                                                                                                                                                            } else {
                                                                                                                                                                let (v76, v77) = if (arg1 == 38) {
                                                                                                                                                                    (1606 * 1, arg0 * 740 * 10000)
                                                                                                                                                                } else {
                                                                                                                                                                    let (v78, v79) = if (arg1 == 39) {
                                                                                                                                                                        (1645 * 1, arg0 * 760 * 10000)
                                                                                                                                                                    } else {
                                                                                                                                                                        let (v80, v81) = if (arg1 == 40) {
                                                                                                                                                                            (1685 * 1, arg0 * 780 * 10000)
                                                                                                                                                                        } else {
                                                                                                                                                                            let (v82, v83) = if (arg1 == 41) {
                                                                                                                                                                                (1724 * 1, arg0 * 800 * 10000)
                                                                                                                                                                            } else {
                                                                                                                                                                                let (v84, v85) = if (arg1 == 42) {
                                                                                                                                                                                    (1764 * 1, arg0 * 820 * 10000)
                                                                                                                                                                                } else {
                                                                                                                                                                                    let (v86, v87) = if (arg1 == 43) {
                                                                                                                                                                                        (1803 * 1, arg0 * 840 * 10000)
                                                                                                                                                                                    } else {
                                                                                                                                                                                        let (v88, v89) = if (arg1 == 44) {
                                                                                                                                                                                            (1843 * 1, arg0 * 850 * 10000)
                                                                                                                                                                                        } else {
                                                                                                                                                                                            let (v90, v91) = if (arg1 == 45) {
                                                                                                                                                                                                (1883 * 1, arg0 * 870 * 10000)
                                                                                                                                                                                            } else {
                                                                                                                                                                                                let (v92, v93) = if (arg1 == 46) {
                                                                                                                                                                                                    (1922 * 1, arg0 * 890 * 10000)
                                                                                                                                                                                                } else {
                                                                                                                                                                                                    let (v94, v95) = if (arg1 == 47) {
                                                                                                                                                                                                        (1962 * 1, arg0 * 910 * 10000)
                                                                                                                                                                                                    } else {
                                                                                                                                                                                                        let (v96, v97) = if (arg1 == 48) {
                                                                                                                                                                                                            (2001 * 1, arg0 * 930 * 10000)
                                                                                                                                                                                                        } else {
                                                                                                                                                                                                            let (v98, v99) = if (arg1 == 49) {
                                                                                                                                                                                                                (2041 * 1, arg0 * 950 * 10000)
                                                                                                                                                                                                            } else {
                                                                                                                                                                                                                let (v100, v101) = if (arg1 == 50) {
                                                                                                                                                                                                                    (2080 * 1, arg0 * 960 * 10000)
                                                                                                                                                                                                                } else {
                                                                                                                                                                                                                    let (v102, v103) = if (arg1 == 51) {
                                                                                                                                                                                                                        (2102 * 1, arg0 * 980 * 10000)
                                                                                                                                                                                                                    } else {
                                                                                                                                                                                                                        let (v104, v105) = if (arg1 == 52) {
                                                                                                                                                                                                                            (2159 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                        } else {
                                                                                                                                                                                                                            let (v106, v107) = if (arg1 == 53) {
                                                                                                                                                                                                                                (2173 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                            } else {
                                                                                                                                                                                                                                let (v108, v109) = if (arg1 == 54) {
                                                                                                                                                                                                                                    (arg0 * 1000 * 10000, 2187 * 1)
                                                                                                                                                                                                                                } else {
                                                                                                                                                                                                                                    let (v110, v111) = if (arg1 == 55) {
                                                                                                                                                                                                                                        (2201 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                    } else {
                                                                                                                                                                                                                                        let (v112, v113) = if (arg1 == 56) {
                                                                                                                                                                                                                                            (2215 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                        } else {
                                                                                                                                                                                                                                            let (v114, v115) = if (arg1 == 57) {
                                                                                                                                                                                                                                                (2229 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                            } else {
                                                                                                                                                                                                                                                let (v116, v117) = if (arg1 == 58) {
                                                                                                                                                                                                                                                    (2243 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                } else {
                                                                                                                                                                                                                                                    let (v118, v119) = if (arg1 == 59) {
                                                                                                                                                                                                                                                        (2257 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                    } else {
                                                                                                                                                                                                                                                        let (v120, v121) = if (arg1 == 60) {
                                                                                                                                                                                                                                                            (2271 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                        } else {
                                                                                                                                                                                                                                                            let (v122, v123) = if (arg1 == 61) {
                                                                                                                                                                                                                                                                (2285 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                            } else {
                                                                                                                                                                                                                                                                let (v124, v125) = if (arg1 == 62) {
                                                                                                                                                                                                                                                                    (2299 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                } else {
                                                                                                                                                                                                                                                                    let (v126, v127) = if (arg1 == 63) {
                                                                                                                                                                                                                                                                        (2313 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                    } else {
                                                                                                                                                                                                                                                                        let (v128, v129) = if (arg1 == 64) {
                                                                                                                                                                                                                                                                            (2327 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                        } else {
                                                                                                                                                                                                                                                                            let (v130, v131) = if (arg1 == 65) {
                                                                                                                                                                                                                                                                                (2340 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                            } else {
                                                                                                                                                                                                                                                                                let (v132, v133) = if (arg1 == 66) {
                                                                                                                                                                                                                                                                                    (2354 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                } else {
                                                                                                                                                                                                                                                                                    let (v134, v135) = if (arg1 == 67) {
                                                                                                                                                                                                                                                                                        (2368 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                    } else {
                                                                                                                                                                                                                                                                                        let (v136, v137) = if (arg1 == 68) {
                                                                                                                                                                                                                                                                                            (2382 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                        } else {
                                                                                                                                                                                                                                                                                            let (v138, v139) = if (arg1 == 69) {
                                                                                                                                                                                                                                                                                                (2396 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                            } else {
                                                                                                                                                                                                                                                                                                let (v140, v141) = if (arg1 == 70) {
                                                                                                                                                                                                                                                                                                    (2410 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                } else {
                                                                                                                                                                                                                                                                                                    let (v142, v143) = if (arg1 == 71) {
                                                                                                                                                                                                                                                                                                        (2424 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                    } else {
                                                                                                                                                                                                                                                                                                        let (v144, v145) = if (arg1 == 72) {
                                                                                                                                                                                                                                                                                                            (2438 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                        } else {
                                                                                                                                                                                                                                                                                                            let (v146, v147) = if (arg1 == 73) {
                                                                                                                                                                                                                                                                                                                (2452 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                            } else {
                                                                                                                                                                                                                                                                                                                let (v148, v149) = if (arg1 == 74) {
                                                                                                                                                                                                                                                                                                                    (2466 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                } else {
                                                                                                                                                                                                                                                                                                                    let (v150, v151) = if (arg1 == 75) {
                                                                                                                                                                                                                                                                                                                        (2480 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                    } else {
                                                                                                                                                                                                                                                                                                                        let (v152, v153) = if (arg1 == 76) {
                                                                                                                                                                                                                                                                                                                            (2494 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                        } else {
                                                                                                                                                                                                                                                                                                                            let (v154, v155) = if (arg1 == 77) {
                                                                                                                                                                                                                                                                                                                                (2508 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                            } else {
                                                                                                                                                                                                                                                                                                                                let (v156, v157) = if (arg1 == 78) {
                                                                                                                                                                                                                                                                                                                                    (2522 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                } else {
                                                                                                                                                                                                                                                                                                                                    let (v158, v159) = if (arg1 == 79) {
                                                                                                                                                                                                                                                                                                                                        (2536 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                    } else {
                                                                                                                                                                                                                                                                                                                                        let (v160, v161) = if (arg1 == 80) {
                                                                                                                                                                                                                                                                                                                                            (2550 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                        } else {
                                                                                                                                                                                                                                                                                                                                            let (v162, v163) = if (arg1 == 81) {
                                                                                                                                                                                                                                                                                                                                                (2564 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                            } else {
                                                                                                                                                                                                                                                                                                                                                let (v164, v165) = if (arg1 == 82) {
                                                                                                                                                                                                                                                                                                                                                    (2578 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                } else {
                                                                                                                                                                                                                                                                                                                                                    let (v166, v167) = if (arg1 == 83) {
                                                                                                                                                                                                                                                                                                                                                        (2592 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                    } else {
                                                                                                                                                                                                                                                                                                                                                        let (v168, v169) = if (arg1 == 84) {
                                                                                                                                                                                                                                                                                                                                                            (2606 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                        } else {
                                                                                                                                                                                                                                                                                                                                                            let (v170, v171) = if (arg1 == 85) {
                                                                                                                                                                                                                                                                                                                                                                (2620 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                            } else {
                                                                                                                                                                                                                                                                                                                                                                let (v172, v173) = if (arg1 == 86) {
                                                                                                                                                                                                                                                                                                                                                                    (2634 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                                } else {
                                                                                                                                                                                                                                                                                                                                                                    let (v174, v175) = if (arg1 == 87) {
                                                                                                                                                                                                                                                                                                                                                                        (2648 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                                    } else {
                                                                                                                                                                                                                                                                                                                                                                        let (v176, v177) = if (arg1 == 88) {
                                                                                                                                                                                                                                                                                                                                                                            (2662 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                                        } else {
                                                                                                                                                                                                                                                                                                                                                                            let (v178, v179) = if (arg1 == 89) {
                                                                                                                                                                                                                                                                                                                                                                                (2676 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                                            } else {
                                                                                                                                                                                                                                                                                                                                                                                let (v180, v181) = if (arg1 == 90) {
                                                                                                                                                                                                                                                                                                                                                                                    (2690 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                                                } else {
                                                                                                                                                                                                                                                                                                                                                                                    let (v182, v183) = if (arg1 == 91) {
                                                                                                                                                                                                                                                                                                                                                                                        (2703 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                                                    } else {
                                                                                                                                                                                                                                                                                                                                                                                        let (v184, v185) = if (arg1 == 92) {
                                                                                                                                                                                                                                                                                                                                                                                            (2717 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                                                        } else {
                                                                                                                                                                                                                                                                                                                                                                                            let (v186, v187) = if (arg1 == 93) {
                                                                                                                                                                                                                                                                                                                                                                                                (2731 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                                                            } else {
                                                                                                                                                                                                                                                                                                                                                                                                let (v188, v189) = if (arg1 == 94) {
                                                                                                                                                                                                                                                                                                                                                                                                    (2745 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                                                                } else {
                                                                                                                                                                                                                                                                                                                                                                                                    let (v190, v191) = if (arg1 == 95) {
                                                                                                                                                                                                                                                                                                                                                                                                        (2759 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                                                                    } else {
                                                                                                                                                                                                                                                                                                                                                                                                        let (v192, v193) = if (arg1 == 96) {
                                                                                                                                                                                                                                                                                                                                                                                                            (2773 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                                                                        } else {
                                                                                                                                                                                                                                                                                                                                                                                                            let (v194, v195) = if (arg1 == 97) {
                                                                                                                                                                                                                                                                                                                                                                                                                (2787 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                                                                            } else {
                                                                                                                                                                                                                                                                                                                                                                                                                let (v196, v197) = if (arg1 == 98) {
                                                                                                                                                                                                                                                                                                                                                                                                                    (2801 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                                                                                } else {
                                                                                                                                                                                                                                                                                                                                                                                                                    let (v198, v199) = if (arg1 == 99) {
                                                                                                                                                                                                                                                                                                                                                                                                                        (arg0 * 1000 * 10000, 2815 * 1)
                                                                                                                                                                                                                                                                                                                                                                                                                    } else {
                                                                                                                                                                                                                                                                                                                                                                                                                        let (v200, v201) = if (arg1 == 100) {
                                                                                                                                                                                                                                                                                                                                                                                                                            (2829 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                                                                                        } else {
                                                                                                                                                                                                                                                                                                                                                                                                                            let (v202, v203) = if (arg1 == 101) {
                                                                                                                                                                                                                                                                                                                                                                                                                                (2843 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                                                                                            } else {
                                                                                                                                                                                                                                                                                                                                                                                                                                let (v204, v205) = if (arg1 == 102) {
                                                                                                                                                                                                                                                                                                                                                                                                                                    (2857 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                                                                                                } else {
                                                                                                                                                                                                                                                                                                                                                                                                                                    let (v206, v207) = if (arg1 == 103) {
                                                                                                                                                                                                                                                                                                                                                                                                                                        (2871 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                                                                                                    } else {
                                                                                                                                                                                                                                                                                                                                                                                                                                        (2885 * 1, arg0 * 1000 * 10000)
                                                                                                                                                                                                                                                                                                                                                                                                                                    };
                                                                                                                                                                                                                                                                                                                                                                                                                                    (v206, v207)
                                                                                                                                                                                                                                                                                                                                                                                                                                };
                                                                                                                                                                                                                                                                                                                                                                                                                                (v204, v205)
                                                                                                                                                                                                                                                                                                                                                                                                                            };
                                                                                                                                                                                                                                                                                                                                                                                                                            (v202, v203)
                                                                                                                                                                                                                                                                                                                                                                                                                        };
                                                                                                                                                                                                                                                                                                                                                                                                                        (v201, v200)
                                                                                                                                                                                                                                                                                                                                                                                                                    };
                                                                                                                                                                                                                                                                                                                                                                                                                    (v199, v198)
                                                                                                                                                                                                                                                                                                                                                                                                                };
                                                                                                                                                                                                                                                                                                                                                                                                                (v196, v197)
                                                                                                                                                                                                                                                                                                                                                                                                            };
                                                                                                                                                                                                                                                                                                                                                                                                            (v194, v195)
                                                                                                                                                                                                                                                                                                                                                                                                        };
                                                                                                                                                                                                                                                                                                                                                                                                        (v192, v193)
                                                                                                                                                                                                                                                                                                                                                                                                    };
                                                                                                                                                                                                                                                                                                                                                                                                    (v190, v191)
                                                                                                                                                                                                                                                                                                                                                                                                };
                                                                                                                                                                                                                                                                                                                                                                                                (v188, v189)
                                                                                                                                                                                                                                                                                                                                                                                            };
                                                                                                                                                                                                                                                                                                                                                                                            (v186, v187)
                                                                                                                                                                                                                                                                                                                                                                                        };
                                                                                                                                                                                                                                                                                                                                                                                        (v184, v185)
                                                                                                                                                                                                                                                                                                                                                                                    };
                                                                                                                                                                                                                                                                                                                                                                                    (v182, v183)
                                                                                                                                                                                                                                                                                                                                                                                };
                                                                                                                                                                                                                                                                                                                                                                                (v180, v181)
                                                                                                                                                                                                                                                                                                                                                                            };
                                                                                                                                                                                                                                                                                                                                                                            (v178, v179)
                                                                                                                                                                                                                                                                                                                                                                        };
                                                                                                                                                                                                                                                                                                                                                                        (v176, v177)
                                                                                                                                                                                                                                                                                                                                                                    };
                                                                                                                                                                                                                                                                                                                                                                    (v174, v175)
                                                                                                                                                                                                                                                                                                                                                                };
                                                                                                                                                                                                                                                                                                                                                                (v172, v173)
                                                                                                                                                                                                                                                                                                                                                            };
                                                                                                                                                                                                                                                                                                                                                            (v170, v171)
                                                                                                                                                                                                                                                                                                                                                        };
                                                                                                                                                                                                                                                                                                                                                        (v168, v169)
                                                                                                                                                                                                                                                                                                                                                    };
                                                                                                                                                                                                                                                                                                                                                    (v166, v167)
                                                                                                                                                                                                                                                                                                                                                };
                                                                                                                                                                                                                                                                                                                                                (v164, v165)
                                                                                                                                                                                                                                                                                                                                            };
                                                                                                                                                                                                                                                                                                                                            (v162, v163)
                                                                                                                                                                                                                                                                                                                                        };
                                                                                                                                                                                                                                                                                                                                        (v160, v161)
                                                                                                                                                                                                                                                                                                                                    };
                                                                                                                                                                                                                                                                                                                                    (v158, v159)
                                                                                                                                                                                                                                                                                                                                };
                                                                                                                                                                                                                                                                                                                                (v156, v157)
                                                                                                                                                                                                                                                                                                                            };
                                                                                                                                                                                                                                                                                                                            (v154, v155)
                                                                                                                                                                                                                                                                                                                        };
                                                                                                                                                                                                                                                                                                                        (v152, v153)
                                                                                                                                                                                                                                                                                                                    };
                                                                                                                                                                                                                                                                                                                    (v150, v151)
                                                                                                                                                                                                                                                                                                                };
                                                                                                                                                                                                                                                                                                                (v148, v149)
                                                                                                                                                                                                                                                                                                            };
                                                                                                                                                                                                                                                                                                            (v146, v147)
                                                                                                                                                                                                                                                                                                        };
                                                                                                                                                                                                                                                                                                        (v144, v145)
                                                                                                                                                                                                                                                                                                    };
                                                                                                                                                                                                                                                                                                    (v142, v143)
                                                                                                                                                                                                                                                                                                };
                                                                                                                                                                                                                                                                                                (v140, v141)
                                                                                                                                                                                                                                                                                            };
                                                                                                                                                                                                                                                                                            (v138, v139)
                                                                                                                                                                                                                                                                                        };
                                                                                                                                                                                                                                                                                        (v136, v137)
                                                                                                                                                                                                                                                                                    };
                                                                                                                                                                                                                                                                                    (v134, v135)
                                                                                                                                                                                                                                                                                };
                                                                                                                                                                                                                                                                                (v132, v133)
                                                                                                                                                                                                                                                                            };
                                                                                                                                                                                                                                                                            (v130, v131)
                                                                                                                                                                                                                                                                        };
                                                                                                                                                                                                                                                                        (v128, v129)
                                                                                                                                                                                                                                                                    };
                                                                                                                                                                                                                                                                    (v126, v127)
                                                                                                                                                                                                                                                                };
                                                                                                                                                                                                                                                                (v124, v125)
                                                                                                                                                                                                                                                            };
                                                                                                                                                                                                                                                            (v122, v123)
                                                                                                                                                                                                                                                        };
                                                                                                                                                                                                                                                        (v120, v121)
                                                                                                                                                                                                                                                    };
                                                                                                                                                                                                                                                    (v118, v119)
                                                                                                                                                                                                                                                };
                                                                                                                                                                                                                                                (v116, v117)
                                                                                                                                                                                                                                            };
                                                                                                                                                                                                                                            (v114, v115)
                                                                                                                                                                                                                                        };
                                                                                                                                                                                                                                        (v112, v113)
                                                                                                                                                                                                                                    };
                                                                                                                                                                                                                                    (v111, v110)
                                                                                                                                                                                                                                };
                                                                                                                                                                                                                                (v109, v108)
                                                                                                                                                                                                                            };
                                                                                                                                                                                                                            (v106, v107)
                                                                                                                                                                                                                        };
                                                                                                                                                                                                                        (v104, v105)
                                                                                                                                                                                                                    };
                                                                                                                                                                                                                    (v102, v103)
                                                                                                                                                                                                                };
                                                                                                                                                                                                                (v100, v101)
                                                                                                                                                                                                            };
                                                                                                                                                                                                            (v98, v99)
                                                                                                                                                                                                        };
                                                                                                                                                                                                        (v96, v97)
                                                                                                                                                                                                    };
                                                                                                                                                                                                    (v94, v95)
                                                                                                                                                                                                };
                                                                                                                                                                                                (v92, v93)
                                                                                                                                                                                            };
                                                                                                                                                                                            (v90, v91)
                                                                                                                                                                                        };
                                                                                                                                                                                        (v88, v89)
                                                                                                                                                                                    };
                                                                                                                                                                                    (v86, v87)
                                                                                                                                                                                };
                                                                                                                                                                                (v84, v85)
                                                                                                                                                                            };
                                                                                                                                                                            (v82, v83)
                                                                                                                                                                        };
                                                                                                                                                                        (v80, v81)
                                                                                                                                                                    };
                                                                                                                                                                    (v78, v79)
                                                                                                                                                                };
                                                                                                                                                                (v76, v77)
                                                                                                                                                            };
                                                                                                                                                            (v74, v75)
                                                                                                                                                        };
                                                                                                                                                        (v72, v73)
                                                                                                                                                    };
                                                                                                                                                    (v70, v71)
                                                                                                                                                };
                                                                                                                                                (v68, v69)
                                                                                                                                            };
                                                                                                                                            (v66, v67)
                                                                                                                                        };
                                                                                                                                        (v64, v65)
                                                                                                                                    };
                                                                                                                                    (v62, v63)
                                                                                                                                };
                                                                                                                                (v60, v61)
                                                                                                                            };
                                                                                                                            (v58, v59)
                                                                                                                        };
                                                                                                                        (v56, v57)
                                                                                                                    };
                                                                                                                    (v54, v55)
                                                                                                                };
                                                                                                                (v52, v53)
                                                                                                            };
                                                                                                            (v50, v51)
                                                                                                        };
                                                                                                        (v48, v49)
                                                                                                    };
                                                                                                    (v46, v47)
                                                                                                };
                                                                                                (v44, v45)
                                                                                            };
                                                                                            (v42, v43)
                                                                                        };
                                                                                        (v40, v41)
                                                                                    };
                                                                                    (v38, v39)
                                                                                };
                                                                                (v36, v37)
                                                                            };
                                                                            (v34, v35)
                                                                        };
                                                                        (v32, v33)
                                                                    };
                                                                    (v30, v31)
                                                                };
                                                                (v28, v29)
                                                            };
                                                            (v26, v27)
                                                        };
                                                        (v24, v25)
                                                    };
                                                    (v22, v23)
                                                };
                                                (v20, v21)
                                            };
                                            (v18, v19)
                                        };
                                        (v16, v17)
                                    };
                                    (v14, v15)
                                };
                                (v12, v13)
                            };
                            (v10, v11)
                        };
                        (v8, v9)
                    };
                    (v6, v7)
                };
                (v4, v5)
            };
            (v2, v3)
        };
        (v0, ((v1 / 1000 / 10000) as u64))
    }
    
    public entry fun withdraw_stake<T0>(arg0: &AdminCap, arg1: &mut StakingPool<T0>, arg2: &mut tx_context::TxContext) {
        transfer::public_transfer<coin::Coin<T0>>(coin::from_balance<T0>(balance::withdraw_all<T0>(&mut arg1.stake_balance), arg2), tx_context::sender(arg2));
    }
    
    // decompiled from Move bytecode v6
}

