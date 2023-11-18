pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "./components/merkleTreeComponent.circom";
include "./components/depositComponent.circom";
include "./components/withdrawComponent.circom";


// here we assume that oldRoot is the immediate last root and is what the user is inserting the change commitment hash into
// partial withdrawal works by making a full withdrawal and redepositing the balances
template PartialWithdraw(levels) {
    // public inputs
    signal input oldRoot;
    signal input nullifierHash;
    signal input amount;
    signal input changeCommitmentHash;
    signal input newRoot;
    signal input recipient; // not taking part in any computations
    signal input relayer;  // not taking part in any computations
    signal input fee;      // not taking part in any computations

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
    component withdraw = Withdraw(levels);
    withdraw.root <== oldRoot;
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


    // prove amount <= denomination
    component lte = LessEqThan(252);
    lte.in[0] <== amount;
    lte.in[1] <== denomination;
    lte.out === 1;

    // prove amount > 0 
    component gt = GreaterThan(252);
    gt.in[0] <== amount;
    gt.in[1] <== 0;
    gt.out === 1;
    

    // prove addition of new note (change) commitment hash to the current tree
    component deposit = Deposit(20);
    deposit.oldRoot <== oldRoot;
    deposit.commitmentHash <== changeCommitmentHash;
    deposit.denomination <== denomination - amount;
    deposit.root <== newRoot;
    deposit.nullifier <== changeNullifier;
    deposit.topNodes[0] <== topNodes[0];
    deposit.topNodes[1] <== topNodes[1];
    for (var i = 0; i < levels; i++) {
        deposit.pathElements[i] <== afterPathElements[i];
        deposit.pathIndices[i] <== afterPathIndices[i];
    }
}

component main {public [oldRoot,nullifierHash,amount,changeCommitmentHash,newRoot,recipient,relayer,fee]} = PartialWithdraw(20);
