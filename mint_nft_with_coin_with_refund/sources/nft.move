module nfts::nft {
    use std::string::{utf8, String};
    use sui::url::{Self, Url};
    use sui::object::{Self, ID, UID};
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::package;
    use sui::display;
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::tx_context::{sender};
    use sui::coin::{Self, Coin, TreasuryCap};

    public struct PEPE has drop {}

    // Define struct of NFT
    public struct NFT has drop {}

    public struct AtomNFT has key, store {
        id: UID,
        name: String,
        description: String,
        image_url: Url,
    }

    public struct MintNFTEvent has copy, drop {
        object_id: ID,
        creator: address,
        name: String,
    }

    // Define the cost of minting an NFT in the fungible token
    const MINT_COST: u64 = 10000000000; // Example cost; adjust as needed

    fun init(otw: NFT, ctx: &mut TxContext) {
        let keys = vector[
            utf8(b"name"),
            utf8(b"image_url"),
            utf8(b"description"),
            utf8(b"project_url"),
            utf8(b"creator"),
        ];

        let values = vector [
            utf8(b"{name}"),
            utf8(b"{image_url}"),
            utf8(b"{description}"),
            utf8(b"https://artify.vertiree.com/"),
            utf8(b"Artify")
        ];
        
        // Claim publisher for package
        let publisher = package::claim(otw, ctx);

        // Get new Display object for AtomNFT type
        let mut display = display::new_with_fields<AtomNFT>(
            &publisher, keys, values, ctx
        );

        // Commit first version of Display to apply changes
        display::update_version(&mut display);

        let owner = tx_context::sender(ctx);
        transfer::public_transfer(publisher, owner);
        transfer::public_transfer(display, owner);
    }

    // Public entry function to mint NFT with payment requirement
    public entry fun mint<COIN>(
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        mut payment: Coin<COIN>, // Payment in the fungible token
        ctx: &mut TxContext
    ) {
        // Verify the payment amount
        let balance = coin::value(&payment);
        assert!(balance >= MINT_COST, 1); // Error code 1: Insufficient payment
      
        // Transfer the payment to the contract owner or a treasury address
        let treasury_address = @0xfb624d465f6b9a43f80d4321d3705ad898e61c812567e3591abcccf932216828;
        let sender = tx_context::sender(ctx);
        
        let remaining_coin = coin::split(&mut payment, MINT_COST, ctx);
        transfer::public_transfer(payment, treasury_address);
        transfer::public_transfer(remaining_coin, sender);
        // Ensure the remainder of the payment is handled
        // Transfer the remaining balance back to the sender if any
        
        

        // Mint the NFT
        let nft = AtomNFT{
            id: object::new(ctx),
            name: utf8(name),
            description: utf8(description),
            image_url: url::new_unsafe_from_bytes(url)
        };

        event::emit(MintNFTEvent{
            object_id: object::uid_to_inner(&nft.id),
            creator: sender,
            name: nft.name,
        });

        transfer::transfer(nft, sender);
    }

    // Update the description of an NFT
    public entry fun update_description(
        nft: &mut AtomNFT,
        new_description: vector<u8>,
    ) {
        nft.description = utf8(new_description);
    }

    // Permanently delete an NFT
    public entry fun burn(nft: AtomNFT) {
        let AtomNFT {id, name: _, description: _, image_url: _} = nft;
        object::delete(id);
    }

    // Get the NFT's description
    public fun description(nft: &AtomNFT): &String {
        &nft.description
    }

    // Get the NFT's name
    public fun name(nft: &AtomNFT): &String {
        &nft.name
    }

    // Get the NFT's image_url
    public fun url(nft: &AtomNFT): &Url {
        &nft.image_url
    }
}
