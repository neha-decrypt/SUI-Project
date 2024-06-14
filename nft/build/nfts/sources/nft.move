module nfts::nft {
    use std::string::{utf8, String};
    use sui::url::{Self, Url};
    use sui::object::{Self, ID, UID};
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::package;
    use sui::display;

    //Define struct of NFT
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
        //claim publisher for package
        let publisher = package::claim(otw,ctx);

        //get new Display object for AtomNFT type
        let mut display = display::new_with_fields<AtomNFT>(
            &publisher, keys, values, ctx
        );

        //commit first version of Display to apply changes
        display::update_version(&mut display);

        let owner = tx_context::sender(ctx);
        transfer::public_transfer(publisher, owner);
        transfer::public_transfer(display, owner);

    }

    //public entry function mint nft
    public entry fun mint(
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        ctx: &mut TxContext
    ) {
        let nft = AtomNFT{
            id: object::new(ctx),
            name: utf8(name),
            description: utf8(description),
            image_url: url::new_unsafe_from_bytes(url)
        };

        let sender = tx_context::sender(ctx);

        event::emit(MintNFTEvent{
            object_id: object::uid_to_inner(&nft.id),
            creator: sender,
            name: nft.name,
        });

        transfer::transfer(nft, sender);
    }

    //update new description of nft
    public entry fun update_description(
        nft: &mut AtomNFT,
        new_description: vector<u8>,
    ) {
        nft.description = utf8(new_description)
    }

    //permamently delete nft
    public entry fun burn(nft: AtomNFT) {
        let AtomNFT {id, name: _, description: _, image_url: _} = nft;
        object::delete(id)
    }

    //get the nft's description
    public fun description(nft: &AtomNFT): &String {
        &nft.description
    }
    //get the nft's name
    public fun name(nft: &AtomNFT): &String {
        &nft.name
    }
    //get the nft's image_url
    public fun url(nft: &AtomNFT): &Url {
        &nft.image_url
    }

    public fun test(): u64{
       10
    }
}