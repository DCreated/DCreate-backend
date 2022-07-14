use ic_agent::identity::BasicIdentity;

use std::path::Path;

pub fn create_identity() -> BasicIdentity {
    let rng = ring::rand::SystemRandom::new();
    let key_pair = ring::signature::Ed25519KeyPair::generate_pkcs8(&rng)
        .expect("Could not generate a key pair.");
    let identity = BasicIdentity::from_key_pair(
        ring::signature::Ed25519KeyPair::from_pkcs8(key_pair.as_ref())
            .expect("Could not read the key pair."),
    );
    identity
}

pub fn get_identity(pem_path: &str) -> BasicIdentity {
    BasicIdentity::from_pem_file(Path::new(pem_path)).unwrap()
}
