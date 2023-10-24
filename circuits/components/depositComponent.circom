pragma circom 2.0.0;

include "merkleTreeComponent.circom";



template OldRootCircuit() {
    signal input oldRoot;
    signal input topNodes[2];
    
    component commitmentHasher = Poseidon(2);
    commitmentHasher.inputs[0] <== topNodes[0];
    commitmentHasher.inputs[1] <== topNodes[1];
    commitmentHasher.out === oldRoot;
}


// oldRoot = poseidon(topLeft, topRight) i.e you know the correct path to the oldRoot
// pathElements[19] == topNodes[0] | topNodes[1] i.e that correct path is what you parsed to the circuit
// root = oldRoot.insert(commitmentHash) when insert() returns the new root i.e when added to that correct path, yields the new root parsed to the circuit
template Deposit(levels) {
    // Public inputs
    signal input oldRoot; // depositor computed root
    signal input commitmentHash; // depositor commitment hash
    signal input denomination; // amount deposited
    signal input root; // depositor computed root

    // private inputs
    signal input nullifier; // nullifier of commitment hash
    signal input topNodes[2]; // two hashes that hash up to oldRoot
    signal input pathElements[levels]; // sibling nodes
    signal input pathIndices[levels]; // leafIndexNum
    


    // prove that same nullifier and denomination generate the right commitmenthash
    component commitmentHasher = Poseidon(3);
    commitmentHasher.inputs[0] <== nullifier;
    commitmentHasher.inputs[1] <== 0;
    commitmentHasher.inputs[2] <== denomination;
    commitmentHasher.out === commitmentHash;


    // ensure pathElements[19] === topLeft or pathElements[19] === topRight
    signal isPathElement19Checker;
    isPathElement19Checker <== (topNodes[0] - pathElements[19]) * (topNodes[1] - pathElements[19]);
    isPathElement19Checker === 0;


    // ensure oldRoot === poseidon(topLeft, topRight)
    component oldRootCircuit = OldRootCircuit();
    oldRootCircuit.oldRoot <== oldRoot;
    oldRootCircuit.topNodes[0] <== topNodes[0];
    oldRootCircuit.topNodes[1] <== topNodes[1];


    // ensure root === tree.insert(commitmentHash) assuming insert() returns the new root
    component tree = MerkleTreeChecker(levels);
    tree.leaf <== commitmentHash;
    tree.root <== root;
    for (var i = 0; i < levels; i++) {
        tree.pathElements[i] <== pathElements[i];
        tree.pathIndices[i] <== pathIndices[i];
    }
}