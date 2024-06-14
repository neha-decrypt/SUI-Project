// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// An escrow for atomic swap of objects without a trusted third party
module escrows::escrow {
     use sui::coin::{Self, Coin, TreasuryCap};
    use sui::tx_context::TxContext;
    use sui::object::{Self, ID, UID};
    /// An object held in escrow
    public struct EscrowedObj<COIN> has key, store {
        id: UID,
        /// owner of the escrowed object
        creator: address,
        /// the escrowed object
        escrowed: Option<COIN>,
    }

    // Error codes
    /// An attempt to cancel escrow by a different user than the owner
    const EWrongOwner: u64 = 0;

    /// The escrow has already been exchanged or cancelled
    const EAlreadyExchangedOrCancelled: u64 = 3;

    /// Create an escrow for exchanging goods with counterparty
    public entry fun create<COIN>(
        escrowed_item: Coin<COIN>,
        ctx: &mut TxContext
    ) {
        let creator = ctx.sender();
        let id = object::new(ctx);
        let escrowed = option::some(escrowed_item);
        transfer::public_share_object(
            EscrowedObj{
                id, creator,escrowed
            }
        );
    }


    /// The `creator` can cancel the escrow and get back the escrowed item
    public entry fun cancel<T:key+store>(
        escrow: &mut EscrowedObj<T>,
        ctx: &TxContext
    ) {
        assert!(&ctx.sender() == &escrow.creator, EWrongOwner);
        assert!(option::is_some(&escrow.escrowed), EAlreadyExchangedOrCancelled);
        transfer::public_transfer(option::extract<T>(&mut escrow.escrowed), escrow.creator);
    }
}