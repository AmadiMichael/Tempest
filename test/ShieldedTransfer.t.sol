// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Shared, Proof, ShieldedTransferStruct, ShieldedClaimStruct} from "./Shared.sol";

contract ShieldedTransferTest is Shared {
    function start()
        private
        returns (
            address sender,
            address receiver,
            bytes32 commitment,
            bytes32 nullifierHash,
            bytes32 nullifier,
            GetShieldedTransferProofReturnStruct memory senderShieldedTransferProofReturnStruct,
            GetShieldedClaimProofReturnStruct memory getShieldedClaimProofReturnStruct
        )
    {
        sender = address(bytes20(keccak256("sender")));
        receiver = address(bytes20(keccak256("receiver")));
        (commitment, nullifierHash, nullifier) = depositAndAssert(sender, 0, new bytes32[](0), 10 ether);

        // shielded transfer
        // sender creates proof
        bytes32[] memory pushedCommitments = new bytes32[](1);
        pushedCommitments[0] = commitment;
        (senderShieldedTransferProofReturnStruct) =
            getShieldedTransferProof(0, 1, nullifier, nullifierHash, 10 ether, 1.5 ether, pushedCommitments);

        // reciever creates proof too
        bytes32[] memory pushedCommitments2 = new bytes32[](3);
        pushedCommitments2[0] = commitment;
        pushedCommitments2[1] = senderShieldedTransferProofReturnStruct.changeCommitmentHash;
        pushedCommitments2[2] = senderShieldedTransferProofReturnStruct.destCommitmentHash;
        (getShieldedClaimProofReturnStruct) = getShieldedClaimProve(
            2,
            3,
            senderShieldedTransferProofReturnStruct.destNullifier,
            senderShieldedTransferProofReturnStruct.destNullifierHash,
            1.5 ether,
            pushedCommitments2
        );
    }

    function test_deposit_shielded_transfer_and_partial_withdraw() external {
        (
            ,
            address receiver,
            bytes32 commitment,
            bytes32 nullifierHash,
            ,
            GetShieldedTransferProofReturnStruct memory senderShieldedTransferProofReturnStruct,
            GetShieldedClaimProofReturnStruct memory getShieldedClaimProofReturnStruct
        ) = start();

        shieldedTransferAndAssert(
            receiver,
            ShieldedTransferStruct(
                senderShieldedTransferProofReturnStruct.proof,
                senderShieldedTransferProofReturnStruct.rootBefore,
                nullifierHash,
                senderShieldedTransferProofReturnStruct.changeCommitmentHash,
                senderShieldedTransferProofReturnStruct.destCommitmentHash,
                senderShieldedTransferProofReturnStruct.rootAfterAddingChangeToTree,
                senderShieldedTransferProofReturnStruct.rootAfterAddingDestToTree
            ),
            ShieldedClaimStruct(
                getShieldedClaimProofReturnStruct.proof,
                senderShieldedTransferProofReturnStruct.destNullifierHash,
                getShieldedClaimProofReturnStruct.changeCommitmentHash,
                getShieldedClaimProofReturnStruct.rootAfter
            ),
            bytes("")
        );

        bytes32[] memory pushedCommitments3 = new bytes32[](4);
        pushedCommitments3[0] = commitment;
        pushedCommitments3[1] = senderShieldedTransferProofReturnStruct.changeCommitmentHash;
        pushedCommitments3[2] = senderShieldedTransferProofReturnStruct.destCommitmentHash;
        pushedCommitments3[3] = getShieldedClaimProofReturnStruct.changeCommitmentHash;
        (,, bytes32 commitment2, bytes32 nullifierHash2, bytes32 nullifier2) = partialWithdrawAndAssert(
            PartialWithdrawStruct(
                receiver,
                1.5 ether,
                1.2 ether,
                receiver,
                0,
                3,
                4,
                getShieldedClaimProofReturnStruct.changeNullifier,
                getShieldedClaimProofReturnStruct.changeNullifierHash,
                pushedCommitments3,
                bytes("")
            )
        );

        bytes32[] memory pushedCommitments4 = new bytes32[](5);
        pushedCommitments4[0] = commitment;
        pushedCommitments4[1] = senderShieldedTransferProofReturnStruct.changeCommitmentHash;
        pushedCommitments4[2] = senderShieldedTransferProofReturnStruct.destCommitmentHash;
        pushedCommitments4[3] = getShieldedClaimProofReturnStruct.changeCommitmentHash;
        pushedCommitments4[4] = commitment2;
        partialWithdrawAndAssert(
            PartialWithdrawStruct(
                receiver,
                0.3 ether,
                0.3 ether,
                receiver,
                0,
                4,
                5,
                nullifier2,
                nullifierHash2,
                pushedCommitments4,
                bytes("")
            )
        );
    }

    function test_prevent_shielded_transfer_double_spend() external {
        (
            ,
            address receiver,
            bytes32 commitment,
            bytes32 nullifierHash,
            bytes32 nullifier,
            GetShieldedTransferProofReturnStruct memory senderShieldedTransferProofReturnStruct,
            GetShieldedClaimProofReturnStruct memory getShieldedClaimProofReturnStruct
        ) = start();
        shieldedTransferAndAssert(
            receiver,
            ShieldedTransferStruct(
                senderShieldedTransferProofReturnStruct.proof,
                senderShieldedTransferProofReturnStruct.rootBefore,
                nullifierHash,
                senderShieldedTransferProofReturnStruct.changeCommitmentHash,
                senderShieldedTransferProofReturnStruct.destCommitmentHash,
                senderShieldedTransferProofReturnStruct.rootAfterAddingChangeToTree,
                senderShieldedTransferProofReturnStruct.rootAfterAddingDestToTree
            ),
            ShieldedClaimStruct(
                getShieldedClaimProofReturnStruct.proof,
                senderShieldedTransferProofReturnStruct.destNullifierHash,
                getShieldedClaimProofReturnStruct.changeCommitmentHash,
                getShieldedClaimProofReturnStruct.rootAfter
            ),
            bytes("")
        );

        // try partial_withdrawing from first deposit into the nextindex, should revert
        bytes32[] memory pushedCommitments3 = new bytes32[](4);
        pushedCommitments3[0] = commitment;
        pushedCommitments3[1] = senderShieldedTransferProofReturnStruct.changeCommitmentHash;
        pushedCommitments3[2] = senderShieldedTransferProofReturnStruct.destCommitmentHash;
        pushedCommitments3[3] = getShieldedClaimProofReturnStruct.changeCommitmentHash;
        partialWithdrawAndAssert(
            PartialWithdrawStruct(
                receiver,
                10 ether,
                10 ether,
                receiver,
                0,
                0,
                4,
                nullifier,
                nullifierHash,
                pushedCommitments3,
                bytes("The note has been already spent")
            )
        );

        // try partial_withdrawing from shared dest that recipient withdrew from, into the nextindex, should revert
        partialWithdrawAndAssert(
            PartialWithdrawStruct(
                receiver,
                1.5 ether,
                1.5 ether,
                receiver,
                0,
                2,
                4,
                senderShieldedTransferProofReturnStruct.destNullifier,
                senderShieldedTransferProofReturnStruct.destNullifierHash,
                pushedCommitments3,
                bytes("The note has been already spent")
            )
        );
    }

    function test_prevent_shielded_transfer_from_non_existent_root() external {
        (
            ,
            address receiver,
            ,
            bytes32 nullifierHash,
            ,
            GetShieldedTransferProofReturnStruct memory senderShieldedTransferProofReturnStruct,
            GetShieldedClaimProofReturnStruct memory getShieldedClaimProofReturnStruct
        ) = start();

        // make the rootBefore be different and expect revert
        shieldedTransferAndAssert(
            receiver,
            ShieldedTransferStruct(
                senderShieldedTransferProofReturnStruct.proof,
                bytes32(uint256(senderShieldedTransferProofReturnStruct.rootBefore) + 1),
                nullifierHash,
                senderShieldedTransferProofReturnStruct.changeCommitmentHash,
                senderShieldedTransferProofReturnStruct.destCommitmentHash,
                senderShieldedTransferProofReturnStruct.rootAfterAddingChangeToTree,
                senderShieldedTransferProofReturnStruct.rootAfterAddingDestToTree
            ),
            ShieldedClaimStruct(
                getShieldedClaimProofReturnStruct.proof,
                senderShieldedTransferProofReturnStruct.destNullifierHash,
                getShieldedClaimProofReturnStruct.changeCommitmentHash,
                getShieldedClaimProofReturnStruct.rootAfter
            ),
            bytes("Cannot find your merkle root")
        );

        // since no check if rootAfterAddingDestToTree is a valid root, the check is in the proof and the circuit will revert if not correct
        shieldedTransferAndAssert(
            receiver,
            ShieldedTransferStruct(
                senderShieldedTransferProofReturnStruct.proof,
                senderShieldedTransferProofReturnStruct.rootBefore,
                nullifierHash,
                senderShieldedTransferProofReturnStruct.changeCommitmentHash,
                senderShieldedTransferProofReturnStruct.destCommitmentHash,
                senderShieldedTransferProofReturnStruct.rootAfterAddingChangeToTree,
                bytes32(uint256(senderShieldedTransferProofReturnStruct.rootAfterAddingDestToTree) + 1)
            ),
            ShieldedClaimStruct(
                getShieldedClaimProofReturnStruct.proof,
                senderShieldedTransferProofReturnStruct.destNullifierHash,
                getShieldedClaimProofReturnStruct.changeCommitmentHash,
                getShieldedClaimProofReturnStruct.rootAfter
            ),
            bytes("Invalid shielded transfer proof")
        );
    }

    function test_deposit_twice_then_shielded_transfer() external {
        address sender = address(bytes20(keccak256("sender")));
        address receiver = address(bytes20(keccak256("receiver")));

        (bytes32 commitment, bytes32 nullifierHash, bytes32 nullifier) =
            depositAndAssert(sender, 0, new bytes32[](0), 10 ether);

        // second deposit
        bytes32[] memory pushedCommitments111 = new bytes32[](1);
        pushedCommitments111[0] = commitment;
        (bytes32 new_commitment,,) = depositAndAssert(sender, 1, pushedCommitments111, 1 ether);

        // shielded transfer
        // sender creates proof
        bytes32[] memory pushedCommitments = new bytes32[](2);
        pushedCommitments[0] = commitment;
        pushedCommitments[1] = new_commitment;
        (GetShieldedTransferProofReturnStruct memory senderShieldedTransferProofReturnStruct) =
            getShieldedTransferProof(0, 2, nullifier, nullifierHash, 10 ether, 1.5 ether, pushedCommitments);

        // reciever creates proof too
        bytes32[] memory pushedCommitments2 = new bytes32[](4);
        pushedCommitments2[0] = commitment;
        pushedCommitments2[1] = new_commitment;
        pushedCommitments2[2] = senderShieldedTransferProofReturnStruct.changeCommitmentHash;
        pushedCommitments2[3] = senderShieldedTransferProofReturnStruct.destCommitmentHash;
        (GetShieldedClaimProofReturnStruct memory getShieldedClaimProofReturnStruct) = getShieldedClaimProve(
            3,
            4,
            senderShieldedTransferProofReturnStruct.destNullifier,
            senderShieldedTransferProofReturnStruct.destNullifierHash,
            1.5 ether,
            pushedCommitments2
        );

        // make the rootBefore be different and expect revert
        shieldedTransferAndAssert(
            receiver,
            ShieldedTransferStruct(
                senderShieldedTransferProofReturnStruct.proof,
                senderShieldedTransferProofReturnStruct.rootBefore,
                nullifierHash,
                senderShieldedTransferProofReturnStruct.changeCommitmentHash,
                senderShieldedTransferProofReturnStruct.destCommitmentHash,
                senderShieldedTransferProofReturnStruct.rootAfterAddingChangeToTree,
                senderShieldedTransferProofReturnStruct.rootAfterAddingDestToTree
            ),
            ShieldedClaimStruct(
                getShieldedClaimProofReturnStruct.proof,
                senderShieldedTransferProofReturnStruct.destNullifierHash,
                getShieldedClaimProofReturnStruct.changeCommitmentHash,
                getShieldedClaimProofReturnStruct.rootAfter
            ),
            bytes("")
        );
    }
}
