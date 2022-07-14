import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Hash "mo:base/Hash";
import Nat32 "mo:base/Nat32";
import Char "mo:base/Char";
import Float "mo:base/Float";

module Types = {

    //Http Request and Response
    public type HttpRequest = {
        body: Blob;
        headers: [HeaderField];
        method: Text;
        url: Text;
    };

    public type HeaderField = (Text, Text);

    public type HttpResponse = {
        body: Blob;
        headers: [HeaderField];
        status_code: Nat16;
        streaming_strategy: ?StreamingStrategy;
    };
  
    public type StreamingCallbackToken =  {
        content_encoding: Text;
        index: Nat;
        key: Text;
        sha256: ?Blob;
    };

    public type StreamingStrategy = {
        #Callback: {
            callback: query (StreamingCallbackToken) -> async (StreamingCallbackResponse);
            token: StreamingCallbackToken;
        };
    };

    public type StreamingCallbackResponse = {
        body: Blob;
        token: ?StreamingCallbackToken;
    };

    public func textToNat( txt : Text) : Nat {
        assert(txt.size() > 0);
        let chars = txt.chars();

        var num : Nat = 0;
        for (v in chars){
            let charToNum = Nat32.toNat(Char.toNat32(v)-48);
            assert(charToNum >= 0 and charToNum <= 9);
            num := num * 10 +  charToNum;          
        };

        num;
    };

    public func streamContent(
            key   : Text,
            index : Nat,
            data  : [Blob],
        ) : StreamingCallbackResponse {
        let (payload, cbt) = _streamContent(
                key,
                index,
                data,
        );

        {
            body  = payload;
            token = cbt;
        };
    };

    private func _streamContent(
        key   : Text,
        index : Nat,
        data  : [Blob],
    ) : (
        Blob,                        // Payload based on the index.
        ?StreamingCallbackToken // Callback for next chunk (if applicable).
    ) {
        let payload = data[index];
        if (index + 1 == data.size()) return (payload, null);
        (payload, ?{
            content_encoding = "gzip";
            index            = index + 1;
            key              = key;
            sha256 = null;
        });
    };

}

