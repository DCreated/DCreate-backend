import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import List "mo:base/List";
import Time "mo:base/Time";
import Hash "mo:base/Hash";

module Types = {

  public let CREATECANVAS_CYCLES: Nat = 200_000_000_000;  //4 T
  public type Result<T,E> = Result.Result<T,E>;
  public type TokenIndex = Nat;

  public type Balance = Nat;

  public type FactorySettings = {
    maxSupply: Nat;
    maxForkRoyaltyRatio: Nat;
    maxRoyaltyRatio: Nat;
    maxForkFee: Nat;
    maxNameSize: Nat;
    maxDescSize: Nat;
    maxCategorySize: Nat;
    createFee : Nat;
  };
  
  public type ContentInfo = {
    name: Text;
    desc: Text;
    category: Text;
    webLink: ?Text;
    twitter: ?Text;
    discord: ?Text;
    medium: ?Text;
  };

  public type NewPriCollectionParamInfo = {
    contentInfo: ContentInfo;
    royaltyRatio: Nat;
    totalSupply: Nat;
    logo: Blob;
    featured: Blob;
    banner: Blob;
  };

  public type NewForkCollectionParamInfo = {
    contentInfo: ContentInfo;
    forkRoyaltyRatio: Nat;
    forkFee: Nat;
    totalSupply: Nat;
    startline: Time.Time;
    deadline: Time.Time;
    whiteListType: Nat;   //0:No whitelist  //1: support Whitelist  //2: only whitelist
    whiteListPrice: ?Nat;
    logo: Blob;
    featured: Blob;
    banner: Blob;
  };

  public type NewCollectionParamInfo = {
    contentInfo: ContentInfo;
    forkRoyaltyRatio: ?Nat;
    forkFee: ?Nat;
    royaltyRatio: ?Nat;
    totalSupply: Nat;
    startline: ?Time.Time;
    deadline: ?Time.Time;
    whiteListType: Nat;   //0:No whitelist  //1: support Whitelist  //2: only whitelist
    whiteListPrice: ?Nat;
    logo: Blob;
    featured: Blob;
    banner: Blob;
  };

  public type CollectionParamInfo = {
    contentInfo: ContentInfo;
    forkRoyaltyRatio: ?Nat;
    forkFee: ?Nat;
    totalSupply: Nat;
    startline: ?Time.Time;
    deadline: ?Time.Time;
    bOpenWhite: Bool;
    whiteListPrice: ?Nat;
    logo: ?Blob;
    featured: ?Blob;
    banner: ?Blob;
  };

  public type CollectionInfo = {
    owner: Principal;
    cid: Principal;
    name: Text;
    desc: Text;
    category: Text;
    forkRoyaltyRatio: ?Nat;
    forkFee: ?Nat;
    totalSupply: Nat;
    bPublic: Bool;
  };

  public type NewCollectionInfo = {
    owner: Principal;
    cid: Principal;
    name: Text;
    desc: Text;
    category: Text;
    totalSupply: Nat;
    collectionType: Nat;
  };

  public type AttrStru = {
    attrIds: [Nat];
  };

  public type NewIPFSItem = {
    //为null表示该collection不支持fork，或者支持fork但是第一次上传token
    parentToken: ?TokenIndex; 
    name: Text;
    desc: Text;
    attrArr: [ComponentAttribute];
    photoLink: ?Text;
    videoLink: ?Text;
    mutablePhotoLink: ?Text;
    earnings: Nat;
    royaltyFeeTo: Principal;
    bFork: Bool;
    passwd: Text;
  };

  public type NewPubItem = {
    name: Text;
    desc: Text;
    photoLink: ?Text;
    videoLink: ?Text;
    earnings: Nat;
    royaltyFeeTo: Principal;
    passwd: Text;
  };

  public type PubNFTMetaData = {
    index: TokenIndex;
    creator: Principal;
    name: Text;
    desc: Text;
    photoLink: ?Text;
    videoLink: ?Text;
    royaltyRatio: Nat;
    royaltyFeeTo: Principal;
  };

  public type PubColSettings = {
    maxRoyaltyRatio: Nat;  
    maxNameSize: Nat;
    maxDescSize: Nat;
    uploadProtocolBaseFee : Nat;
    marketFeeRatio : Nat;
    totalSupply : Nat;
  };

  public type CreatorPubNFTMetaData = {
    owner: ?Principal;
    metaData: PubNFTMetaData;
  };

  public type NewPriItem = {
    name: Text;
    desc: Text;
    attrArr: [ComponentAttribute];
    photoLink: ?Text;
    videoLink: ?Text;
    passwd: Text;
  };

  public type PriNFTMetaData = {
    name: Text;
    desc: Text;
    index: TokenIndex;
    photoLink: ?Text;
    videoLink: ?Text;
    attrIds: [Nat];
  };

  public type CreatorPriNFTMetaData = {
    owner: ?Principal;
    metaData: PriNFTMetaData;
  };

  public type PriColSettings = {
    maxRoyaltyRatio: Nat;  
    maxAttrNum: Nat;
    uploadProtocolBaseFee : Nat;
    marketFeeRatio : Nat;
    totalSupply : Nat;
  };

  public type NewForkItem = {
    parentToken: ?TokenIndex; 
    name: Text;
    desc: Text;
    photoLink: ?Text;
    videoLink: ?Text;
    mutablePhotoLink: ?Text;
    earnings: Nat;
    royaltyFeeTo: Principal;
    bFork: Bool;
    passwd: Text;
  };

  public type NFTMetaData = {
    index: TokenIndex;
    creator: Principal;
    parentToken: ?TokenIndex;
    name: Text;
    desc: Text;
    photoLink: ?Text;
    videoLink: ?Text;
    royaltyRatio: Nat;
    royaltyFeeTo: Principal;
    attrIds: [Nat];
  };

  public type ForkNFTMetaData = {
    index: TokenIndex;
    creator: Principal;
    parentToken: ?TokenIndex;
    desc: Text;
    photoLink: ?Text;
    videoLink: ?Text;
    royaltyRatio: Nat;
    royaltyFeeTo: Principal;
    bFork: Bool;
  };

  public type CreatorForkNFTMetaData = {
    owner: ?Principal;
    metaData: ForkNFTMetaData;
  };

  public type ForkCollectionSettings = {
    maxRoyaltyRatio: Nat;
    maxDescSize: Nat;
    uploadProtocolBaseFee : Nat; 
    uploadProtocolFeeRatio : Nat;
    newItemForkFee : Nat;    
    marketFeeRatio : Nat;     
    forkRoyaltyRatio : Nat;  
    totalSupply : Nat;
    startline : Time.Time;
    deadline : Time.Time;
    mutablePhotoLink : ?Text;
    whiteListType: Nat;
    whiteListPrice: ?Nat;
  };

  public type CollectionSettings = {
    maxRoyaltyRatio: Nat;
    maxDescSize: Nat;
    uploadProtocolBaseFee : Nat; 
    uploadProtocolFeeRatio : Nat;
    newItemForkFee : ?Nat;    
    marketFeeRatio : Nat;     
    forkRoyaltyRatio : ?Nat;  
    totalSupply : Nat;
    startline : ?Time.Time;
    deadline : ?Time.Time;
    mutablePhotoLink : ?Text;
    bOpenWhite: Bool;
    whiteListPrice: ?Nat;
  };

  public type NFTStoreInfo = {
    canisterId: Principal;
    nftIndex: TokenIndex;
    photoLink: Text;
    videoLink: Text;
    nftType: Text;
  };

  public type ComponentAttribute = {
    traitType: Text;
    name: Text;
  };

  public type TokenDetails = {
    id: Nat;
    attrArr: [ComponentAttribute];
  };

  public type GetTokenResponse = Result.Result<TokenDetails, {
    #NotFoundIndex;
  }>;


  public type BuyRequest = {
    tokenIndex:     TokenIndex;
    price:          Nat;
    feeTo:          Principal;
    marketFeeRatio: Nat;
  };

  public type CreateError = {
    #Unauthorized;
    #LessThanFee;
    #InsufficientBalance;
    #AllowedInsufficientBalance;
    #NameAlreadyExit;
    #EarningsTooHigh;
    #NotOwner;
    #SupplyTooLarge;
    #RoyaltyRatioTooHigh;
    #ParamError;
    #NotOnWhiteList;
    #Other;
  };

  public type CreateResponse = Result.Result<Text, CreateError>;

  public type MintError = {
    #Unauthorized;
    #LessThanFee;
    #InsufficientBalance;
    #AllowedInsufficientBalance;
    #Other;
    #NotInWhiteList;
    #NotOwner;
    #ParamError;
    #SupplyUsedUp;
    #IPFSLinkAlreadyExist;
    #TooManyAttr;
    #NoIPFSLink;
    #ForkNotOpen;
  };
  public type MintResponse = Result.Result<TokenIndex,MintError>;

  public type TransferResponse = Result.Result<TokenIndex, {
    #NotOwnerOrNotApprove;
    #NotAllowTransferToSelf;
    #ListOnMarketPlace;
    #Other;
  }>;

  public type BuyResponse = Result.Result<TokenIndex, {
    #Unauthorized;
    #LessThanFee;
    #InsufficientBalance;
    #AllowedInsufficientBalance;
    #NotFoundIndex;
    #NotAllowBuySelf;
    #AlreadyTransferToOther;
    #Other;
  }>;

  public type ListRequest = {
    tokenIndex : TokenIndex;
    price : Nat;
  };

  public type Listings = { 
    tokenIndex : TokenIndex; 
    seller : Principal; 
    price : Nat;
    time : Time.Time;
  };

  public type SoldListings = {
    lastPrice : Nat;
    time : Time.Time;
    account : Nat;
  };

  public type Operation = {
    #Mint;
    #List;
    #UpdateList;
    #CancelList;
    #Sale;
    #Transfer;
    #Bid;
  };

  public type OpRecord = {
    op: Operation;
    price: ?Nat;
    from: ?Principal;
    to: ?Principal;
    timestamp: Time.Time;
  };

  public type SaleRecord = {
    tokenIndex: TokenIndex;
    price: ?Nat;
    from: ?Principal;
    to: ?Principal;
    photoLink: ?Text;
    videoLink: ?Text;
    timestamp: Time.Time;
  };

  public type ListResponse = Result.Result<TokenIndex, {
    #NotOwner;
    #NotFoundIndex;
    #AlreadyList;
    #NotApprove;
    #NotNFT;
    #SamePrice;
    #NotOpenList;
    #Other;
  }>;

  public module TokenIndex = {
    public func equal(x : TokenIndex, y : TokenIndex) : Bool {
      x == y
    };
    public func hash(x : TokenIndex) : Hash.Hash {
      Text.hash(Nat.toText(x))
    };
  };

  public module NFTStoreInfo = {
    public func equal(x : NFTStoreInfo, y : NFTStoreInfo) : Bool {
      x.canisterId == y.canisterId and x.nftIndex == y.nftIndex
    };
    public func hash(x : NFTStoreInfo) : Hash.Hash {
      Text.hash(Principal.toText(x.canisterId) # Nat.toText(x.nftIndex))
    };
    public func compare(x : NFTStoreInfo, y : NFTStoreInfo) : { #less; #equal; #greater } {
      if (x.canisterId < y.canisterId) { #less }
      else if(x.canisterId == y.canisterId and x.nftIndex < y.nftIndex) { #less }
      else if (x.canisterId == y.canisterId and x.nftIndex == y.nftIndex) { #equal }
      else { #greater }
    };
  };

  public module ComponentAttribute = {
    public func equal(x : ComponentAttribute, y : ComponentAttribute) : Bool {
      x.traitType == y.traitType and x.name == y.name
    };
    public func hash(x : ComponentAttribute) : Hash.Hash {
      Text.hash(x.traitType # x.name)
    };
  };

}

