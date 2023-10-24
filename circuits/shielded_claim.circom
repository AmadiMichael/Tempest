pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "./components/merkleTreeComponent.circom";
include "./components/depositComponent.circom";
include "./components/withdrawComponent.circom";


// here we assume that oldRoot is the immediate last root and is what the user is inserting the change commitment hash into
template ShieldedClaim(levels) {
    // public inputs
    signal input oldRoot;
    signal input nullifierHash;
    signal input changeCommitmentHash;
    signal input newRoot;

    // private inputs
    signal input denomination;
    signal input nullifier;
    signal input changeNullifier;
    signal input pathElements[levels];
    signal input pathIndices[levels];
    
    signal input topNodes[2]; // two hashes that hash up to oldRoot
    signal input afterPathElements[levels];
    signal input afterPathIndices[levels];


    // prove you know the preimage of the nullifier hash
    // prove that same nullifier and denomination generate the right commitmenthash
    // prove commitment hash is in the tree and oldRoot is the root of the private path elements
    component withdraw = ShieldedWithdraw(levels);
    withdraw.root <== oldRoot;
    withdraw.nullifierHash <== nullifierHash;
    withdraw.denomination <== denomination;
    withdraw.nullifier <== nullifier;
    for (var i = 0; i < levels; i++) {
        withdraw.pathElements[i] <== pathElements[i];
        withdraw.pathIndices[i] <== pathIndices[i];
    }


    // prove addition of new note commitment hash to the immediate past note
    component deposit = Deposit(20);
    deposit.oldRoot <== oldRoot;
    deposit.commitmentHash <== changeCommitmentHash;
    deposit.denomination <== denomination;
    deposit.root <== newRoot;
    deposit.nullifier <== changeNullifier;
    deposit.topNodes[0] <== topNodes[0];
    deposit.topNodes[1] <== topNodes[1];
    for (var i = 0; i < levels; i++) {
        deposit.pathElements[i] <== afterPathElements[i];
        deposit.pathIndices[i] <== afterPathIndices[i];
    }
}

component main {public [oldRoot,nullifierHash,changeCommitmentHash,newRoot]} = ShieldedClaim(20);
