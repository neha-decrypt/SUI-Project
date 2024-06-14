module metaschool::NENE {
    use std::option;
    use sui::coin;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::pay;
    
    // Name matches the module name, but in UPPERCASE
    public struct NENE has drop {}
    const ENoCoins: u64 = 0;

    // Module initializer is called once on module publish.
    // A treasury cap is sent to the publisher, who then controls minting and burning.
    fun init(witness: NENE, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 9, b"NE", b"NENE", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }

    public entry fun mint(
        treasury: &mut coin::TreasuryCap<NENE>, amount: u64, recipient: address, ctx: &mut TxContext
    ) {
        coin::mint_and_transfer(treasury, amount, recipient, ctx);
    }

    public entry fun transfer(mut coins: vector<coin::Coin<NENE>>, amount: u64, recipient: address, ctx: &mut TxContext) {
        assert!(vector::length(&coins) > 0, ENoCoins);
        let mut coin = vector::pop_back(&mut coins);
        pay::join_vec(&mut coin, coins);
        pay::split_and_transfer(&mut coin, amount, recipient, ctx);
        transfer::public_transfer(coin, tx_context::sender(ctx))
    }
}
