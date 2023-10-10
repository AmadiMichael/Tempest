const { MerkleTree } = require("./merkleTree.js");
const { ethers } = require("ethers");
const {
  Contract,
  ContractFactory,
  BigNumber,
  BigNumberish,
} = require("ethers");
const { poseidonContract, buildPoseidon } = require("circomlibjs");
const path = require("path");
const { groth16 } = require("snarkjs");

function poseidonHash(poseidon, inputs) {
  const hash = poseidon(inputs.map((x) => BigNumber.from(x).toBigInt()));
  // Make the number within the field size
  const hashStr = poseidon.F.toString(hash);
  // Make it a valid hex string
  const hashHex = BigNumber.from(hashStr).toHexString();
  // pad zero to make it 32 bytes, so that the output can be taken as a bytes32 contract argument
  const bytes32 = ethers.utils.hexZeroPad(hashHex, 32);
  return bytes32;
}

class PoseidonHasher {
  poseidon;

  constructor(poseidon) {
    this.poseidon = poseidon;
  }

  hash(left, right) {
    return poseidonHash(this.poseidon, [left, right]);
  }
}

async function prove(witness) {
  const wasmPath = path.join(
    __dirname,
    "../build/partial_withdraw_js/partial_withdraw.wasm"
  );
  const zkeyPath = path.join(
    __dirname,
    "../build/partial_withdraw_circuit_final.zkey"
  );

  const { proof } = await groth16.fullProve(witness, wasmPath, zkeyPath);

  const solProof = {
    a: [proof.pi_a[0], proof.pi_a[1]],
    b: [
      [proof.pi_b[0][1], proof.pi_b[0][0]],
      [proof.pi_b[1][1], proof.pi_b[1][0]],
    ],
    c: [proof.pi_c[0], proof.pi_c[1]],
  };
  return solProof;
}

async function getProve(
  height,
  leafIndex,
  newLeafIndex,
  nullifier,
  changeNullifier,
  nullifierHash,
  changeCommitmentHash,
  denomination,
  recipient,
  amount,
  relayer,
  fee,
  _pushedCommitments
) {
  let poseidon = await buildPoseidon();

  const tree = new MerkleTree(height, "test", new PoseidonHasher(poseidon));

  const pushedCommitments = ethers.utils.defaultAbiCoder.decode(
    ["bytes32[]"],
    _pushedCommitments
  )[0];

  for (let i = 0; i < pushedCommitments.length; i++) {
    await tree.insert(pushedCommitments[i]);
  }

  const {
    root: oldRoot,
    path_elements,
    path_index,
  } = await tree.path(leafIndex);

  const topNodes = await tree.getTopTwoElements();
  const x = await tree.path(newLeafIndex);

  await tree.insert(changeCommitmentHash);
  const newRoot = await tree.root();

  const witness = {
    // Public
    oldRoot,
    nullifierHash,
    amount,
    changeCommitmentHash,
    newRoot,
    recipient,
    relayer,
    fee,

    // Private
    denomination,
    nullifier: BigNumber.from(nullifier).toBigInt(),
    changeNullifier: BigNumber.from(changeNullifier).toBigInt(),
    pathElements: path_elements,
    pathIndices: path_index,
    topNodes,
    afterPathElements: x.path_elements,
    afterPathIndices: x.path_index,
  };

  // console.log(witness);

  const solProof = await prove(witness);

  console.log(
    ethers.utils.defaultAbiCoder.encode(
      [
        "uint256",
        "uint256",
        "uint256",
        "uint256",
        "uint256",
        "uint256",
        "uint256",
        "uint256",
        "bytes32",
        "bytes32",
      ],
      [
        solProof.a[0],
        solProof.a[1],
        solProof.b[0][0],
        solProof.b[0][1],
        solProof.b[1][0],
        solProof.b[1][1],
        solProof.c[0],
        solProof.c[1],
        oldRoot,
        newRoot,
      ]
    )
  );

  // it doesn't return so use this to return
  process.exit(0);
}

getProve(
  parseInt(process.argv[2]),
  parseInt(process.argv[3]),
  parseInt(process.argv[4]),
  process.argv[5],
  process.argv[6],
  process.argv[7],
  process.argv[8],
  process.argv[9],
  process.argv[10],
  process.argv[11],
  process.argv[12],
  parseInt(process.argv[13]),
  process.argv[14]
);
