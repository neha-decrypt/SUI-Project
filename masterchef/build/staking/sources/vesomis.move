module vesomis::vesomis {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    public struct VeSomisMintEvent has copy, drop {
        id: object::ID,
        amount: u64,
        sender: address,
    }
    
    public struct VeSomisBurnEvent has copy, drop {
        id: object::ID,
        amount: u64,
        sender: address,
    }
    
    public struct Supply has store, key {
        id: object::UID,
        supply: u64,
    }
    
    public struct VeSomis has key {
        id: object::UID,
        balance: u64,
    }
    
    
    public(package) fun transfer(arg0: VeSomis, arg1: &mut tx_context::TxContext) {
        transfer::transfer<VeSomis>(arg0, tx_context::sender(arg1));
    }
    
    public fun amount(arg0: &VeSomis) : u64 {
        arg0.balance
    }
    
    public(package) fun burn(arg0: &mut Supply, arg1:  VeSomis, arg2:  &tx_context::TxContext) {
        let VeSomis {
            id      : v0,
            balance : v1,
        } = arg1;
        
        arg0.supply = arg0.supply - v1;
        
        object::delete(v0);
    }
    
    fun init(arg0: &mut tx_context::TxContext) {
        let v0 = Supply{
            id     : object::new(arg0), 
            supply : 0,
        };
        transfer::public_share_object<Supply>(v0);
    }
    
    public(package) fun join(arg0: &mut VeSomis, arg1: VeSomis) {
        let VeSomis {
            id      : v0,
            balance : v1,
        } = arg1;
        object::delete(v0);
        arg0.balance = arg0.balance + v1;
    }
    
    public(package) fun mint(arg0: &mut Supply, arg1: u64, arg2: &mut tx_context::TxContext) : VeSomis {
        let v0 = VeSomis{
            id      : object::new(arg2), 
            balance : arg1,
        };
        let v1 = VeSomisMintEvent{
            id     : object::id<VeSomis>(&v0), 
            amount : arg1, 
            sender : tx_context::sender(arg2),
        };
        event::emit<VeSomisMintEvent>(v1);
        arg0.supply = arg0.supply + arg1;
        v0
    }
    
    public(package) fun mint_and_transfer(arg0: &mut Supply, arg1: u64, arg2: &mut tx_context::TxContext) {
        transfer(mint(arg0, arg1, arg2), arg2);
    }
    
    // decompiled from Move bytecode v6
}

