pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "merkleTreeComponent.circom";



template Withdraw(levels) {
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


    // prove commitment hash is in the tree and root is the root of the private path elements
    component tree = MerkleTreeChecker(levels);
    tree.leaf <== commitmentHasher.out;
    tree.root <== root;
    for (var i = 0; i < levels; i++) {
        tree.pathElements[i] <== pathElements[i];
        tree.pathIndices[i] <== pathIndices[i];
    }


    // Add hidden signals to make sure that tampering with recipient or fee will invalidate the snark proof
    // Most likely it is not required, but it's better to stay on the safe side and it only takes 2 constraints
    // Squares are used to prevent optimizer from removing those constraints
    signal recipientSquare;
    signal feeSquare;
    signal relayerSquare;
    recipientSquare <== recipient * recipient;
    feeSquare <== fee * fee;
    relayerSquare <== relayer * relayer;
}






template ShieldedWithdraw(levels) {
    // public inputs
    signal input root;
    signal input nullifierHash;
    signal input denomination;

    // private inputs
    signal input nullifier;
    signal input pathElements[levels];
    signal input pathIndices[levels];


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


    // prove commitment hash is in the tree and root is the root of the private path elements
    component tree = MerkleTreeChecker(levels);
    tree.leaf <== commitmentHasher.out;
    tree.root <== root;
    for (var i = 0; i < levels; i++) {
        tree.pathElements[i] <== pathElements[i];
        tree.pathIndices[i] <== pathIndices[i];
    }
}