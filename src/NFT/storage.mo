/**
 * Module     : storage.mo
 * Copyright  : 2021 Hellman Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : Hellman Team - Leven
 * Stability  : Experimental
 */

import HashMap "mo:base/HashMap";
import RBTree "mo:base/RBTree";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Types "../common/types";
import Cycles "mo:base/ExperimentalCycles";

shared(msg) actor class Storage(_owner: Principal) {
    type TokenIndex = Types.TokenIndex;
    type NFTStoreInfo = Types.NFTStoreInfo;

    private stable var owner_ : Principal = _owner;
    private stable var passWd: Text = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkaWQ6ZXRocjoweEVEZjY2YmEyMjBjMDlCZTgzNUVCQzczMTkxOTQyMDU2NTE4ZjE2MDMiLCJpc3MiOiJ3ZWIzLXN0b3JhZ2UiLCJpYXQiOjE2NTE5MDU1NTkzMTcsIm5hbWUiOiJkb3JpcyJ9.3KipoolPI6kSOqEVRLfr8o8vsdoUaFB8DXhT2h_8RnY";

    private stable var userFavoriteEntries: [(Principal,[NFTStoreInfo]) ] = [];
    private var userFavorite = RBTree.RBTree<Principal, [NFTStoreInfo]>(Principal.compare);

    private stable var nftFavoriteEntries: [(NFTStoreInfo,Nat) ] = [];
    private var nftFavorite = RBTree.RBTree<NFTStoreInfo, Nat>(Types.NFTStoreInfo.compare);

    private stable var collectionFavoriteEntries: [(Principal,Nat) ] = [];
    private var collectionFavorite = RBTree.RBTree<Principal, Nat>(Principal.compare);

    private stable var usrCollFavoriteEntries: [(Text, Bool) ] = [];
    private var usrCollFavorite = RBTree.RBTree<Text, Bool>(Text.compare);

    private stable var nftHeatNumEntries: [(NFTStoreInfo,Nat) ] = [];
    private var nftHeatNum = RBTree.RBTree<NFTStoreInfo, Nat>(Types.NFTStoreInfo.compare);

    private stable var usrNftHeatEntries: [(Text, Bool) ] = [];
    private var usrNftHeat = RBTree.RBTree<Text, Bool>(Text.compare);

    system func preupgrade() {
        userFavoriteEntries := Iter.toArray(userFavorite.entries());
        nftFavoriteEntries := Iter.toArray(nftFavorite.entries());
        collectionFavoriteEntries := Iter.toArray(collectionFavorite.entries());
        usrCollFavoriteEntries := Iter.toArray(usrCollFavorite.entries());
        nftHeatNumEntries := Iter.toArray(nftHeatNum.entries());
        usrNftHeatEntries := Iter.toArray(usrNftHeat.entries());
    };

    system func postupgrade() {
        for( (k, v) in userFavoriteEntries.vals()){
            userFavorite.put(k, v);
        };
        userFavoriteEntries := [];

        for( (k, v) in nftFavoriteEntries.vals()){
            nftFavorite.put(k, v);
        };
        nftFavoriteEntries := [];

        for( (k, v) in collectionFavoriteEntries.vals()){
            collectionFavorite.put(k, v);
        };
        collectionFavoriteEntries := [];

        for( (k, v) in usrCollFavoriteEntries.vals()){
            usrCollFavorite.put(k, v);
        };
        usrCollFavoriteEntries := [];

        for( (k, v) in nftHeatNumEntries.vals()){
            nftHeatNum.put(k, v);
        };
        nftHeatNumEntries := [];

        for( (k, v) in usrNftHeatEntries.vals()){
            usrNftHeat.put(k, v);
        };
        usrNftHeatEntries := [];
    };

    public shared(msg) func getOwner() : async Principal {
        owner_
    };

    public shared(msg) func setPasswd(pw: Text) : async Bool {
        assert(msg.caller == owner_);
        passWd := pw;
        return true;
    };

    public shared(msg) func setFavorite(info: NFTStoreInfo, passwd: Text) : async Bool {
        if(passWd != passwd){return false;};
        var ret: Bool = false; 
        switch(userFavorite.get(msg.caller)){
            case (?arr){
                if(Option.isNull(Array.find<NFTStoreInfo>(arr, 
                    func (x : NFTStoreInfo): Bool { 
                        x.videoLink == info.videoLink
                        and x.canisterId == info.canisterId
                        and x.nftIndex == info.nftIndex
                    }))
                )
                {
                    var arrNew : [NFTStoreInfo] = Array.append(arr, [info]);
                    userFavorite.put(msg.caller, arrNew);
                    ret := true;
                };
            };
            case _ {
                userFavorite.put(msg.caller, [info]);
                ret := true;
            };
        };
        if(ret){
            _addNftFavoriteNum(info);
        };
        ret
    };

    public shared(msg) func cancelFavorite(info: NFTStoreInfo, passwd: Text) : async Bool {
        if(passWd != passwd){return false;};
        var ret: Bool = false; 
        switch(userFavorite.get(msg.caller)){
            case (?arr){
                var arrNew : [NFTStoreInfo] = Array.filter<NFTStoreInfo>(arr, 
                    func (x : NFTStoreInfo): Bool {
                        x.videoLink != info.videoLink
                        and x.canisterId != info.canisterId
                        and x.nftIndex != info.nftIndex 
                    } 
                );
                userFavorite.put(msg.caller, arrNew);
                ret := true;
            };
            case _ {};
        };
        if(ret){
            _subNftFavoriteNum(info);
        };
        ret
    };

    public query func getFavorite(user: Principal): async [NFTStoreInfo] {
        var ret: [NFTStoreInfo] = [];
        switch(userFavorite.get(user)){
            case (?arr){
                ret := arr;
            };
            case _ {};
        };
        return ret;
    };

    public query func isFavorite(user:Principal, info: NFTStoreInfo): async Bool {
        var ret: Bool = false;
        switch(userFavorite.get(user)){
            case (?arr){
                if(Option.isSome(Array.find<NFTStoreInfo>(arr, 
                    func (x : NFTStoreInfo): Bool { 
                        x.videoLink == info.videoLink 
                        and x.nftType == info.nftType
                        and x.canisterId == info.canisterId
                        and x.nftIndex == info.nftIndex
                    }))
                )
                {
                    ret := true;
                };
            };
            case _ {};
        };
        return ret;
    };

    public shared(msg) func setCollFavorite(cid: Principal, passwd: Text) : async Bool {
        var ret: Bool = false;
        if(passWd != passwd){return ret;};
        let key = Principal.toText(msg.caller) # Principal.toText(cid);
        switch(usrCollFavorite.get(key)){
            case (?t){};
            case _ {
                switch(collectionFavorite.get(cid)){
                    case (?n){
                        collectionFavorite.put(cid, n+1);
                    };
                    case _ {
                        collectionFavorite.put(cid, 1);
                    };
                };
                usrCollFavorite.put(key, true);
            }
        };  
        ret
    };

    public shared(msg) func cancelCollFavorite(cid: Principal, passwd: Text) : async Bool {
        var ret: Bool = false;
        if(passWd != passwd){return ret;};
        switch(usrCollFavorite.get(Principal.toText(msg.caller) # Principal.toText(cid))){
            case (?t){
                switch(collectionFavorite.get(cid)){
                    case (?n){
                        if(n > 1){collectionFavorite.put(cid, n-1);};
                        if(n ==1 ){ collectionFavorite.delete(cid); };
                    };
                    case _ {};
                };
                usrCollFavorite.delete(Principal.toText(msg.caller) # Principal.toText(cid));
                ret := true;
            };
            case _ {};
        };  
        ret
    };

    public query func getCollFavoriteNum(cid: Principal): async Nat {
        switch(collectionFavorite.get(cid)){
            case (?n){n};
            case _ {0};
        }
    };

    public query func isCollFavorite(user:Principal, cid: Principal): async Bool {
        switch(usrCollFavorite.get(Principal.toText(user) # Principal.toText(cid))){
            case(?b){b};
            case _ {false};
        };
    };

    public shared(msg) func setNftHeatNum(info: NFTStoreInfo, passwd: Text) : async Bool {
        var ret: Bool = false;
        if(passWd != passwd){return ret;};
        let key = Principal.toText(info.canisterId) # Nat.toText(info.nftIndex) # Principal.toText(msg.caller);
        switch(usrNftHeat.get(key)){
            case (?t){};
            case _ {
                switch(nftHeatNum.get(info)){
                    case (?n){
                        nftHeatNum.put(info, n+1);
                    };
                    case _ {
                        nftHeatNum.put(info, 1);
                    };
                };
                usrNftHeat.put(key, true);
            }
        };  
        ret
    };

    public shared(msg) func calcelNftHeatNum(info: NFTStoreInfo, passwd: Text) : async Bool {
        var ret: Bool = false;
        if(passWd != passwd){return ret;};
        let key = Principal.toText(info.canisterId) # Nat.toText(info.nftIndex) # Principal.toText(msg.caller);
        switch(usrNftHeat.get(key)){
            case (?t){
                switch(nftHeatNum.get(info)){
                    case (?n){
                        if(n > 1){nftHeatNum.put(info, n-1);};
                        if(n ==1 ){ nftHeatNum.delete(info); };
                    };
                    case _ {};
                };
                usrNftHeat.delete(key);
                ret := true;
            };
            case _ {};
        };  
        ret
    };

    public query func getNftHeatNum(info: NFTStoreInfo): async Nat {
        switch(nftHeatNum.get(info)){
            case (?n){n};
            case _ {0};
        }
    };

    public query func isHeatAndFavorite(user:Principal, info: NFTStoreInfo): async (Bool, Bool) {
        let isHeat = switch(usrNftHeat.get(Principal.toText(info.canisterId) # Nat.toText(info.nftIndex) # Principal.toText(user))){
            case (?t){t};
            case _ {false};
        };
        let isFavorite = switch(userFavorite.get(user)){
            case (?arr){
                if(Option.isSome(Array.find<NFTStoreInfo>(arr, 
                    func (x : NFTStoreInfo): Bool { 
                        x.videoLink == info.videoLink 
                        and x.nftType == info.nftType
                        and x.canisterId == info.canisterId
                        and x.nftIndex == info.nftIndex
                    }))
                )
                {
                    true
                }else{false};
            };
            case _ {false};
        };
        (isHeat, isFavorite)
    };

    public query func getNftFavoriteNum(info: NFTStoreInfo): async Nat {
        switch(nftFavorite.get(info)){
            case (?n){n};
            case _ {0};
        };
    };

    public query func getAllNftFavoriteNum(): async [(NFTStoreInfo,Nat)] {
        Iter.toArray(nftFavorite.entries())
    };

    public query func getTopNFavoriteNft(n: Nat): async [(NFTStoreInfo,Nat)] {
        let sortArr = Array.sort(Iter.toArray(nftFavorite.entries()),  func (x : (NFTStoreInfo, Nat), y : (NFTStoreInfo, Nat)) : { #less; #equal; #greater } {
            if (x.1 > y.1) { #less }
            else if (x.1 == y.1) { #equal }
            else { #greater }
        });
        let ys : Buffer.Buffer<(NFTStoreInfo, Nat)> = Buffer.Buffer(n);
        var start: Nat = 0;
        label outer for (x in sortArr.vals()) {
            if (start == n) {
                break outer;
            };
            ys.add(x);
            start += 1;
        };
        ys.toArray()
    };

    public query func getSortNftFavoriteNumByCid(cid: Principal): async [(NFTStoreInfo,Nat)] {
        var ret = Buffer.Buffer<(NFTStoreInfo, Nat)>(0);
        for((k,v) in nftFavorite.entries()){
            if(k.canisterId == cid){
                ret.add((k,v));
            };
        };
        Array.sort(ret.toArray(), func (x : (NFTStoreInfo, Nat), y : (NFTStoreInfo, Nat)) : { #less; #equal; #greater } {
            if (x.1 > y.1) { #less }
            else if (x.1 == y.1) { #equal }
            else { #greater }
        })
    };

    public shared(msg) func setCollFavorite2(cid: Principal, num: Nat) : async Bool {
        assert(msg.caller == owner_);
        collectionFavorite.put(cid, num);
        true
    };

    public shared(msg) func setFavorite2(info: NFTStoreInfo, num: Nat) : async Bool {
        assert(msg.caller == owner_);
        nftFavorite.put(info, num);
        true
    };

    public shared(msg) func setHeatNum2(info: NFTStoreInfo, num: Nat) : async Bool {
        assert(msg.caller == owner_);
        nftHeatNum.put(info, num);
        true
    };

    private func _addNftFavoriteNum(identity: NFTStoreInfo) {
        switch(nftFavorite.get(identity)){
            case(?n) { nftFavorite.put(identity, n + 1); };
            case _ { nftFavorite.put(identity, 1); };
        };
    };

    private func _subNftFavoriteNum(identity: NFTStoreInfo) {
        switch(nftFavorite.get(identity)){
            case(?n) { 
                if( n > 1){
                    nftFavorite.put(identity, n - 1);
                };
                if(n ==1 ){ nftFavorite.delete(identity); };
            };
            case _ {};
        };
    };

    public query func getCycles() : async Nat {
        return Cycles.balance();
    };

    public shared(msg) func wallet_receive() : async Nat {
        let available = Cycles.available();
        let accepted = Cycles.accept(available);
        return accepted;
    };
};