pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "merkleTreeComponent.circom";
include "depositComponent.circom";


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


    // used to get the leaf index of a leaf based on the pathIndices given
    component leafIndexNum = Bits2Num(levels);
    for (var i = 0; i < levels; i++) {
        leafIndexNum.in[i] <== pathIndices[i];
    }


    // prove you know the preimage of the nullifier hash
    component nullifierHasher = Poseidon(4);
    nullifierHasher.inputs[0] <== nullifier;
    nullifierHasher.inputs[1] <== 1;
    nullifierHasher.inputs[2] <== leafIndexNum.out;
    nullifierHasher.inputs[3] <== denomination;
    nullifierHasher.out === nullifierHash;


    // prove that same nullifier and denomination generate the right commitmenthash
    component commitmentHasher = Poseidon(3);
    commitmentHasher.inputs[0] <== nullifier;
    commitmentHasher.inputs[1] <== 0;
    commitmentHasher.inputs[2] <== denomination;


    // prove commitment hash is in the tree and oldRoot is the root of the private path elements
    component tree = MerkleTreeChecker(levels);
    tree.leaf <== commitmentHasher.out;
    tree.root <== oldRoot;
    for (var i = 0; i < levels; i++) {
        tree.pathElements[i] <== pathElements[i];
        tree.pathIndices[i] <== pathIndices[i];
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
