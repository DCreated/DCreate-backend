#!/bin/sh
dfx canister --network ic  call ICCreateFactory setDataUser '(principal "7wzuu-moji4-ekxtu-rux6w-57vvq-i2qq2-iz5oe-c5rzc-kzl72-awzfj-wae")'
dfx canister --network ic  call ICCreateFactory setbPublic '(true)'

(cd ic_create_call;cargo run  /Users/eddy/.config/dfx/identity/eddy2/identity.pem https://boundary.ic0.app vqvbt-iqaaa-aaaai-qmika-cai  new_collection)

