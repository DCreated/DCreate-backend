/**
 * Module     : NFTFactory.mo
 * Copyright  : 2021 Hellman Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : Hellman Team - Leven
 * Stability  : Experimental
 */

import WICP "../common/WICP";
import Types "../common/types";
import IC0 "../common/IC0";
import NFTTypes "../common/nftTypes";
import PubNFT "../NFT/pubNFT";
import PriNFT "../NFT/priNFT";
import ForkNFT "../NFT/forkNFT";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Bool "mo:base/Bool";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import List "mo:base/List";
import Option "mo:base/Option";
import Cycles "mo:base/ExperimentalCycles";
import Result "mo:base/Result";

/**
 * Factory Canister to Create Canister
 */
shared(msg)  actor class NFTFactory (owner_: Principal, feeTo_: Principal, wicpCanisterId_: Principal) = this {

    type WICPActor = WICP.WICPActor;
    type CollectionIndex = Types.TokenIndex;
    type CollectionInfo = Types.CollectionInfo;
    type NewCollectionInfo = Types.NewCollectionInfo;
    type NewCollectionParamInfo = Types.NewCollectionParamInfo;
    type NewPriCollectionParamInfo = Types.NewPriCollectionParamInfo;
    type NewForkCollectionParamInfo = Types.NewForkCollectionParamInfo;
    type CreateResponse = Types.CreateResponse;
    type CreateError = Types.CreateError;
    type FactorySettings = Types.FactorySettings;

    private stable var owner: Principal = owner_;
    private stable var createFeeTo : Principal = feeTo_;
    private stable var WICPCanisterActor: WICPActor = actor(Principal.toText(wicpCanisterId_));

    private stable var maxSupply:Nat = 10000;
    private stable var maxForkRoyaltyRatio:Nat = 30;
    private stable var maxRoyaltyRatio:Nat = 50;
    private stable var maxForkFee:Nat = 200_000_000;
    private stable var maxNameSize:Nat = 20;
    private stable var maxDescSize:Nat = 2000;
    private stable var maxCategorySize:Nat = 20;
    private stable var newCollectionFee:Nat = 1_000_000_000;

    private stable var forkFeeCommission:Nat = 10;
    private stable var uploadBaseFeeForPublic = 50_000_000;
    private stable var uploadBaseFeeForFork = 10_000_000;
    private stable var marketFeeRatio = 1;

    private stable var cyclesCreateCanvas: Nat = Types.CREATECANVAS_CYCLES;

    private stable var collectionInfoEntries : [(Text, CollectionInfo)] = [];
    private var collectionInfo = HashMap.HashMap<Text, CollectionInfo>(1, Text.equal, Text.hash);

    private stable var newCollectionInfoEntries : [(Text, NewCollectionInfo)] = [];
    private var newCollectionInfo = HashMap.HashMap<Text, NewCollectionInfo>(1, Text.equal, Text.hash); 

    private stable var dataUser : Principal = Principal.fromText("hhftw-cdk5x-tvfsh-b7wr5-vgc2q-ekhzl-h2sws-pzpkh-7n7yl-a2m2j-6ae");

    private stable var whiteListEntries : [(Principal, Nat)] = [];
    private var whiteList = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);

    private stable var bPublic: Bool = false;

    system func preupgrade() {
        newCollectionInfoEntries := Iter.toArray(newCollectionInfo.entries());
        collectionInfoEntries := Iter.toArray(collectionInfo.entries());
        whiteListEntries := Iter.toArray(whiteList.entries());
    };

    system func postupgrade() {
        collectionInfo := HashMap.fromIter<Text, CollectionInfo>(collectionInfoEntries.vals(), 1, Text.equal, Text.hash);
        newCollectionInfo := HashMap.fromIter<Text, NewCollectionInfo>(newCollectionInfoEntries.vals(), 1, Text.equal, Text.hash);
        whiteList := HashMap.fromIter<Principal, Nat>(whiteListEntries.vals(), 1, Principal.equal, Principal.hash);

        collectionInfoEntries := [];
        newCollectionInfoEntries := [];
        whiteListEntries := [];
    };

    private func _isOwner(user: Principal) : Bool {
        dataUser == user or owner == user 
    };

    public shared(msg) func createNewPriCollection(paramInfo: NewPriCollectionParamInfo) : async CreateResponse {   
        //factory对外公开时或者不公开期间在白名单才能创建collection
        var availableMintTimes = 0;
        if (not bPublic){
            availableMintTimes := switch(whiteList.get(msg.caller)){
                case (?b){b};
                case _ {return #err(#NotOnWhiteList);};
            };
        };
        
        switch(_checkPriCollectionParam(paramInfo)){
            case(#ok(_)) {};
            case(#err(errText)){
                return #err(errText);
            };
        };
       
        if(not _isOwner(msg.caller)){
            let transferResult = await WICPCanisterActor.transferFrom(msg.caller, createFeeTo, newCollectionFee);
            switch(transferResult){
                case(#ok(b)) {};
                case(#err(errText)){
                    return #err(errText);
                };
            };
        };

        Cycles.add(cyclesCreateCanvas);

        var collType:Nat = 0; //public
        var baseFee: Nat = uploadBaseFeeForPublic;
        if(not _isOwner(msg.caller)){
            baseFee := uploadBaseFeeForFork;
        };

        var canisterId:Principal = Principal.fromActor(this);
        if(_isOwner(msg.caller)){
            let collection = await PubNFT.PubNFT(paramInfo, baseFee, marketFeeRatio,
                                                    msg.caller, owner, createFeeTo, wicpCanisterId_);
            canisterId := Principal.fromActor(collection);
        }else{
            let collection = await PriNFT.PriNFT(paramInfo, baseFee, marketFeeRatio,
                                                    msg.caller, owner, createFeeTo, wicpCanisterId_);
            canisterId := Principal.fromActor(collection);
            collType := 1; //private
        };

        let collInfo: NewCollectionInfo = {
            owner = msg.caller;
            cid = canisterId;
            name = paramInfo.contentInfo.name;
            desc = paramInfo.contentInfo.desc;
            category = paramInfo.contentInfo.category;
            totalSupply = paramInfo.totalSupply;
            collectionType = collType;
        };
        newCollectionInfo.put(paramInfo.contentInfo.name, collInfo);

        if (not bPublic){
            if (availableMintTimes == 1) {
                whiteList.delete(msg.caller);
            }else{
                whiteList.put(msg.caller,availableMintTimes - 1);
            };
        };

        ignore _setController(canisterId);
        return #ok(paramInfo.contentInfo.name);
    };

    public shared(msg) func createNewForkCollection(paramInfo: NewForkCollectionParamInfo) : async CreateResponse {   
        //factory对外公开时或者不公开期间在白名单才能创建collection
        var availableMintTimes = 0;
        if (not bPublic){
            availableMintTimes := switch(whiteList.get(msg.caller)){
                case (?b){b};
                case _ {return #err(#NotOnWhiteList);};
            };
        };
        
        switch(_checkForkCollectionParam(paramInfo)){
            case(#ok(_)) {};
            case(#err(errText)){
                return #err(errText);
            };
        };
       
        let transferResult = await WICPCanisterActor.transferFrom(msg.caller, createFeeTo, newCollectionFee);
        switch(transferResult){
            case(#ok(b)) {};
            case(#err(errText)){
                return #err(errText);
            };
        };

        Cycles.add(cyclesCreateCanvas);
        let collection = await ForkNFT.ForkNFT(paramInfo, uploadBaseFeeForFork, forkFeeCommission, marketFeeRatio,
                                                msg.caller, owner, createFeeTo, wicpCanisterId_);
        var canisterId = Principal.fromActor(collection);

        let collInfo: NewCollectionInfo = {
            owner = msg.caller;
            cid = canisterId;
            name = paramInfo.contentInfo.name;
            desc = paramInfo.contentInfo.desc;
            category = paramInfo.contentInfo.category;
            totalSupply = paramInfo.totalSupply;
            collectionType = 2;
        };
        newCollectionInfo.put(paramInfo.contentInfo.name, collInfo);

        if (not bPublic){
            if (availableMintTimes == 1) {
                whiteList.delete(msg.caller);
            }else{
                whiteList.put(msg.caller,availableMintTimes - 1);
            };
        };

        ignore _setController(canisterId);
        return #ok(paramInfo.contentInfo.name);
    };

    public query func isPublic() : async Bool {
        bPublic
    };

    public shared(msg) func setbPublic(isPublic: Bool) : async Bool {
        assert(msg.caller == owner);
        bPublic := isPublic;
        return true;
    };

    public shared(msg) func setCollInfo(name:Text, info: NewCollectionInfo) : async Bool {
        assert(msg.caller == owner);
        newCollectionInfo.put(name, info);
        true
    };

    public shared(msg) func uploadWhiteList(accountList: [Principal]) : async Bool {
        assert(msg.caller == owner);
        for(value in accountList.vals()){
            switch(whiteList.get(value)){
                case (?b){
                    whiteList.put(value, b+1);
                };
                case _ {
                    whiteList.put(value, 1);
                };
            }
        };
        return true;
    };

    public shared(msg) func clearWhiteList() : async Bool {
        assert(msg.caller == owner);
        whiteList := HashMap.HashMap<Principal, Nat>(0, Principal.equal, Principal.hash);
        return true;
    };
    
    public query func getWhiteList() : async [(Principal, Nat)] {
        Iter.toArray(whiteList.entries())
    };

    public query func checkIfWhiteList(user: Principal) : async Nat {
        switch(whiteList.get(user)){
            case (?b){b};
            case _ {0};
        }
    };

    private func _checkPriCollectionParam(paramInfo: NewPriCollectionParamInfo) : Result.Result<(), CreateError> {
        if(_checkProNameExist(paramInfo.contentInfo.name)){return #err(#NameAlreadyExit);};
        if(paramInfo.totalSupply > maxSupply) {return #err(#SupplyTooLarge);};
        if( paramInfo.contentInfo.name.size() > maxNameSize 
            or paramInfo.contentInfo.desc.size() > maxDescSize 
            or paramInfo.contentInfo.category.size() > maxCategorySize 
        ){
                return #err(#ParamError);
        };
        #ok()
    };

    private func _checkForkCollectionParam(paramInfo: NewForkCollectionParamInfo) : Result.Result<(), CreateError> {
        if(_checkProNameExist(paramInfo.contentInfo.name)){return #err(#NameAlreadyExit);};
        if(paramInfo.totalSupply > maxSupply) {return #err(#SupplyTooLarge);};
        if( paramInfo.contentInfo.name.size() > maxNameSize 
            or paramInfo.contentInfo.desc.size() > maxDescSize 
            or paramInfo.contentInfo.category.size() > maxCategorySize
            or paramInfo.forkRoyaltyRatio > maxForkRoyaltyRatio
            or paramInfo.forkFee > maxForkFee
        ){
                return #err(#ParamError);
        };
        #ok()
    };

    public query func checkProjectName(pName: Text) : async Bool {
        _checkProNameExist(pName)
    };

    private func _checkProNameExist(pName: Text) : Bool {
        Option.isSome(newCollectionInfo.get(pName))
    };

    public query func getAllCollInfo() : async [(Text, NewCollectionInfo)]{
        Iter.toArray(newCollectionInfo.entries())
    };

    public shared(msg) func delCollInfo(name: Text) : async Bool {
        assert(msg.caller == owner);
        newCollectionInfo.delete(name);
        true
    };

    public query func getCollInfoByUser(prinId: Principal) : async [NewCollectionInfo] {

        var ret : List.List<NewCollectionInfo> = List.nil<NewCollectionInfo>();
        for( (k,v) in newCollectionInfo.entries()){
            if(prinId == v.owner){
                ret := List.push(v, ret);
            };
        };
        List.toArray(ret)
    };

    public query func getPublicCollInfo() : async [NewCollectionInfo] {

        var ret : List.List<NewCollectionInfo> = List.nil<NewCollectionInfo>();
        for( (k,v) in newCollectionInfo.entries()){
            if(_isOwner(v.owner)){
                ret := List.push(v, ret);
            };
        };
        List.toArray(ret)
    };

    public query func getCollInfoByCategory(category: Text) : async [NewCollectionInfo] {

        var ret : List.List<NewCollectionInfo> = List.nil<NewCollectionInfo>();
        for( (k,v) in newCollectionInfo.entries()){
            if(category == v.category){
                ret := List.push(v, ret);
            };
        };
        List.toArray(ret)
    };

    public shared(msg) func setNewCollectionFee(price: Nat) : async Bool {
        assert(msg.caller == owner);
        newCollectionFee := price;
        return true;
    };

    public shared(msg) func setDataUser(_dataUser: Principal) : async Bool {
        assert(msg.caller == owner);
        dataUser := _dataUser;
        return true;
    };

    public shared(msg) func syncCollInfo() : async Bool {
        assert(msg.caller == owner);
        for((k,v) in collectionInfo.entries()){
            var typeColl: Nat = 1;
            if(_isOwner(v.owner)){
                typeColl := 0;
            }else{
                if(Option.isSome(v.forkFee) and Option.isSome(v.forkRoyaltyRatio)){
                    typeColl := 2; //fork
                }else{
                    typeColl := 1; //personal
                };
            };
            let info: NewCollectionInfo = {
                owner = v.owner;
                cid = v.cid;
                name = v.name;
                desc = v.desc;
                category = v.category;
                totalSupply = v.totalSupply;
                collectionType = typeColl;
            };
            newCollectionInfo.put(k,info);
        };
        true
    };

    public shared(msg) func clearOldCollInfo() : async Bool {
        assert(msg.caller == owner);
        collectionInfo := HashMap.HashMap<Text, CollectionInfo>(0, Text.equal, Text.hash);
        true
    };

    public shared(msg) func setMaxParam(newMaxSupply:Nat, newMaxRatio:Nat, newMaxRoyaltyRatio: Nat, newMaxForkFee:Nat,
                                            newMaxNameSize:Nat, newMaxDescSize:Nat, newMaxCategorySize:Nat) : async Bool {
        assert(msg.caller == owner);
        maxSupply := newMaxSupply;
        maxForkRoyaltyRatio := newMaxRatio;
        maxRoyaltyRatio := newMaxRoyaltyRatio;
        maxForkFee := newMaxForkFee;
        maxNameSize := newMaxNameSize;
        maxDescSize := newMaxDescSize;
        maxCategorySize := newMaxCategorySize;
        true
    };

    public shared(msg) func setFeeAndRatio(fee1: Nat, fee2: Nat, ratio: Nat, marketRatio: Nat) : async Bool {
        assert(msg.caller == owner);
        uploadBaseFeeForPublic := fee1;
        uploadBaseFeeForFork := fee2;
        forkFeeCommission := ratio;
        marketFeeRatio := marketRatio;
        return true;
    };

    public query func getDataUser() : async Principal {
        dataUser
    };

    public query func getFeeArgu() : async (Nat, Nat) {
        (uploadBaseFeeForPublic, forkFeeCommission)
    };

    public query func getMarketFeeRatio() : async Nat {
        marketFeeRatio
    };

    public shared(msg) func setCyclesCreate(newCycles: Nat) : async Bool {
        assert(msg.caller == owner);
        cyclesCreateCanvas := newCycles;
        return true;
    };

    public query func getCyclesCreate() : async Nat {
        cyclesCreateCanvas
    };

    public shared(msg) func setOwner(newOwner: Principal) : async Bool {
        assert(msg.caller == owner);
        owner := newOwner;
        return true;
    };

    public query func getOwner() : async Principal {
        owner
    };

    public shared(msg) func setCreateFeeTo(newFeeTo: Principal) : async Bool {
        assert(msg.caller == owner);
        createFeeTo := newFeeTo;
        return true;
    };

    public shared(msg) func wallet_receive() : async Nat {
        let available = Cycles.available();
        let accepted = Cycles.accept(available);
        return accepted;
    };

    public query func getCycles() : async Nat {
        return Cycles.balance();
    };

    public query func getSettings() : async FactorySettings {
        {
            maxSupply = maxSupply;
            maxForkRoyaltyRatio = maxForkRoyaltyRatio;
            maxRoyaltyRatio = maxRoyaltyRatio;
            maxForkFee = maxForkFee;
            maxNameSize = maxNameSize;
            maxDescSize = maxDescSize;
            maxCategorySize = maxCategorySize;
            createFee = newCollectionFee;
        }
    };

    private func _setController(canisterId: Principal): async () {

        let controllers: ?[Principal] = ?[owner, Principal.fromActor(this)];
        let settings: IC0.CanisterSettings = {
            controllers = controllers;
            compute_allocation = null;
            memory_allocation = null;
            freezing_threshold = null;
        };
        let params: IC0.UpdateSettingsParams = {
            canister_id = canisterId;
            settings = settings;
        };
        await IC0.IC.update_settings(params);
    };

}