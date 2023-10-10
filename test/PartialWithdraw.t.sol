// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Shared, Proof} from "./Shared.sol";

contract PartialWithdrawTest is Shared {
    function test_deposit_and_withdraw_twice_using_partial_withdraw() external {
        address userOldSigner = address(bytes20(keccak256("userOldSigner")));
        address relayerSigner = address(bytes20(keccak256("relayerSigner")));

        (bytes32 commitment, bytes32 nullifierHash, bytes32 nullifier) =
            depositAndAssert(userOldSigner, 0, new bytes32[](0), 10 ether);

        // withdraw
        bytes32[] memory pushedCommitments = new bytes32[](1);
        pushedCommitments[0] = commitment;
        (,, bytes32 newCommitment, bytes32 newNullifierHash, bytes32 newNullifier) = partialWithdrawAndAssert(
            PartialWithdrawStruct(
                userOldSigner,
                10 ether,
                1 ether,
                relayerSigner,
                0,
                0,
                1,
                nullifier,
                nullifierHash,
                pushedCommitments,
                bytes("")
            )
        );

        bytes32[] memory newPushedCommitments = new bytes32[](2);
        newPushedCommitments[0] = commitment;
        newPushedCommitments[1] = newCommitment;
        partialWithdrawAndAssert(
            PartialWithdrawStruct(
                userOldSigner,
                9 ether,
                1 ether,
                relayerSigner,
                0,
                1,
                2,
                newNullifier,
                newNullifierHash,
                newPushedCommitments,
                bytes("")
            )
        );
    }

    function test_prevent_double_spend() external {
        address userOldSigner = address(bytes20(keccak256("userOldSigner")));
        address relayerSigner = address(bytes20(keccak256("relayerSigner")));

        (bytes32 commitment, bytes32 nullifierHash, bytes32 nullifier) =
            depositAndAssert(userOldSigner, 0, new bytes32[](0), 1 ether);

        // withdraw
        bytes32[] memory pushedCommitments = new bytes32[](1);
        pushedCommitments[0] = commitment;
        partialWithdrawAndAssert(
            PartialWithdrawStruct(
                userOldSigner,
                1 ether,
                0.5 ether,
                relayerSigner,
                0,
                0,
                1,
                nullifier,
                nullifierHash,
                pushedCommitments,
                bytes("")
            )
        );

        partialWithdrawAndAssert(
            PartialWithdrawStruct(
                userOldSigner,
                1 ether,
                0.5 ether,
                relayerSigner,
                0,
                0,
                1,
                nullifier,
                nullifierHash,
                pushedCommitments,
                bytes("The note has been already spent")
            )
        );
    }

    function test_prevent_partial_withdraw_from_non_existent_root() external {
        address honestUser = address(bytes20(keccak256("honestUser")));
        address relayerSigner = address(bytes20(keccak256("relayerSigner")));
        address attacker = address(bytes20(keccak256("attacker")));

        (bytes32 honest_commitment,,) = depositAndAssert(honestUser, 0, new bytes32[](0), 1 ether);

        // generate proof but don't commit or deposit
        (bytes32 attacker_commitment, bytes32 attacker_nullifierHash, bytes32 attacker_nullifier) =
            abi.decode(getDepositCommitmentHash(1, 1e18), (bytes32, bytes32, bytes32));

        // withdraw but expect error
        bytes32[] memory pushedCommitments = new bytes32[](2);
        pushedCommitments[0] = honest_commitment;
        pushedCommitments[1] = attacker_commitment;
        partialWithdrawAndAssert(
            PartialWithdrawStruct(
                attacker,
                1 ether,
                0.5 ether,
                relayerSigner,
                0,
                1,
                2,
                attacker_nullifier,
                attacker_nullifierHash,
                pushedCommitments,
                bytes("Cannot find your merkle root")
            )
        );
    }

    // used to trivially test that deposits can withdraw after more deposits have come in
    function test_deposit_twice_then_partial_withdraw() external {
        address userOldSigner = address(bytes20(keccak256("userOldSigner")));
        address userNewSigner = address(bytes20(keccak256("userNewSigner")));
        address relayerSigner = address(bytes20(keccak256("relayerSigner")));

        // first deposit
        (bytes32 commitment, bytes32 nullifierHash, bytes32 nullifier) =
            depositAndAssert(userOldSigner, 0, new bytes32[](0), 1 ether);

        // second deposit
        bytes32[] memory pushedCommitments = new bytes32[](1);
        pushedCommitments[0] = commitment;
        (bytes32 new_commitment,,) = depositAndAssert(userNewSigner, 1, pushedCommitments, 1 ether);

        // withdraw first deposit via second deposit's root
        bytes32[] memory updated_pushedCommitments = new bytes32[](2);
        updated_pushedCommitments[0] = commitment;
        updated_pushedCommitments[1] = new_commitment;
        partialWithdrawAndAssert(
            PartialWithdrawStruct(
                userOldSigner,
                1 ether,
                0.7 ether,
                relayerSigner,
                0,
                0,
                2,
                nullifier,
                nullifierHash,
                updated_pushedCommitments,
                bytes("")
            )
        );
    }
}
