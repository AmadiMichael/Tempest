# Use existing public phase 1 setup
PHASE1=build/phase1_final.ptau
PHASE2=build/phase2_final.ptau
DEPOSIT_CIRCUIT_ZKEY=build/deposit_circuit_final.zkey
PARTIAL_WITHDRAW_CIRCUIT_ZKEY=build/partial_withdraw_circuit_final.zkey
FULL_WITHDRAW_CIRCUIT_ZKEY=build/full_withdraw_circuit_final.zkey
SHIELDED_TRANSFER_CIRCUIT_ZKEY=build/shielded_transfer_circuit_final.zkey
SHIELDED_CLAIM_CIRCUIT_ZKEY=build/shielded_claim_circuit_final.zkey


# Phase 1
if [ -f "$PHASE1" ]; then
    echo "Phase 1 file exists, no action"
else
    echo "Phase 1 file does not exist, downloading ..."
    curl -o $PHASE1 https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_15.ptau
fi

# Untrusted phase 2
npx snarkjs powersoftau prepare phase2 $PHASE1 $PHASE2 -v

npx snarkjs zkey new build/deposit.r1cs $PHASE2 $DEPOSIT_CIRCUIT_ZKEY
npx snarkjs zkey new build/partial_withdraw.r1cs $PHASE2 $PARTIAL_WITHDRAW_CIRCUIT_ZKEY
npx snarkjs zkey new build/full_withdraw.r1cs $PHASE2 $FULL_WITHDRAW_CIRCUIT_ZKEY
npx snarkjs zkey new build/shielded_transfer.r1cs $PHASE2 $SHIELDED_TRANSFER_CIRCUIT_ZKEY
npx snarkjs zkey new build/shielded_claim.r1cs $PHASE2 $SHIELDED_CLAIM_CIRCUIT_ZKEY

npx snarkjs zkey export verificationkey $DEPOSIT_CIRCUIT_ZKEY build/deposit_verification_key.json
npx snarkjs zkey export verificationkey $PARTIAL_WITHDRAW_CIRCUIT_ZKEY build/partial_withdraw_verification_key.json
npx snarkjs zkey export verificationkey $FULL_WITHDRAW_CIRCUIT_ZKEY build/full_withdraw_verification_key.json
npx snarkjs zkey export verificationkey $SHIELDED_TRANSFER_CIRCUIT_ZKEY build/shielded_transfer_verification_key.json
npx snarkjs zkey export verificationkey $SHIELDED_CLAIM_CIRCUIT_ZKEY build/shielded_claim_verification_key.json

npx snarkjs zkey export solidityverifier $DEPOSIT_CIRCUIT_ZKEY build/DepositVerifier.sol
npx snarkjs zkey export solidityverifier $PARTIAL_WITHDRAW_CIRCUIT_ZKEY build/PartialWithdrawVerifier.sol
npx snarkjs zkey export solidityverifier $FULL_WITHDRAW_CIRCUIT_ZKEY build/FullWithdrawVerifier.sol
npx snarkjs zkey export solidityverifier $SHIELDED_TRANSFER_CIRCUIT_ZKEY build/ShieldedTransferVerifier.sol
npx snarkjs zkey export solidityverifier $SHIELDED_CLAIM_CIRCUIT_ZKEY build/ShieldedClaimVerifier.sol
