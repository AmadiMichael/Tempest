// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Shared, Proof} from "./Shared.sol";

contract DepositAndWithdrawTest is Shared {
    function test_deposit_and_withdraw() external {
        address userOldSigner = address(bytes20(keccak256("userOldSigner")));
        address relayerSigner = address(bytes20(keccak256("relayerSigner")));

        (bytes32 commitment, bytes32 nullifierHash, bytes32 nullifier) =
            depositAndAssert(userOldSigner, 0, new bytes32[](0), 1 ether);

        // withdraw
        bytes32[] memory pushedCommitments = new bytes32[](1);
        pushedCommitments[0] = commitment;
        withdrawAndAssert(
            userOldSigner, 1 ether, relayerSigner, 0, 0, nullifier, nullifierHash, pushedCommitments, bytes("")
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
        withdrawAndAssert(
            userOldSigner, 1 ether, relayerSigner, 0, 0, nullifier, nullifierHash, pushedCommitments, bytes("")
        );

        // try again but expect error
        withdrawAndAssert(
            userOldSigner,
            1 ether,
            relayerSigner,
            0,
            0,
            nullifier,
            nullifierHash,
            pushedCommitments,
            bytes("The note has been already spent")
        );
    }

    function test_prevent_withdraw_from_non_existent_root() external {
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
        withdrawAndAssert(
            attacker,
            1 ether,
            relayerSigner,
            0,
            1,
            attacker_nullifier,
            attacker_nullifierHash,
            pushedCommitments,
            bytes("Cannot find your merkle root")
        );
    }

    function test_deposit_twice_then_withdraw() external {
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
        withdrawAndAssert(
            userOldSigner, 1 ether, relayerSigner, 0, 0, nullifier, nullifierHash, updated_pushedCommitments, bytes("")
        );
    }

    function test_clear() external {
        address userOldSigner = address(bytes20(keccak256("userOldSigner")));

        startHoax(userOldSigner, 1 ether);
        tempestEth.commit{value: 1 ether}(bytes32(uint256(1)));

        uint256 balanceBefore = userOldSigner.balance;
        tempestEth.clear();
        assertEq(balanceBefore + 1 ether, userOldSigner.balance);
    }

    function test_clear_reverts_if_not_committed() external {
        address userOldSigner = address(bytes20(keccak256("userOldSigner")));

        startHoax(userOldSigner, 1 ether);
        tempestEth.commit{value: 1 ether}(bytes32(uint256(1)));

        tempestEth.clear();

        vm.expectRevert(bytes("not committed"));
        tempestEth.clear();
    }

    function test_commit_revert_if_caller_has_pending_commit() external {
        address userOldSigner = address(bytes20(keccak256("userOldSigner")));

        startHoax(userOldSigner, 2 ether);
        tempestEth.commit{value: 1 ether}(bytes32(uint256(1)));

        vm.expectRevert(bytes("Pending commitment hash"));
        tempestEth.commit{value: 1 ether}(bytes32(uint256(2)));
    }

    function test_commit_revert_if_commitment_hash_not_within_bn128_field() external {
        address userOldSigner = address(bytes20(keccak256("userOldSigner")));
        uint256 FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

        startHoax(userOldSigner, 2 ether);
        vm.expectRevert(bytes("_commitment not in field"));
        tempestEth.commit{value: 1 ether}(bytes32(uint256(FIELD_SIZE)));
    }

    function test_withdraw_reverts_if_fee_exceeds_denomination() external {
        address userOldSigner = address(bytes20(keccak256("userOldSigner")));
        address relayerSigner = address(bytes20(keccak256("relayerSigner")));

        (bytes32 commitment, bytes32 nullifierHash, bytes32 nullifier) =
            depositAndAssert(userOldSigner, 0, new bytes32[](0), 1 ether);

        // withdraw
        bytes32[] memory pushedCommitments = new bytes32[](1);
        pushedCommitments[0] = commitment;
        withdrawAndAssert(
            userOldSigner,
            1 ether,
            relayerSigner,
            1.1 ether,
            0,
            nullifier,
            nullifierHash,
            pushedCommitments,
            bytes("Fee exceeds transfer value")
        );
    }
}
