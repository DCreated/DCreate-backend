//ccc modules

use candid::{CandidType, Decode, Encode, Int, Nat};
use ic_agent::{ic_types::Principal, Agent};

use ic_agent::identity::BasicIdentity;
use log::*;

use garcon::Delay;
use std::fs::{File, OpenOptions};
use std::io::{Read, Write};
use candid::parser::token::error;
use std::cmp::min;
use chrono::Local;
use crate::{ContentInfo, CreateCollectionParam};
use serde::{Serialize,Deserialize};

//做trait、兼容所有canister
#[derive(Clone)]
pub struct Accessor {
    agent: ic_agent::Agent,
    waiter: Delay,
    pub caller: Principal,
}

#[derive(Clone, Debug, PartialEq, Eq, Hash, Deserialize, CandidType)]
pub enum Operation {
    #[serde(rename = "mint")]
    Mint,
    #[serde(rename = "burn")]
    Burn,
    #[serde(rename = "transfer")]
    Transfer,
    #[serde(rename = "batchTransfer")]
    BatchTransfer,
    #[serde(rename = "approve")]
    Approve,
}

#[derive(CandidType, Deserialize, Debug)]
pub struct OpRecord {
    pub caller: Principal,
    pub op: Operation,
    pub index: Nat,
    pub from: Option<Principal>,
    pub to: Option<Principal>,
    pub amount: Nat,
    pub fee: Nat,
    pub timestamp: Int,
}

#[derive(CandidType, Deserialize, Debug)]
pub struct TextInfo {
    pub name: String,
    pub bio: String,
    pub link: String,
}

#[derive(CandidType, Deserialize, Debug)]
pub struct ProfileInfo {
    pub text_info: TextInfo,
    pub avatar: Option<Vec<u8>>,
}


/***
 public type CreateResponse = Result.Result<Text, {
    #Unauthorized;
    #LessThanFee;
    #InsufficientBalance;
    #AllowedInsufficientBalance;
    #NameAlreadyExit;
    #EarningsTooHigh;
    #NotOwner;
    #NotSetDataUser;
    #Other;
  }>;
*/

#[derive(CandidType, Deserialize, Debug)]
enum CreateCollectionError {
    #[serde(rename = "Unauthorized")]
    Unauthorized,
    #[serde(rename = "LessThanFee")]
    LessThanFee,
    #[serde(rename = "InsufficientBalance")]
    InsufficientBalance,
    #[serde(rename = "AllowedInsufficientBalance")]
    AllowedInsufficientBalance,
    #[serde(rename = "NameAlreadyExit")]
    NameAlreadyExit,
    #[serde(rename = "EarningsTooHigh")]
    EarningsTooHigh,
    #[serde(rename = "NotOwner")]
    NotOwner,
    #[serde(rename = "NotSetDataUser")]
    NotSetDataUser,
    #[serde(rename = "Other")]
    Other,
}

#[derive(CandidType, Deserialize, Debug)]
enum CreateCollectionResult {
    #[serde(rename = "ok")]
    Success(String),
    #[serde(rename = "err")]
    Error(CreateCollectionError),
}

#[derive(CandidType,Clone, Deserialize, Debug, PartialEq, Serialize)]
pub struct CreateCollectionParam2 {
    pub logo: Option<Vec<u8>>,
    pub featured: Option<Vec<u8>>,
    pub banner: Option<Vec<u8>>,
    #[serde(rename = "contentInfo")]
    pub content_info: ContentInfo,
}

impl Accessor {
    pub async fn new(identity: BasicIdentity, network: &str) -> Result<Accessor, Box<dyn std::error::Error>> {
        let agent = Agent::builder()
            .with_url(network)
            .with_identity(identity)
            .build()?;
        let caller = agent.get_principal().unwrap();
        agent.fetch_root_key().await?;
        let waiter = garcon::Delay::builder()
            .throttle(std::time::Duration::from_millis(500))
            .timeout(std::time::Duration::from_secs(60 * 5))
            .build();
        Ok(Accessor {
            agent,
            waiter,
            caller,
        })
    }
    //todo:区别容器内asset和http网络异常
    async fn retry_call(&self, canister_id: &str, method: &str, raw_argument: Vec<u8>) -> Vec<u8> {
        let canister_id = Principal::from_text(canister_id).unwrap();
        loop {
            let call_result = self
                .agent
                .update(&canister_id, method)
                .with_arg(&raw_argument)
                .call_and_wait(self.waiter.clone())
                .await;

            match call_result {
                Ok(raw_data) => return raw_data,
                Err(error) => {
                    error!(
                        "Call {} method {} failed {:?},wait 10s and then call it again",
                        canister_id, method, error
                    );
                    std::thread::sleep(std::time::Duration::from_secs(5));
                    continue;
                }
            }
        }
    }

    pub async fn upload_collection_info(
        &self,
        info: &CreateCollectionParam,
        canister_id: &str
    ) -> Result<(), Box<dyn std::error::Error>> {
        let load_image = |path: &str| {
            Option::from({
                let mut data = Vec::<u8>::new();
                let _res = File::open(path)
                    .unwrap()
                    .read_to_end(&mut data)
                    .unwrap();
                data
            })
        };
        let banner_data = info.banner.as_ref().and_then(|path| load_image(path));
        let featured_data = info.featured.as_ref().and_then(|path| load_image(path));
        let logo_data = info.logo.as_ref().and_then(|path| load_image(path));


        let create_info = CreateCollectionParam2 {
            logo: logo_data,
            featured: featured_data,
            banner: banner_data,
            content_info: info.content_info.clone()
        };

        let start = Local::now().timestamp_millis() as u64;
        let response = self
            .retry_call(
                canister_id,
                "createNewCollection",
                Encode!(&create_info)?,
            )
            .await;
        let end = Local::now().timestamp_millis() as u64;
        println!("upload consume {} ms", end - start);

        let res = Decode!(response.as_slice(),CreateCollectionResult ).unwrap();
        match res {
            CreateCollectionResult::Success(x) => {
                info!("create collection success,respond {}",x);
            }
            CreateCollectionResult::Error(error) => {
                info!("create collection failed {:?}", error);
            }
            _ => {}
        };
        Ok(())
    }
}
