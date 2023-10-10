// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {
    TempestEth,
    IFullWithdrawVerifier,
    IDepositVerifier,
    IPartialWithdrawVerifier,
    IShieldedTransferVerifier,
    IShieldedClaimVerifier,
    Proof,
    ShieldedTransferStruct,
    ShieldedClaimStruct
} from "../src/TempestEth.sol";
import {Groth16Verifier as FullWithdrawGroth16Verifier} from "../build/FullWithdrawVerifier.sol";
import {Groth16Verifier as DepositGroth16Verifier} from "../build/DepositVerifier.sol";
import {Groth16Verifier as PartialWithdrawGroth16Verifier} from "../build/PartialWithdrawVerifier.sol";
import {Groth16Verifier as ShieldedTransferGroth16Verifier} from "../build/ShieldedTransferVerifier.sol";
import {Groth16Verifier as ShieldedClaimGroth16Verifier} from "../build/ShieldedClaimVerifier.sol";

contract Shared is Test {
    TempestEth tempestEth;
    IDepositVerifier depositVerifier;
    IFullWithdrawVerifier fullWithdrawVerifier;
    IPartialWithdrawVerifier partialWithdrawVerifier;
    IShieldedTransferVerifier shieldedTransferVerifier;
    IShieldedClaimVerifier shieldedClaimVerifier;

    event Deposit(bytes32 indexed commitment, uint256 leafIndex, uint256 timestamp);
    event Withdrawal(address to, bytes32 nullifierHash, address indexed relayer, uint256 fee);
    event ShieldedTransfer(
        bytes32 indexed changeCommitmentHash,
        bytes32 indexed sharedCommitmentHash,
        bytes32 indexed redepositCommitmentHash,
        uint256 startIndex,
        bytes32 sendNullifierHash,
        bytes32 redpositNullifierHash
    );

    function setUp() public {
        fullWithdrawVerifier = IFullWithdrawVerifier(address(new FullWithdrawGroth16Verifier()));
        depositVerifier = IDepositVerifier(address(new DepositGroth16Verifier()));
        partialWithdrawVerifier = IPartialWithdrawVerifier(address(new PartialWithdrawGroth16Verifier()));
        shieldedTransferVerifier = IShieldedTransferVerifier(address(new ShieldedTransferGroth16Verifier()));
        shieldedClaimVerifier = IShieldedClaimVerifier(address(new ShieldedClaimGroth16Verifier()));

        tempestEth = new TempestEth(
            depositVerifier,
            fullWithdrawVerifier,
            partialWithdrawVerifier,
            shieldedTransferVerifier,
            shieldedClaimVerifier,
            20
        );
    }

    function getDepositCommitmentHash(uint256 leafIndex, uint256 denomination) internal returns (bytes memory) {
        string[] memory inputs = new string[](4);
        inputs[0] = "node";
        inputs[1] = "ffi_helpers/getCommitment.js";
        inputs[2] = vm.toString(leafIndex);
        inputs[3] = vm.toString(denomination);

        return vm.ffi(inputs);
    }

    function getJsTreeAssertions(bytes32[] memory pushedCommitments, bytes32 newCommitment)
        private
        returns (bytes32 root_before_commitment, uint256 height, bytes32 root_after_commitment)
    {
        string[] memory inputs = new string[](5);
        inputs[0] = "node";
        inputs[1] = "ffi_helpers/tree.js";
        inputs[2] = "20";
        inputs[3] = vm.toString(abi.encode(pushedCommitments));
        inputs[4] = vm.toString(newCommitment);

        bytes memory result = vm.ffi(inputs);
        (root_before_commitment, height, root_after_commitment) = abi.decode(result, (bytes32, uint256, bytes32));
    }

    struct GetPartialWithdrawProveStruct {
        uint256 leafIndex;
        uint256 changeLeafIndex;
        bytes32 nullifier;
        bytes32 changeNullifier;
        bytes32 nullifierHash;
        bytes32 changeCommitmentHash;
        uint256 denomination;
        address recipient;
        uint256 amount;
        address relayer;
        uint256 fee;
        bytes32[] pushedCommitments;
    }

    function getPartialWithdrawProve(GetPartialWithdrawProveStruct memory getPartialWithdrawProveStruct)
        private
        returns (bytes memory)
    {
        string[] memory inputs = new string[](15);
        inputs[0] = "node";
        inputs[1] = "ffi_helpers/getPartialWithdrawProve.js";
        inputs[2] = "20";
        inputs[3] = vm.toString(getPartialWithdrawProveStruct.leafIndex);
        inputs[4] = vm.toString(getPartialWithdrawProveStruct.changeLeafIndex);
        inputs[5] = vm.toString(getPartialWithdrawProveStruct.nullifier);
        inputs[6] = vm.toString(getPartialWithdrawProveStruct.changeNullifier);
        inputs[7] = vm.toString(getPartialWithdrawProveStruct.nullifierHash);
        inputs[8] = vm.toString(getPartialWithdrawProveStruct.changeCommitmentHash);
        inputs[9] = vm.toString(getPartialWithdrawProveStruct.denomination);
        inputs[10] = vm.toString(getPartialWithdrawProveStruct.recipient);
        inputs[11] = vm.toString(getPartialWithdrawProveStruct.amount);
        inputs[12] = vm.toString(getPartialWithdrawProveStruct.relayer);
        inputs[13] = vm.toString(getPartialWithdrawProveStruct.fee);
        inputs[14] = vm.toString(abi.encode(getPartialWithdrawProveStruct.pushedCommitments));

        bytes memory result = vm.ffi(inputs);
        return result;
    }

    struct GetShieldedClaimProveStruct {
        uint256 leafIndex;
        uint256 destLeafIndex;
        bytes32 nullifier;
        bytes32 destNullifier;
        bytes32 nullifierHash;
        bytes32 destCommitmentHash;
        uint256 denomination;
        bytes32[] pushedCommitments;
    }

    function generateShieldedClaimProve(GetShieldedClaimProveStruct memory getShieldedClaimProveStruct)
        private
        returns (bytes memory)
    {
        string[] memory inputs = new string[](12);
        inputs[0] = "node";
        inputs[1] = "ffi_helpers/getShieldedClaimProve.js";
        inputs[2] = "20";
        inputs[3] = vm.toString(getShieldedClaimProveStruct.leafIndex);
        inputs[4] = vm.toString(getShieldedClaimProveStruct.destLeafIndex);
        inputs[5] = vm.toString(getShieldedClaimProveStruct.nullifier);
        inputs[6] = vm.toString(getShieldedClaimProveStruct.destNullifier);
        inputs[7] = vm.toString(getShieldedClaimProveStruct.nullifierHash);
        inputs[8] = vm.toString(getShieldedClaimProveStruct.destCommitmentHash);
        inputs[9] = vm.toString(getShieldedClaimProveStruct.denomination);
        inputs[10] = vm.toString(abi.encode(getShieldedClaimProveStruct.pushedCommitments));

        bytes memory result = vm.ffi(inputs);
        return result;
    }

    struct GetShieldedClaimProofReturnStruct {
        Proof proof;
        bytes32 changeCommitmentHash;
        bytes32 changeNullifierHash;
        bytes32 changeNullifier;
        bytes32 rootBefore;
        bytes32 rootAfter;
    }

    function getShieldedClaimProve(
        uint256 fromLeafIndex,
        uint256 changeLeafIndex,
        bytes32 nullifier,
        bytes32 nullifierHash,
        uint256 denomination,
        bytes32[] memory pushedCommitments
    ) internal returns (GetShieldedClaimProofReturnStruct memory getShieldedClaimProofReturnStruct) {
        (
            getShieldedClaimProofReturnStruct.changeCommitmentHash,
            getShieldedClaimProofReturnStruct.changeNullifierHash,
            getShieldedClaimProofReturnStruct.changeNullifier
        ) = abi.decode(getDepositCommitmentHash(changeLeafIndex, denomination), (bytes32, bytes32, bytes32));

        (
            getShieldedClaimProofReturnStruct.proof,
            getShieldedClaimProofReturnStruct.rootBefore,
            getShieldedClaimProofReturnStruct.rootAfter
        ) = abi.decode(
            generateShieldedClaimProve(
                GetShieldedClaimProveStruct(
                    fromLeafIndex,
                    changeLeafIndex,
                    nullifier,
                    getShieldedClaimProofReturnStruct.changeNullifier,
                    nullifierHash,
                    getShieldedClaimProofReturnStruct.changeCommitmentHash,
                    denomination,
                    pushedCommitments
                )
            ),
            (Proof, bytes32, bytes32)
        );
    }

    function getFullWithdrawProve(
        uint256 leafIndex,
        bytes32 nullifier,
        bytes32 nullifierHash,
        address recipient,
        uint256 amount,
        address relayer,
        uint256 fee,
        bytes32[] memory pushedCommitments
    ) private returns (bytes memory) {
        string[] memory inputs = new string[](11);
        inputs[0] = "node";
        inputs[1] = "ffi_helpers/getFullWithdrawProve.js";
        inputs[2] = "20";
        inputs[3] = vm.toString(leafIndex);
        inputs[4] = vm.toString(nullifier);
        inputs[5] = vm.toString(nullifierHash);
        inputs[6] = vm.toString(recipient);
        inputs[7] = vm.toString(amount);
        inputs[8] = vm.toString(relayer);
        inputs[9] = vm.toString(fee);
        inputs[10] = vm.toString(abi.encode(pushedCommitments));

        bytes memory result = vm.ffi(inputs);
        return result;
    }

    function getDepositProve(
        uint256 leafIndex,
        bytes32 oldRoot,
        uint256 denomination,
        bytes32 nullifier,
        bytes32 commitmentHash,
        bytes32[] memory pushedCommitments
    ) private returns (bytes memory) {
        string[] memory inputs = new string[](9);
        inputs[0] = "node";
        inputs[1] = "ffi_helpers/getDepositProve.js";
        inputs[2] = "20";
        inputs[3] = vm.toString(leafIndex);
        inputs[4] = vm.toString(oldRoot);
        inputs[5] = vm.toString(commitmentHash);
        inputs[6] = vm.toString(denomination);
        inputs[7] = vm.toString(nullifier);
        inputs[8] = vm.toString(abi.encode(pushedCommitments));

        bytes memory result = vm.ffi(inputs);
        return result;
    }

    function depositAndAssert(address user, uint256 newLeafIndex, bytes32[] memory pushedCommitments, uint256 amount)
        internal
        returns (bytes32 commitment, bytes32 nullifierHash, bytes32 nullifier)
    {
        startHoax(user, amount + 1 ether);

        (commitment, nullifierHash, nullifier) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, amount), (bytes32, bytes32, bytes32));

        uint256 userrBalBefore = user.balance;

        // deposit
        tempestEth.commit{value: amount}(commitment);

        /// get dep prove
        Proof memory depositProof;
        bytes32 newRoot;
        {
            (depositProof, newRoot) = abi.decode(
                getDepositProve(
                    newLeafIndex,
                    tempestEth.roots(tempestEth.currentRootIndex()),
                    amount,
                    nullifier,
                    commitment,
                    pushedCommitments
                ),
                (Proof, bytes32)
            );
        }

        vm.expectEmit(true, false, false, true, address(tempestEth));
        emit Deposit(commitment, newLeafIndex, block.timestamp);
        tempestEth.deposit(depositProof, newRoot);
        assertTrue((userrBalBefore - user.balance) >= amount, "Balance did not go down by expcted amount of ether");

        {
            // assert tree root and elements are correct
            (bytes32 preDepositRoot, uint256 elements, bytes32 postDepositRoot) =
                getJsTreeAssertions(pushedCommitments, commitment);
            assertEq(preDepositRoot, tempestEth.roots(newLeafIndex));
            assertEq(elements, tempestEth.nextIndex());
            assertEq(postDepositRoot, tempestEth.roots(newLeafIndex + 1));
        }

        vm.stopPrank();
    }

    function withdrawAndAssert(
        address user,
        uint256 amount,
        address relayer,
        uint256 fee,
        uint256 leafIndex,
        bytes32 nullifier,
        bytes32 nullifierHash,
        bytes32[] memory pushedCommitments,
        bytes memory errorIfAny
    ) internal returns (Proof memory proof, bytes32 root) {
        startHoax(relayer);

        /// get prove
        {
            (proof, root) = abi.decode(
                getFullWithdrawProve(leafIndex, nullifier, nullifierHash, user, amount, relayer, fee, pushedCommitments),
                (Proof, bytes32)
            );
        }

        // withdraw
        address _user = user;
        address _relayer = relayer;
        uint256 _amount = amount;
        uint256 _fee = fee;
        if (keccak256(errorIfAny) == keccak256(bytes(""))) {
            uint256 userBalBefore = user.balance;

            vm.expectEmit(true, false, false, true, address(tempestEth));
            emit Withdrawal(_user, nullifierHash, _relayer, _fee);
            tempestEth.withdraw(proof, root, nullifierHash, payable(_user), _amount, payable(_relayer), _fee);
            assertEq(
                (_user.balance - userBalBefore), _amount - _fee, "Balance did not go up by expected amount of ether"
            );
        } else {
            vm.expectRevert(errorIfAny);
            tempestEth.withdraw(proof, root, nullifierHash, payable(_user), _amount, payable(_relayer), _fee);
        }

        vm.stopPrank();
    }

    struct PartialWithdrawStruct {
        address user;
        uint256 denomination;
        uint256 amount;
        address relayer;
        uint256 fee;
        uint256 leafIndex;
        uint256 newLeafIndex;
        bytes32 nullifier;
        bytes32 nullifierHash;
        bytes32[] pushedCommitments;
        bytes errorIfAny;
    }

    struct DepositInfoStruct {
        bytes32 newCommitment;
        bytes32 newNullifierHash;
        bytes32 newNullifier;
    }

    function partialWithdrawAndAssert(PartialWithdrawStruct memory partialWithdrawStruct)
        internal
        returns (Proof memory, bytes32, bytes32, bytes32, bytes32)
    {
        startHoax(partialWithdrawStruct.relayer);

        // get new commitment details
        DepositInfoStruct memory depositInfoStruct = abi.decode(
            getDepositCommitmentHash(
                partialWithdrawStruct.newLeafIndex, partialWithdrawStruct.denomination - partialWithdrawStruct.amount
            ),
            (DepositInfoStruct)
        );

        /// get prove
        bytes32 newRoot;
        Proof memory proof;
        bytes32 root;
        {
            (proof, root, newRoot) = abi.decode(
                getPartialWithdrawProve(
                    GetPartialWithdrawProveStruct(
                        partialWithdrawStruct.leafIndex,
                        partialWithdrawStruct.newLeafIndex,
                        partialWithdrawStruct.nullifier,
                        depositInfoStruct.newNullifier,
                        partialWithdrawStruct.nullifierHash,
                        depositInfoStruct.newCommitment,
                        partialWithdrawStruct.denomination,
                        partialWithdrawStruct.user,
                        partialWithdrawStruct.amount,
                        partialWithdrawStruct.relayer,
                        partialWithdrawStruct.fee,
                        partialWithdrawStruct.pushedCommitments
                    )
                ),
                (Proof, bytes32, bytes32)
            );
        }

        // withdraw
        withdrawAction(proof, root, newRoot, partialWithdrawStruct, depositInfoStruct);
        vm.stopPrank();

        return (
            proof,
            root,
            depositInfoStruct.newCommitment,
            depositInfoStruct.newNullifierHash,
            depositInfoStruct.newNullifier
        );
    }

    function withdrawAction(
        Proof memory proof,
        bytes32 root,
        bytes32 newRoot,
        PartialWithdrawStruct memory partialWithdrawStruct,
        DepositInfoStruct memory depositInfoStruct
    ) internal {
        // withdraw
        if (keccak256(partialWithdrawStruct.errorIfAny) == keccak256(bytes(""))) {
            uint256 userBalBefore = partialWithdrawStruct.user.balance;

            vm.expectEmit(true, false, false, true, address(tempestEth));
            emit Withdrawal(
                partialWithdrawStruct.user,
                partialWithdrawStruct.nullifierHash,
                partialWithdrawStruct.relayer,
                partialWithdrawStruct.fee
            );

            vm.expectEmit(true, false, false, true, address(tempestEth));
            emit Deposit(depositInfoStruct.newCommitment, partialWithdrawStruct.newLeafIndex, block.timestamp);

            tempestEth.partialWithdraw(
                proof,
                root,
                partialWithdrawStruct.nullifierHash,
                depositInfoStruct.newCommitment,
                newRoot,
                payable(partialWithdrawStruct.user),
                partialWithdrawStruct.amount,
                payable(partialWithdrawStruct.relayer),
                partialWithdrawStruct.fee
            );
            assertEq(
                (partialWithdrawStruct.user.balance - userBalBefore),
                partialWithdrawStruct.amount - partialWithdrawStruct.fee,
                "Balance did not go up by expected amount of ether"
            );
        } else {
            vm.expectRevert(partialWithdrawStruct.errorIfAny);
            tempestEth.partialWithdraw(
                proof,
                root,
                partialWithdrawStruct.nullifierHash,
                depositInfoStruct.newCommitment,
                newRoot,
                payable(partialWithdrawStruct.user),
                partialWithdrawStruct.amount,
                payable(partialWithdrawStruct.relayer),
                partialWithdrawStruct.fee
            );
        }
    }

    struct GetShieldedTransferProveStruct {
        uint256 fromLeafIndex;
        uint256 changeLeafIndex;
        bytes32 fromNullifier;
        bytes32 changeNullifier;
        bytes32 destNullifier;
        bytes32 fromNullifierHash;
        bytes32 changeCommitmentHash;
        bytes32 destCommitmentHash;
        uint256 denomination;
        uint256 amount;
        bytes32[] pushedCommitments;
    }

    function generateShieldedTransferProof(GetShieldedTransferProveStruct memory getShieldedTransferProveStruct)
        internal
        returns (bytes memory)
    {
        string[] memory inputs = new string[](14);
        inputs[0] = "node";
        inputs[1] = "ffi_helpers/getShieldedTransferProve.js";
        inputs[2] = "20";
        inputs[3] = vm.toString(getShieldedTransferProveStruct.fromLeafIndex);
        inputs[4] = vm.toString(getShieldedTransferProveStruct.changeLeafIndex);
        inputs[5] = vm.toString(getShieldedTransferProveStruct.fromNullifier);
        inputs[6] = vm.toString(getShieldedTransferProveStruct.changeNullifier);
        inputs[7] = vm.toString(getShieldedTransferProveStruct.destNullifier);
        inputs[8] = vm.toString(getShieldedTransferProveStruct.fromNullifierHash);
        inputs[9] = vm.toString(getShieldedTransferProveStruct.changeCommitmentHash);
        inputs[10] = vm.toString(getShieldedTransferProveStruct.destCommitmentHash);
        inputs[11] = vm.toString(getShieldedTransferProveStruct.denomination);
        inputs[12] = vm.toString(getShieldedTransferProveStruct.amount);
        inputs[13] = vm.toString(abi.encode(getShieldedTransferProveStruct.pushedCommitments));

        bytes memory result = vm.ffi(inputs);
        return result;
    }

    function shieldedTransferAndAssert(
        address broadcaster,
        ShieldedTransferStruct memory sendProof,
        ShieldedClaimStruct memory redepositProof,
        bytes memory errorIfAny
    ) internal {
        startHoax(broadcaster);

        if (keccak256(errorIfAny) == keccak256(bytes(""))) {
            vm.expectEmit(true, true, true, true, address(tempestEth));
            emit ShieldedTransfer(
                sendProof._changeCommitmentHash,
                sendProof._destCommitmentHash,
                redepositProof._newCommitmentHash,
                tempestEth.nextIndex(),
                sendProof._nullifierHash,
                redepositProof._nullifierHash
            );
            tempestEth.shieldedTransfer(sendProof, redepositProof);
        } else {
            vm.expectRevert(errorIfAny);
            tempestEth.shieldedTransfer(sendProof, redepositProof);
        }
    }

    struct GetShieldedTransferProofReturnStruct {
        Proof proof;
        bytes32 changeCommitmentHash;
        bytes32 changeNullifierHash;
        bytes32 changeNullifier;
        bytes32 destCommitmentHash;
        bytes32 destNullifierHash;
        bytes32 destNullifier;
        bytes32 rootBefore;
        bytes32 rootAfterAddingChangeToTree;
        bytes32 rootAfterAddingDestToTree;
    }

    function getShieldedTransferProof(
        uint256 fromLeafIndex,
        uint256 changeLeafIndex,
        bytes32 fromNullifier,
        bytes32 fromNullifierHash,
        uint256 denomination,
        uint256 amount,
        bytes32[] memory pushedCommitments
    ) internal returns (GetShieldedTransferProofReturnStruct memory getShieldedTransferProofReturnStruct) {
        (
            getShieldedTransferProofReturnStruct.changeCommitmentHash,
            getShieldedTransferProofReturnStruct.changeNullifierHash,
            getShieldedTransferProofReturnStruct.changeNullifier
        ) = abi.decode(getDepositCommitmentHash(changeLeafIndex, denomination - amount), (bytes32, bytes32, bytes32));

        (
            getShieldedTransferProofReturnStruct.destCommitmentHash,
            getShieldedTransferProofReturnStruct.destNullifierHash,
            getShieldedTransferProofReturnStruct.destNullifier
        ) = abi.decode(getDepositCommitmentHash(changeLeafIndex + 1, amount), (bytes32, bytes32, bytes32));

        (
            getShieldedTransferProofReturnStruct.proof,
            getShieldedTransferProofReturnStruct.rootBefore,
            getShieldedTransferProofReturnStruct.rootAfterAddingChangeToTree,
            getShieldedTransferProofReturnStruct.rootAfterAddingDestToTree
        ) = abi.decode(
            generateShieldedTransferProof(
                GetShieldedTransferProveStruct(
                    fromLeafIndex,
                    changeLeafIndex,
                    fromNullifier,
                    getShieldedTransferProofReturnStruct.changeNullifier,
                    getShieldedTransferProofReturnStruct.destNullifier,
                    fromNullifierHash,
                    getShieldedTransferProofReturnStruct.changeCommitmentHash,
                    getShieldedTransferProofReturnStruct.destCommitmentHash,
                    denomination,
                    amount,
                    pushedCommitments
                )
            ),
            (Proof, bytes32, bytes32, bytes32)
        );
    }
}
