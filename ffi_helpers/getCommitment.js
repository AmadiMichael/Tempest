const { ethers } = require("ethers");
const {
  Contract,
  ContractFactory,
  BigNumber,
  BigNumberish,
} = require("ethers");
const { poseidonContract, buildPoseidon } = require("circomlibjs");

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

class Deposit {
  constructor(poseidon, leafIndex, denomination) {
    this.poseidon = poseidon;
    this.nullifier = ethers.utils.randomBytes(15);
    this.denomination = denomination;
    this.leafIndex = leafIndex;
  }

  get commitment() {
    return poseidonHash(this.poseidon, [this.nullifier, 0, this.denomination]);
  }

  get nullifierHash() {
    if (!this.leafIndex && this.leafIndex !== 0)
      throw Error("leafIndex is unset yet");
    return poseidonHash(this.poseidon, [
      this.nullifier,
      1,
      this.leafIndex,
      this.denomination,
    ]);
  }
}

async function getCommitment(leafIndex, denomination) {
  let poseidon = await buildPoseidon();
  let deposit = new Deposit(poseidon, leafIndex, denomination);
  console.log(
    ethers.utils.defaultAbiCoder.encode(
      ["bytes32", "bytes32", "bytes32"],
      [
        deposit.commitment,
        deposit.nullifierHash,
        ethers.utils.hexZeroPad(deposit.nullifier, 32),
      ]
    )
  );
}

getCommitment(parseInt(process.argv[2]), process.argv[3]);
