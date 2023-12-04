module devhub::devcard{
    use std::option::{Self, Option};
    use std::string::{Self, String};

    use sui::transfer;
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::url::{Self, Url};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::object_table::{Self, ObjectTable};
    use sui::event;

    const NOT_THE_OWNER: u64 = 0;
    const INSUFFICIENT_FUNDS: u64 = 1;
    const MIN_CARD_COST: u64 = 1;

    struct DevCard has key, store{
        id: UID,
        name: String,
        owner: address,
        title: String,
        img_url: Url,
        //description may have a string value or null
        description: Option<String>,
        years_of_exp: u8,
        technologies: String,
        portfolio: String,
        contact: String,
        open_to_work: bool,
    }

    struct DevHub has key{
        id: UID,
        owner: address,
        counter: u64,
        //Object table has key value pairs. Here key is id (u64), value is DevCard
        cards: ObjectTable<u64, DevCard>
    }

    //Event: requires copy and drop functionalities
    struct CardCreated has copy, drop{
        id: ID,
        name: String,
        owner: address,
        title: String,
        contact: String
    }

    //Event that will be triggered when user updates description
    struct DescriptionUpdated has copy, drop{
        name: String,
        owner: address, 
        new_description: String
    }

    struct PortfolioUpdated has copy, drop{
        name: String,
        owner: address,
        new_portfolio: String
    }

    //init function: runs only once
    fun init(ctx: &mut TxContext){
        //we are sharing the DevHub object. It will be accessible by everyone
        transfer::share_object(
            DevHub{
                id: object::new(ctx),
                owner: tx_context::sender(ctx),
                counter: 0,
                cards: object_table::new(ctx),
            }
        )
    }

    public entry fun create_card(
        name: vector<u8>,
        title: vector<u8>,
        img_url: vector<u8>,
        years_of_exp: u8,
        technologies: vector<u8>,
        portfolio: vector<u8>,
        contact: vector<u8>,
        payment: Coin<SUI>,
        devhub: &mut DevHub,
        ctx: &mut TxContext 
    ){
        let value = coin::value(&payment);
        assert!(value == MIN_CARD_COST, INSUFFICIENT_FUNDS);
        transfer::public_transfer(payment, devhub.owner);

        devhub.counter = devhub.counter + 1;

        let id = object::new(ctx);
        
        //trigger the event CardCreated
        event::emit(
            CardCreated{
                id: object::uid_to_inner(&id),
                name: string::utf8(name),
                owner: tx_context::sender(ctx),
                title: string::utf8(title),
                contact: string::utf8(contact)
            }
        );

        //type conversions
        let devcard = DevCard{
            id: id,
            name: string::utf8(name),
            owner: tx_context::sender(ctx),
            title: string::utf8(title),
            img_url: url::new_unsafe_from_bytes(img_url),
            description: option::none(),
            years_of_exp,
            technologies: string::utf8(technologies),
            portfolio: string::utf8(portfolio),
            contact: string::utf8(contact),
            open_to_work: true
        };

        //adding the devcard to the object table in devhub
        object_table::add(&mut devhub.cards, devhub.counter, devcard)
    }

    public entry fun update_card_description(
        devhub: &mut DevHub, new_description: vector<u8>, id: u64, ctx: &mut TxContext 
    ){
        let user_card = object_table::borrow_mut(&mut devhub.cards, id);
        assert!(tx_context::sender(ctx) == user_card.owner, NOT_THE_OWNER);

        let old_value = option::swap_or_fill(&mut user_card.description, string::utf8(new_description));
        
        event::emit(
            DescriptionUpdated{
                name: user_card.name,
                owner: user_card.owner,
                new_description: string::utf8(new_description)
            }
        );

        _ = old_value;
    }

    //if return type is void, entry keyword is added to the function declaration
    public entry fun deactivate_card(
        devhub: &mut DevHub, id: u64, ctx: &mut TxContext
    ){
        let user_card = object_table::borrow_mut(&mut devhub.cards, id);
        assert!(tx_context::sender(ctx) == user_card.owner, NOT_THE_OWNER);
        user_card.open_to_work = false;
    }

    public entry fun update_portfolio(
        devhub: &mut DevHub, new_portfolio: vector<u8>, id: u64, ctx: &mut TxContext
    ){
        let user_card = object_table::borrow_mut(&mut devhub.cards, id);
        assert!(tx_context::sender(ctx) == user_card.owner, NOT_THE_OWNER);
        user_card.portfolio = string::utf8(new_portfolio);

        event::emit(
            PortfolioUpdated{
                name: user_card.name,
                owner: user_card.owner,
                new_portfolio: string::utf8(new_portfolio)
            }
        );
    }

    //no entry keyword since this function will return sth
    public fun get_card_info(
        //mut is removed here since we are only accessing data and not modifying data in DevHub
    devhub: &DevHub, id:u64)
    : (
        String,
        address,
        String,
        Url,
        Option<String>,
        u8,
        String,
        String,
        String,
        bool,
    ){
        let card = object_table::borrow(&devhub.cards, id);
        //returning the tuple below
        (
            card.name,
            card.owner,
            card.title,
            card.img_url,
            card.description,
            card.years_of_exp,
            card.technologies,
            card.portfolio,
            card.contact,
            card.open_to_work
        )
    }
}