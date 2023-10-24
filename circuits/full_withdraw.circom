pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "./components/merkleTreeComponent.circom";
include "./components/withdrawComponent.circom";


template FullWithdraw(levels) {
    // public inputs
    signal input root;
    signal input nullifierHash;
    signal input denomination;
    signal input recipient; // not taking part in any computations
    signal input relayer;  // not taking part in any computations
    signal input fee;      // not taking part in any computations

    // private inputs
    signal input nullifier;
    signal input pathElements[levels];
    signal input pathIndices[levels];


    // prove you know the preimage of the nullifier hash
    // prove that same nullifier and denomination generate the right commitmenthash
    // prove commitment hash is in the tree and oldRoot is the root of the private path elements
    component withdraw = Withdraw(levels);
    withdraw.root <== root;
    withdraw.nullifierHash <== nullifierHash;
    withdraw.denomination <== denomination;
    withdraw.recipient <== recipient;
    withdraw.relayer <== relayer;
    withdraw.fee <== fee;
    withdraw.nullifier <== nullifier;
    for (var i = 0; i < levels; i++) {
        withdraw.pathElements[i] <== pathElements[i];
        withdraw.pathIndices[i] <== pathIndices[i];
    }
}

component main {public [root,nullifierHash,denomination,recipient,relayer,fee]} = FullWithdraw(20);