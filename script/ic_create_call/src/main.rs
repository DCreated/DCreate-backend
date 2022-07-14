#![feature(drain_filter)]
//#![deny(warnings)]
#![allow(unused)]



pub mod canister;
pub mod identity;

use std::borrow::Borrow;
use std::path::Path;
use rand::Rng;
use candid::{CandidType, Decode, Encode, Int, Nat};
use image::imageops::overlay;
use image::io::Reader as ImageReader;
use image::{GenericImage, GenericImageView, ImageFormat, Rgba};
use image::{Rgb, RgbImage};
use imageproc::drawing::draw_text_mut;
use std::fs::{File as fsFile, OpenOptions};
use std::collections::{BTreeMap, HashMap};
use std::io::{BufReader, BufWriter};
use std::ops::{Deref, DerefMut};
use chrono::Local;
use clap::{App, Arg};
use log::info;
use png::DisposeOp::Background;
use serde::{Deserialize, Serialize};
use tokio::runtime::Runtime;
use crate::canister::Accessor;
use config::{Config, File};

/***
name: Text;
    desc: Text;
    category: Text;
    webLink: ?Text;
    twitter: ?Text;
    discord: ?Text;
    medium: ?Text;
*/
#[derive(CandidType,Clone, Deserialize, Debug, PartialEq, Serialize)]
pub struct ContentInfo {
    pub name: String,
    pub desc: String,
    pub category: String,
    pub webLink: Option<String>,
    pub twitter: Option<String>,
    pub discord: Option<String>,
    pub medium: Option<String>

}



#[derive(Clone, Deserialize, Debug, PartialEq, Serialize)]
pub struct CreateCollectionParam {
    pub logo: Option<String>,
    pub featured: Option<String>,
    pub banner: Option<String>,
    pub content_info: ContentInfo
}



#[async_std::main]
#[paw::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();
    //let pem_path = "/Users/eddy/.config/dfx/identity/eddy/identity.pem";
    //let pem_path = "/root/.config/dfx/identity/eddy/identity.pem";
    let matches = App::new("Hellman")
        .version("1.0")
        .about("Does awesome things")
        .arg(Arg::new("pem_path")
            .about("Sets the pem file to use")
            .required(true)
            .index(1))
        .arg(Arg::new("network")
            .about("network")
            .required(true)
            .index(2))
        .arg(Arg::new("canister_id")
            .about("canister_id")
            .required(true)
            .index(3))
        .subcommand(App::new("new_collection")
            .arg(Arg::new("config_file")
                .about("Sets the canister id to use")
                .required(false)
                .index(1))
        )
        .get_matches();

    let pem_path = matches.value_of("pem_path").unwrap();
    //https://boundary.ic0.app
    let network = matches.value_of("network").unwrap();
    let canister = matches.value_of("canister_id").unwrap();


    match matches.subcommand() {
        Some(("new_collection", sub_matcher)) => {
            let config_file = sub_matcher.value_of("config_file");
            let file_path = config_file.unwrap_or("./collections.json");
            let file = fsFile::open(file_path).unwrap();
            let reader = BufReader::new(file);
            let collections: Vec<CreateCollectionParam> =
                serde_json::from_reader(reader).expect("JSON was not well-formatted");
            info!("dist_tokens = {:?}",collections);
            let rt = Runtime::new().unwrap();
            rt.block_on(async move {
                let identity = identity::get_identity(pem_path);
                let access = Accessor::new(identity, network).await.unwrap();
                for collection in collections {
                    info!("start upload collection {}",collection.content_info.name);
                    access.upload_collection_info(&collection,canister).await;
                    info!("finished upload collection {}",collection.content_info.name);
                }
            });
        }
        _ => {
            info!("not support")
        }
    }
    Ok(())
}