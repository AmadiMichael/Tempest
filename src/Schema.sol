// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.21;

struct Proof {
    uint256[2] a;
    uint256[2][2] b;
    uint256[2] c;
}

struct DepositInfo {
    bytes32 commitment;
    uint256 denomination;
}

struct ShieldedTransferStruct {
    Proof _proof;
    bytes32 _root;
    bytes32 _nullifierHash; // `from` nullifier hash
    bytes32 _changeCommitmentHash;
    bytes32 _destCommitmentHash;
    bytes32 _rootAfterChangeWasAdded;
    bytes32 _rootAfterDestWasAdded;
}

struct ShieldedClaimStruct {
    Proof _proof;
    bytes32 _nullifierHash; // `shared dest` nullifier hash
    bytes32 _newCommitmentHash;
    bytes32 _newRoot;
}

interface IFullWithdrawVerifier {
    function verifyProof(
        uint256[2] calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2] calldata _pC,
        uint256[6] calldata _pubSignals
    ) external view returns (bool);
}

interface IDepositVerifier {
    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[4] calldata input
    ) external view returns (bool);
}

interface IPartialWithdrawVerifier {
    function verifyProof(
        uint256[2] calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2] calldata _pC,
        uint256[8] calldata _pubSignals
    ) external view returns (bool);
}

interface IShieldedTransferVerifier {
    function verifyProof(
        uint256[2] calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2] calldata _pC,
        uint256[6] calldata _pubSignals
    ) external view returns (bool);
}

interface IShieldedClaimVerifier {
    function verifyProof(
        uint256[2] calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2] calldata _pC,
        uint256[4] calldata _pubSignals
    ) external view returns (bool);
}
