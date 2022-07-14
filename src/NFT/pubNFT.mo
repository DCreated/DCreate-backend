/**
 * Module     : NFT.mo
 * Copyright  : 2021 Hellman Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : Hellman Team - Leven
 * Stability  : Experimental
 */

import WICP "../common/WICP";
import Types "../common/types";
import IC0 "../common/IC0";
import NFTTypes "../common/nftTypes";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Bool "mo:base/Bool";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Text "mo:base/Text";
import Option "mo:base/Option";
import Blob "mo:base/Blob";
import RBTree "mo:base/RBTree";
import Buffer "mo:base/Buffer";
import Time "mo:base/Time";
import Cycles "mo:base/ExperimentalCycles";
import Result "mo:base/Result";

shared(msg)  actor class PubNFT (paramInfo_: Types.NewPriCollectionParamInfo, uploadBaseFee_: Nat, marketFeeRatio_:Nat,
                owner_: Principal, cccOwner_:Principal, feeTo_: Principal, wicpCid_: Principal) = this {

    type ContentInfo = Types.ContentInfo;
    type NewPriCollectionParamInfo = Types.NewPriCollectionParamInfo;
    type Operation = Types.Operation;
    type NewPubItem = Types.NewPubItem;
    type AttrStru = Types.AttrStru;
    type TokenDetails = Types.TokenDetails;

    type ComponentAttribute = Types.ComponentAttribute;
    type CreatorPubNFTMetaData = Types.CreatorPubNFTMetaData;
    type PubNFTMetaData = Types.PubNFTMetaData;
    type GetTokenResponse = Types.GetTokenResponse;

    type WICPActor = WICP.WICPActor;
    type TokenIndex = Types.TokenIndex;
    type Balance = Types.Balance;
    type MintError = Types.MintError;
    type MintResponse = Types.MintResponse;
    type TransferResponse = Types.TransferResponse;
    type ListRequest = Types.ListRequest;
    type ListResponse = Types.ListResponse;
    type BuyResponse = Types.BuyResponse;
    type Listings = Types.Listings;
    type SoldListings = Types.SoldListings;
    type OpRecord = Types.OpRecord;
    type SaleRecord = Types.SaleRecord;
    type BuyRequest = Types.BuyRequest;
    type PubColSettings = Types.PubColSettings;


    type HttpRequest = NFTTypes.HttpRequest;
    type HttpResponse = NFTTypes.HttpResponse;

    private stable var owner: Principal = owner_;
    private stable var controller: Principal = cccOwner_;
    private stable var feeTo: Principal = feeTo_;

    private stable var maxNameSize:Nat = 20;
    private stable var maxDescSize:Nat = 2000;
    private stable var maxRoyaltyRatio = 50;
    private stable var uploadProtocolBaseFee = uploadBaseFee_;
    private stable var marketFeeRatio = marketFeeRatio_;

    private stable var WICPCanisterActor: WICPActor = actor(Principal.toText(wicpCid_));
    private stable var glIndex = 0;

    private stable var paramInfo: NewPriCollectionParamInfo = paramInfo_;
    private stable var logo: Blob = paramInfo.logo;
    private stable var featured: Blob = paramInfo.featured;
    private stable var banner: Blob = paramInfo.banner;

    type ListRecord = List.List<OpRecord>;
    private stable var opsEntries: [(TokenIndex, [OpRecord])] = [];
    private var ops = HashMap.HashMap<TokenIndex, ListRecord>(1, Types.TokenIndex.equal, Types.TokenIndex.hash);

    private stable var allSaleRecord: List.List<SaleRecord> = List.nil<SaleRecord>();
    
    private stable var tokensEntries : [(TokenIndex, PubNFTMetaData)] = [];
    private var tokens = HashMap.HashMap<TokenIndex, PubNFTMetaData>(1, Types.TokenIndex.equal, Types.TokenIndex.hash);

    private stable var listingsEntries : [(TokenIndex, Listings)] = [];
    private var listings = HashMap.HashMap<TokenIndex, Listings>(1, Types.TokenIndex.equal, Types.TokenIndex.hash);

    private stable var soldListingsEntries : [(TokenIndex, SoldListings)] = [];
    private var soldListings = HashMap.HashMap<TokenIndex, SoldListings>(1, Types.TokenIndex.equal, Types.TokenIndex.hash);

    // Mapping from NFT canister ID to owner
    private stable var ownersEntries : [(TokenIndex, Principal)] = [];
    private var owners = HashMap.HashMap<TokenIndex, Principal>(1, Types.TokenIndex.equal, Types.TokenIndex.hash); 

    private var nftApprovals = HashMap.HashMap<TokenIndex, Principal>(1, Types.TokenIndex.equal, Types.TokenIndex.hash);
    // Mapping from owner to operator approvals
    private var operatorApprovals = HashMap.HashMap<Principal, HashMap.HashMap<Principal, Bool>>(1, Principal.equal, Principal.hash);

    private stable var ipfsLinkEntries: [(Text,Bool) ] = [];
    private var ipfsLink = RBTree.RBTree<Text, Bool>(Text.compare);

    private stable var passWd: Text = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkaWQ6ZXRocjoweEVEZjY2YmEyMjBjMDlCZTgzNUVCQzczMTkxOTQyMDU2NTE4ZjE2MDMiLCJpc3MiOiJ3ZWIzLXN0b3JhZ2UiLCJpYXQiOjE2NTE5MDU1NTkzMTcsIm5hbWUiOiJkb3JpcyJ9.3KipoolPI6kSOqEVRLfr8o8vsdoUaFB8DXhT2h_8RnY";

    system func preupgrade() {
        tokensEntries := Iter.toArray(tokens.entries());
        listingsEntries := Iter.toArray(listings.entries());
        soldListingsEntries := Iter.toArray(soldListings.entries());
        ownersEntries := Iter.toArray(owners.entries());
        ipfsLinkEntries := Iter.toArray(ipfsLink.entries());

        var size0 : Nat = ops.size();
        var temp0 : [var (TokenIndex, [OpRecord])] = Array.init<(TokenIndex, [OpRecord])>(size0, (0, []));
        size0 := 0;
        for ((k, v) in ops.entries()) {
            temp0[size0] := (k, List.toArray(v));
            size0 += 1;
        };
        opsEntries := Array.freeze(temp0);
    };

    system func postupgrade() {
        owners := HashMap.fromIter<TokenIndex, Principal>(ownersEntries.vals(), 1, Types.TokenIndex.equal, Types.TokenIndex.hash);
        listings := HashMap.fromIter<TokenIndex, Listings>(listingsEntries.vals(), 1, Types.TokenIndex.equal, Types.TokenIndex.hash);
        soldListings := HashMap.fromIter<TokenIndex, SoldListings>(soldListingsEntries.vals(), 1, Types.TokenIndex.equal, Types.TokenIndex.hash);
        tokens := HashMap.fromIter<TokenIndex, PubNFTMetaData>(tokensEntries.vals(), 1, Types.TokenIndex.equal, Types.TokenIndex.hash);
       
        ownersEntries := [];
        listingsEntries := [];
        soldListingsEntries := [];
        tokensEntries := [];

        for ((k, v) in opsEntries.vals()) {
            ops.put(k, List.fromArray<OpRecord>(v));
        };
        opsEntries := [];

        for( (k, v) in ipfsLinkEntries.vals()){
            ipfsLink.put(k, v);
        };
        ipfsLinkEntries := [];
    };

    public query func getTokenById(tokenId:Nat): async GetTokenResponse{
        let tokenDetail : TokenDetails = {
                id = tokenId;
                attrArr = [];
        };
        #ok(tokenDetail)
    };

    public shared(msg) func setFavorite(tokenIndex: TokenIndex): async Bool {
        return true;
    };

    public shared(msg) func cancelFavorite(tokenIndex: TokenIndex): async Bool {
        return true;
    };

    private func _addRecord(index: TokenIndex, op: Operation, from: ?Principal, to: ?Principal, 
        price: ?Nat, timestamp: Time.Time
    ) {
        let o : OpRecord = {
            op = op;
            from = from;
            to = to;
            price = price;
            timestamp = timestamp;
        };
        switch (ops.get(index)) {
            case (?l) {
                let newl = List.push<OpRecord>(o, l);
                ops.put(index, newl);
            };
            case (_) {
                let l1 = List.nil<OpRecord>();
                let l2 = List.push<OpRecord>(o, l1);
                ops.put(index, l2);
            };   
        };
    };

    private func _addSaleRecord(index: TokenIndex, from: ?Principal, to: ?Principal, 
        price: ?Nat, timestamp: Time.Time
    ) {
        var linkInfo = tokens.get(index);
        let saleRecord : SaleRecord = {
            tokenIndex = index;
            from = from;
            to = to;
            price = price;
            photoLink = switch(linkInfo) {
                case (?l){l.photoLink};
                case _ {null};
            };
            videoLink = switch(linkInfo) {
                case (?l){l.videoLink};
                case _ {null};
            };
            timestamp = timestamp;
        };
        allSaleRecord := List.push(saleRecord, allSaleRecord);
    };

    public shared(msg) func chunkRecord(num: Nat) : async Bool {
        assert(msg.caller == controller);
        let (l1, l2) = List.split<SaleRecord>(num, allSaleRecord);
        allSaleRecord := l1;
        true
    };

    public shared(msg) func uploadIPFSItem(newItem: NewPubItem) : async MintResponse {
        if(passWd != newItem.passwd){return #err(#ParamError);};
        let videoLink = switch (newItem.videoLink) {
            case (?video) { video };
            case _ { return #err(#NoIPFSLink);}
        };

        switch(_checkIPFSItemParam(newItem,videoLink)){
            case(#ok(_)) {};
            case(#err(errText)){
                return #err(errText);
            };
        };

        var tos = Buffer.Buffer<Principal>(0);
        var values = Buffer.Buffer<Nat>(0);
        tos.add(feeTo);
        values.add(uploadProtocolBaseFee);

        let transferResult = await WICPCanisterActor.batchTransferFrom(msg.caller, tos.toArray(), values.toArray());
        switch(transferResult){
            case(#ok(b)) {};
            case(#err(errText)){
                return #err(errText);
            };
        };

        let data: PubNFTMetaData = {
            index = glIndex;
            creator = msg.caller;
            name = newItem.name;
            desc = newItem.desc;
            photoLink = newItem.photoLink;
            videoLink = newItem.videoLink;
            royaltyRatio = newItem.earnings;
            royaltyFeeTo = newItem.royaltyFeeTo;
        };
        tokens.put(glIndex, data);
        ipfsLink.put(videoLink,true);

        let index = glIndex;
        owners.put(glIndex, msg.caller);
        _addRecord(glIndex, #Mint, null, ?msg.caller, null, Time.now());

        glIndex += 1;

        return #ok(index);
    };

    public shared(msg) func transferFrom(from: Principal, to: Principal, tokenIndex: TokenIndex): async TransferResponse {
        if(Option.isSome(listings.get(tokenIndex))){
            return #err(#ListOnMarketPlace);
        };
        if( not _isApprovedOrOwner(from, msg.caller, tokenIndex) ){
            return #err(#NotOwnerOrNotApprove);
        };
        if(from == to){
            return #err(#NotAllowTransferToSelf);
        };
        _transfer(from, to, tokenIndex);
        if(Option.isSome(listings.get(tokenIndex))){
            listings.delete(tokenIndex);
        };
        _addRecord(tokenIndex, #Transfer, ?from, ?to, null, Time.now());
        _addSaleRecord(tokenIndex, ?from, ?to, null, Time.now());
        return #ok(tokenIndex);
    };

    public shared(msg) func batchTransferFrom(from: Principal, tos: [Principal], tokenIndexs: [TokenIndex]): async TransferResponse {
        if(tokenIndexs.size() == 0 or tos.size() == 0
            or tokenIndexs.size() != tos.size()){
            return #err(#Other);
        };
        for(v in tokenIndexs.vals()){
            if(Option.isSome(listings.get(v))){
                return #err(#ListOnMarketPlace);
            };
            if( not _isApprovedOrOwner(from, msg.caller, v) ){
                return #err(#NotOwnerOrNotApprove);
            };
        };
        for(i in Iter.range(0, tokenIndexs.size() - 1)){
            _transfer(from, tos[i], tokenIndexs[i]);
        };
        return #ok(tokenIndexs[0]);
    };

    public shared(msg) func approve(approve: Principal, tokenIndex: TokenIndex): async Bool{
        let ow = switch(_ownerOf(tokenIndex)){
            case(?o){o};
            case _ {return false;};
        };
        if(ow != msg.caller){return false;};
        nftApprovals.put(tokenIndex, approve);
        return true;
    };

    public shared(msg) func setApprovalForAll(operatored: Principal, approved: Bool): async Bool{
        assert(msg.caller != operatored);
        switch(operatorApprovals.get(msg.caller)){
            case(?op){
                op.put(operatored, approved);
                operatorApprovals.put(msg.caller, op);
            };
            case _ {
                var temp = HashMap.HashMap<Principal, Bool>(1, Principal.equal, Principal.hash);
                temp.put(operatored, approved);
                operatorApprovals.put(msg.caller, temp);
            };
        };
        return true;
    };

    public shared(msg) func list(listReq: ListRequest): async ListResponse {
        if(Option.isSome(listings.get(listReq.tokenIndex))){
            return #err(#AlreadyList);
        };
        if(not _checkOwner(listReq.tokenIndex, msg.caller)){
            return #err(#NotOwner);
        };
        let timeStamp = Time.now();
        var order:Listings = {
            tokenIndex = listReq.tokenIndex; 
            seller = msg.caller; 
            price = listReq.price;
            time = timeStamp;
        };
        listings.put(listReq.tokenIndex, order);
        _addRecord(listReq.tokenIndex, #List, ?msg.caller, null, ?listReq.price, timeStamp);
        return #ok(listReq.tokenIndex);
    };

    public shared(msg) func updateList(listReq: ListRequest): async ListResponse {
        let orderInfo = switch(listings.get(listReq.tokenIndex)){
            case (?o){o};
            case _ {return #err(#NotFoundIndex);};
        };
        if(listReq.price == orderInfo.price){
            return #err(#SamePrice);
        };
        if(not _checkOwner(listReq.tokenIndex, msg.caller)){
            return #err(#NotOwner);
        };
        let timeStamp = Time.now();
        var order:Listings = {
            tokenIndex = listReq.tokenIndex; 
            seller = msg.caller; 
            price = listReq.price;
            time = timeStamp;
        };
        listings.put(listReq.tokenIndex, order);
        _addRecord(listReq.tokenIndex, #UpdateList, ?msg.caller, null, ?listReq.price, timeStamp);
        return #ok(listReq.tokenIndex);
    };

    public shared(msg) func cancelList(tokenIndex: TokenIndex): async ListResponse {
        let orderInfo = switch(listings.get(tokenIndex)){
            case (?o){o};
            case _ {return #err(#NotFoundIndex);};
        };
        
        if(not _checkOwner(tokenIndex, msg.caller)){
            return #err(#NotOwner);
        };
        var price: Nat = orderInfo.price;
        listings.delete(tokenIndex);
        _addRecord(tokenIndex, #CancelList, ?msg.caller, null, ?price, Time.now());
        return #ok(tokenIndex);
    };

    public shared(msg) func buyNow(buyRequest: BuyRequest): async BuyResponse {
        assert(buyRequest.marketFeeRatio == marketFeeRatio);
        let orderInfo = switch(listings.get(buyRequest.tokenIndex)){
            case (?l){l};
            case _ {return #err(#NotFoundIndex);};
        };
        if(msg.caller == orderInfo.seller){
            return #err(#NotAllowBuySelf);
        };
        
        if(buyRequest.price < orderInfo.price){
            return #err(#Other);
        };
        
        if(not _checkOwner(buyRequest.tokenIndex, orderInfo.seller)){
            listings.delete(buyRequest.tokenIndex);
            return #err(#AlreadyTransferToOther);
        };

        var tos = Buffer.Buffer<Principal>(0);
        var values = Buffer.Buffer<Nat>(0);
        var valueMap = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);

        var royaltyRatio:Nat = 0;
        var royaltyFeeTo:Principal = owner;
        switch(tokens.get(buyRequest.tokenIndex)){
            case(?info){
                royaltyRatio := info.royaltyRatio;
                royaltyFeeTo := info.royaltyFeeTo;
            };
            case _ {return #err(#Other);};
        };

        let marketFee:Nat = Nat.div(Nat.mul(orderInfo.price, buyRequest.marketFeeRatio), 100);
        let royaltyFee:Nat = Nat.div(Nat.mul(orderInfo.price, royaltyRatio), 1000);
        if(marketFee > 0){
            switch(valueMap.get(buyRequest.feeTo)){
                case (?n){valueMap.put(buyRequest.feeTo, n+marketFee);};
                case _ {valueMap.put(buyRequest.feeTo, marketFee);};
            };
        };
        if(royaltyFee > 0){
            switch(valueMap.get(royaltyFeeTo)){
                case (?n){valueMap.put(royaltyFeeTo, n+royaltyFee);};
                case _ {valueMap.put(royaltyFeeTo, royaltyFee);};
            };
        };
        var sellValue = orderInfo.price - marketFee - royaltyFee;
        if(sellValue > 0){
            switch(valueMap.get(orderInfo.seller)){
                case (?n){valueMap.put(orderInfo.seller, n+sellValue);};
                case _ {valueMap.put(orderInfo.seller, sellValue);};
            };
        };
        
        for((k,v) in valueMap.entries()){
            tos.add(k);
            values.add(v);
        };

        let transferResult = await WICPCanisterActor.batchTransferFrom(msg.caller, tos.toArray(), values.toArray());
        switch(transferResult){
            case(#ok(b)) {};
            case(#err(errText)){
                return #err(errText);
            };
        };
        listings.delete(buyRequest.tokenIndex);

        _transfer(orderInfo.seller, msg.caller, orderInfo.tokenIndex);
        _addSoldListings(orderInfo);
        _addRecord(buyRequest.tokenIndex, #Sale, ?orderInfo.seller, ?msg.caller, ?orderInfo.price, Time.now());
        _addSaleRecord(buyRequest.tokenIndex, ?orderInfo.seller, ?msg.caller, ?orderInfo.price, Time.now());
        
        return #ok(buyRequest.tokenIndex);
    };

    public query func getAllSaleRecord(): async [SaleRecord] {
        List.toArray(allSaleRecord)
    };

    public query func getSaleRecordByAccount(user: Principal): async [SaleRecord] {
        var ret: List.List<SaleRecord> = List.nil<SaleRecord>();
        let saleArr: [SaleRecord] = List.toArray(allSaleRecord);
        for(val in saleArr.vals()){
            switch(val.from, val.to){
                case (?f, ?t) {
                    if(f == user or t == user){ ret := List.push(val, ret); };
                };
                case (_, _) {};
            };
        };
        List.toArray(ret)
    };

    public query func getFeeTo() : async Principal {
        feeTo
    };
    
    public shared(msg) func wallet_receive() : async Nat {
        let available = Cycles.available();
        let accepted = Cycles.accept(available);
        return accepted;
    };

    public query func getHistory(index: TokenIndex) : async [OpRecord] {
        var ret: [OpRecord] = [];
        switch (ops.get(index)) {
            case (?l) {
                ret := List.toArray(l);
            };
            case (_) {};   
        };
        return ret;
    };

    public query func getAllHistory() : async [(TokenIndex,ListRecord)] {
        Iter.toArray(ops.entries())
    };

    public query func getListings() : async [(PubNFTMetaData, Listings)] {
        var ret = Buffer.Buffer<(PubNFTMetaData, Listings)>(listings.size());
        for((k,v) in listings.entries()){
            switch(tokens.get(k)){
                case(?d){ret.add((d, v));};
                case _ {};
            }
        };
        return ret.toArray();
    };

    public query func getNFTMetaDataByIndex(index: TokenIndex) : async ?PubNFTMetaData {
        tokens.get(index)
    };

    public query func getListingsByAttr(attrArr: [AttrStru]) : async [(PubNFTMetaData, Listings)] {
        []
    };

    private func _checkIPFSItemParam(newItem: NewPubItem, videoLink: Text) : Result.Result<(), MintError> {
        switch (ipfsLink.get(videoLink)) {
            case(?b){ return #err(#IPFSLinkAlreadyExist);};
            case _ {};
        };
        if(newItem.name.size() > maxNameSize 
            or newItem.desc.size() > maxDescSize
            or newItem.earnings > maxRoyaltyRatio
        ){
            return #err(#ParamError);
        };
        #ok()
    };

    public query func getSoldListings() : async [(PubNFTMetaData, SoldListings)] {
        var ret = Buffer.Buffer<(PubNFTMetaData, SoldListings)>(soldListings.size());
        for((k,v) in soldListings.entries()){
            switch(tokens.get(k)){
                case(?d){ret.add((d, v));};
                case _ {};
            }
        };
        return ret.toArray();
    };

    public query func isList(index: TokenIndex) : async ?Listings {
        listings.get(index)
    };

    public query func getApproved(tokenIndex: TokenIndex) : async ?Principal {
        nftApprovals.get(tokenIndex)
    };

    public query func isApprovedForAll(owner: Principal, operatored: Principal) : async Bool {
        _checkApprovedForAll(owner, operatored)
    };

    public query func ownerOf(tokenIndex: TokenIndex) : async ?Principal {
        _ownerOf(tokenIndex)
    };

    public query func balanceOf(user: Principal) : async Nat {
        var ret: Nat = 0;
        for( (k,v) in owners.entries() ){
            if(v == user){ ret += 1; };
        };
        ret
    };

    public query func getCycles() : async Nat {
        return Cycles.balance();
    };
    
    public shared(msg) func changeOwner(newOwner: Principal) : async Bool {
        assert(msg.caller == controller);
        owner := newOwner;
        return true;
    };

    public query func getOwner() : async Principal {
        owner
    };

    public shared(msg) func setMAXRoyaltyRatio(maxRatio: Nat) : async Bool {
        assert(msg.caller == controller);
        maxRoyaltyRatio := maxRatio;
        return true;
    };

    public shared(msg) func setMaxParam(newMaxNameSize:Nat, newMaxDescSize:Nat, newMaxAttrNum:Nat) : async Bool {
        assert(msg.caller == controller);
        maxNameSize := newMaxNameSize; 
        maxDescSize := newMaxDescSize;
        true
    };

    public query func getSettings() : async PubColSettings {
        //fixme: 规避不能返回包含var的结构体的问题
        {
            maxRoyaltyRatio = maxRoyaltyRatio; 
            maxNameSize = maxNameSize; 
            maxDescSize = maxDescSize;
            uploadProtocolBaseFee = uploadProtocolBaseFee;
            marketFeeRatio = marketFeeRatio;
            totalSupply = owners.size();
        }
    };

    public shared(msg) func setFeeAndRatio(fee: Nat, ratio: Nat, marketRatio: Nat) : async Bool {
        assert(msg.caller == controller);
        uploadProtocolBaseFee := fee;
        marketFeeRatio := marketRatio;
        return true;
    };

    public query func getCollectionInfo() : async ContentInfo {
        paramInfo.contentInfo
    };

    // get all token by pid
    public query func getAllNFT(user: Principal) : async [PubNFTMetaData] {
        var ret = Buffer.Buffer<PubNFTMetaData>(0);
        for((k,v) in owners.entries()){
            if(v == user){
                switch(tokens.get(k)){
                    case(?d){ret.add(d);};
                    case _ {};
                }
            };
        };
        Array.sort(ret.toArray(), func (x : PubNFTMetaData, y : PubNFTMetaData) : { #less; #equal; #greater } {
            if (x.index < y.index) { #less }
            else if (x.index == y.index) { #equal }
            else { #greater }
        })
    };

    public query func getCreatorNFT(user: Principal) : async [CreatorPubNFTMetaData] {
        var ret = Buffer.Buffer<CreatorPubNFTMetaData>(0);
        for((k,v) in tokens.entries()){
            if(v.creator == user){
                let nftData = {
                    owner = owners.get(k);
                    metaData = v;
                };
                ret.add(nftData);
            };
        };
        Array.sort(ret.toArray(), func (x : CreatorPubNFTMetaData, y : CreatorPubNFTMetaData) : { #less; #equal; #greater } {
            if (x.metaData.index < y.metaData.index) { #less }
            else if (x.metaData.index == y.metaData.index) { #equal }
            else { #greater }
        })
    };

    //get all token 
    public query func getAllToken() : async [(PubNFTMetaData, ?Listings)] {
        var ret = Buffer.Buffer<(PubNFTMetaData, ?Listings)>(listings.size());
        for((k,v) in tokens.entries()){
            ret.add((v, listings.get(k)));
        };
        Array.sort(ret.toArray(), func (x : (PubNFTMetaData, ?Listings), y : (PubNFTMetaData, ?Listings)) : { #less; #equal; #greater } {
            if (x.0.index < y.0.index) { #less }
            else if (x.0.index == y.0.index) { #equal }
            else { #greater }
        })
    };

    public query func getAll() : async [(TokenIndex, Principal)] {
        Iter.toArray(owners.entries())
    };

    public query func getSuppy() : async Nat {
        owners.size();
    };

    public query func getCirculation() : async Nat {
        owners.size()
    };

    public query func getOwnerSize() : async Nat {
        var holders = HashMap.HashMap<Principal, Bool>(0, Principal.equal, Principal.hash);
        for((k,v) in owners.entries()){
            if(Option.isNull(holders.get(v))){
                holders.put(v, true);
            };
        };
        holders.size()
    };

    public query func http_request(request: HttpRequest) : async HttpResponse {
        let path = Iter.toArray(Text.tokens(request.url, #text("/")));
        if (path.size() != 2){
            assert(false);
        };

        var nftData :Blob = Blob.fromArray([]);
        if(path[0] == "token") {
            if(path[1] == "logo"){
                nftData := logo;
            }else if(path[1] == "featured"){
                nftData := featured;
            }else if(path[1] == "banner"){
                nftData := banner;
            }else{
                assert(false);
            };
        }else{assert(false)};

        return {
                body = nftData;
                headers = [("Content-Type", "image/png")];
                status_code = 200;
                streaming_strategy = null;
        };
    };

    private func _transfer(from: Principal, to: Principal, tokenIndex: TokenIndex) {
        nftApprovals.delete(tokenIndex);
        owners.put(tokenIndex, to);
    };

    private func _addSoldListings( orderInfo :Listings) {
        switch(soldListings.get(orderInfo.tokenIndex)){
            case (?sold){
                let newDeal = {
                    lastPrice = orderInfo.price;
                    time = Time.now();
                    account = sold.account + 1;
                };
                soldListings.put(orderInfo.tokenIndex, newDeal);
            };
            case _ {
                let newDeal = {
                    lastPrice = orderInfo.price;
                    time = Time.now();
                    account = 1;
                };
                soldListings.put(orderInfo.tokenIndex, newDeal);
            };
        };
    };

    private func _ownerOf(tokenIndex: TokenIndex) : ?Principal {
        owners.get(tokenIndex)
    };

    private func _checkOwner(tokenIndex: TokenIndex, from: Principal) : Bool {
        switch(owners.get(tokenIndex)){
            case (?o){
                if(o == from){
                    true
                }else{
                    false
                }
            };
            case _ {false};
        }
    };

    private func _checkApprove(tokenIndex: TokenIndex, approved: Principal) : Bool {
        switch(nftApprovals.get(tokenIndex)){
            case (?o){
                if(o == approved){
                    true
                }else{
                    false
                }
            };
            case _ {false};
        }
    };

    private func _checkApprovedForAll(owner: Principal, operatored: Principal) : Bool {
        switch(operatorApprovals.get(owner)){
            case (?a){
                switch(a.get(operatored)){
                    case (?b){b};
                    case _ {false};
                }
            };
            case _ {false};
        }
    };

    private func _isApprovedOrOwner(from: Principal, spender: Principal, tokenIndex: TokenIndex) : Bool {
        _checkOwner(tokenIndex, from) and (_checkOwner(tokenIndex, spender) or 
        _checkApprove(tokenIndex, spender) or _checkApprovedForAll(from, spender))
    };
}
