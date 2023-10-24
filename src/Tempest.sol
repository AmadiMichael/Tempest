// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.21;

import "./utils/ReentrancyGuard.sol";
import {
    IFullWithdrawVerifier,
    IDepositVerifier,
    IPartialWithdrawVerifier,
    IShieldedTransferVerifier,
    IShieldedClaimVerifier,
    Proof,
    ShieldedTransferStruct,
    ShieldedClaimStruct,
    DepositInfo
} from "./Schema.sol";

abstract contract Tempest is ReentrancyGuard {
    uint256 constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 constant ROOT_HISTORY_SIZE = 30;
    bytes32 constant initialRootZero = 0x2b0f6fc0179fa65b6f73627c0e1e84c7374d2eaec44c9a48f2571393ea77bcbb; // Keccak256("Tornado")

    uint256 immutable levels;
    IFullWithdrawVerifier immutable fullWithdrawVerifier;
    IDepositVerifier immutable depositVerifier;
    IPartialWithdrawVerifier immutable partialWithdrawVerifier;
    IShieldedTransferVerifier immutable shieldedTransferVerifier;
    IShieldedClaimVerifier immutable shieldedClaimVerifier;

    // current index of the latest root in the roots array
    uint128 public currentRootIndex;

    // index which the next deposit commitment hash should go into
    uint128 public nextIndex;

    // fixed size array of past roots to enable withdrawal using any last-ROOT_HISTORY_SIZE root from the past
    bytes32[ROOT_HISTORY_SIZE] public roots;

    // mapping of nullifier hashes to if they have been consumed or not
    mapping(bytes32 => bool) public nullifierHashes;

    // mapping of an address and it's pending commitment hash info (i.e commitment hash and amount deposited)
    mapping(address => DepositInfo) pendingCommit;

    event Deposit(bytes32 indexed commitment, uint256 leafIndex, uint256 timestamp);
    event Withdrawal(address to, bytes32 nullifierHash, address indexed relayer, uint256 fee);
    event ShieldedTransfer(
        bytes32 indexed changeCommitmentHash,
        bytes32 indexed sharedCommitmentHash,
        bytes32 indexed redepositCommitmentHash,
        uint256 lastIndexBeforeShieldedTransfer,
        bytes32 sendNullifierHash,
        bytes32 redpositNullifierHash
    );

    /**
     * @param _depositVerifier the address of deposit SNARK verifier for this contract
     * @param _fullWithdrawVerifier the address of withdraw SNARK verifier for this contract
     * @param _partialWithdrawVerifier the address of the partial-withdraw SNARK verifier for this contract
     * @param _shieldedTransferVerifier the address of shielded-transfer SNARK verifier for this contract
     * @param _merkleTreeHeight the height of deposits' Merkle Tree
     */
    constructor(
        IDepositVerifier _depositVerifier,
        IFullWithdrawVerifier _fullWithdrawVerifier,
        IPartialWithdrawVerifier _partialWithdrawVerifier,
        IShieldedTransferVerifier _shieldedTransferVerifier,
        IShieldedClaimVerifier _shieldedClaimVerifier,
        uint256 _merkleTreeHeight
    ) {
        require(_merkleTreeHeight > 0, "_treeLevels should be greater than zero");
        require(_merkleTreeHeight < 32, "_treeLevels should be less than 32");

        levels = _merkleTreeHeight;
        roots[0] = initialRootZero;
        depositVerifier = _depositVerifier;
        fullWithdrawVerifier = _fullWithdrawVerifier;
        partialWithdrawVerifier = _partialWithdrawVerifier;
        shieldedTransferVerifier = _shieldedTransferVerifier;
        shieldedClaimVerifier = _shieldedClaimVerifier;
    }

    /**
     * @notice Let users delete a previously committed commitment hash and withdraw the denomination they deposited alongside it
     */
    function clear() external nonReentrant {
        require(pendingCommit[msg.sender].commitment != bytes32(0), "not committed");
        uint256 denomination = pendingCommit[msg.sender].denomination;
        delete pendingCommit[msg.sender];
        _processWithdraw(payable(msg.sender), denomination, payable(address(0)), 0);
    }

    /**
     * @notice lets users commit with any amount and a commitment hash which they can add into the tree whenever they want
     * @param _commitment commitment hash of user's deposit
     */
    function commit(bytes32 _commitment) external payable nonReentrant {
        require(pendingCommit[msg.sender].commitment == bytes32(0), "Pending commitment hash");
        require(uint256(_commitment) < FIELD_SIZE, "_commitment not in field");
        pendingCommit[msg.sender] = DepositInfo({commitment: _commitment, denomination: msg.value});
        _processDeposit();
    }

    /**
     * @notice deposit with commitment hash stored onchain when `commit` function was called
     * @dev lets users update the current merkle root by providing a snark proof that proves they added `pendingCommit[msg.sender]` to the current merkle tree root `roots[currentRootIndex]` and verifying it onchain
     * @param _proof snark proof of correct addition of `pendingCommit[msg.sender]` to the current merkle tree root `roots[currentRootIndex]`
     * @param newRoot new root computed by the user after adding `pendingCommit[msg.sender]` to the current merkle tree root `roots[currentRootIndex]`
     */
    function deposit(Proof calldata _proof, bytes32 newRoot) external payable nonReentrant {
        DepositInfo memory depositInfo = pendingCommit[msg.sender];
        require(depositInfo.commitment != bytes32(0), "not commited");

        uint256 _currentRootIndex = currentRootIndex;

        require(
            depositVerifier.verifyProof(
                _proof.a,
                _proof.b,
                _proof.c,
                [
                    uint256(roots[_currentRootIndex]),
                    uint256(depositInfo.commitment),
                    depositInfo.denomination,
                    uint256(newRoot)
                ]
            ),
            "Invalid deposit proof"
        );

        // set pending commit to 0 bytes
        pendingCommit[msg.sender] = DepositInfo(bytes32(0), 0);
        uint128 newCurrentRootIndex = uint128((_currentRootIndex + 1) % ROOT_HISTORY_SIZE);

        // update currentRootIndex
        currentRootIndex = newCurrentRootIndex;

        // update root
        roots[newCurrentRootIndex] = newRoot;
        uint256 _nextIndex = nextIndex;

        // update next index
        nextIndex += 1;

        emit Deposit(depositInfo.commitment, _nextIndex, block.timestamp);
    }

    /**
     * @dev this function is defined in a child contract
     */
    function _processDeposit() internal virtual;

    /**
     * @notice Withdraw all deposit associated with a commitment hash from the contract.
     * @dev Mostly used to remove deposit in the case that the merkle tree is filled
     * @param _proof is a zkSNARK proof data
     * @param _root is the root the user wants to proof that their commitment hash is part of
     * @param _nullifierHash nullifier hash associated with the commitment hash the user proves they have
     * @param _recipient address to send the amount to
     * @param _amount amount to send to _recipient
     * @param _relayer relayer if any
     * @param _fee fee to pay to replayer if any
     */
    function withdraw(
        Proof calldata _proof,
        bytes32 _root,
        bytes32 _nullifierHash,
        address payable _recipient,
        uint256 _amount,
        address payable _relayer,
        uint256 _fee
    ) external payable nonReentrant {
        require(_fee <= _amount, "Fee exceeds transfer value");
        require(!nullifierHashes[_nullifierHash], "The note has been already spent");
        require(isKnownRoot(_root), "Cannot find your merkle root"); // Make sure to use a recent one

        require(
            fullWithdrawVerifier.verifyProof(
                _proof.a,
                _proof.b,
                _proof.c,
                [
                    uint256(_root),
                    uint256(_nullifierHash),
                    _amount,
                    uint256(uint160(address(_recipient))),
                    uint256(uint160(address(_relayer))),
                    _fee
                ]
            ),
            "Invalid withdraw proof"
        );

        nullifierHashes[_nullifierHash] = true;
        _processWithdraw(_recipient, _amount, _relayer, _fee);
        emit Withdrawal(_recipient, _nullifierHash, _relayer, _fee);
    }

    /**
     * @notice Partially withdraw from a commitmentHash from the contract. Can withdraw all but nobody would know you withdrew all
     * @param _proof is a zkSNARK proof data
     * @param _root is the root the user wants to proof that their commitment hash is part of
     * @param _nullifierHash nullifier hash associated with the commitment hash the user proves they have
     * @param _newCommitmentHash commitmentHash used for the change leaf index
     * @param _newRoot merkle root after adding _newCommitmentHash to the merkle tree with root: _root
     * @param _recipient address to send the amount to
     * @param _amount amount to send to _recipient
     * @param _relayer relayer if any
     * @param _fee fee to pay to replayer if any
     */
    function partialWithdraw(
        Proof calldata _proof,
        bytes32 _root,
        bytes32 _nullifierHash,
        bytes32 _newCommitmentHash,
        bytes32 _newRoot,
        address payable _recipient,
        uint256 _amount,
        address payable _relayer,
        uint256 _fee
    ) external payable nonReentrant {
        require(_fee <= _amount, "Fee exceeds transfer value");
        require(!nullifierHashes[_nullifierHash], "The note has been already spent");
        require(isKnownRoot(_root), "Cannot find your merkle root"); // Make sure to use a recent one

        require(
            partialWithdrawVerifier.verifyProof(
                _proof.a,
                _proof.b,
                _proof.c,
                [
                    uint256(_root),
                    uint256(_nullifierHash),
                    _amount,
                    uint256(_newCommitmentHash),
                    uint256(_newRoot),
                    uint256(uint160(address(_recipient))),
                    uint256(uint160(address(_relayer))),
                    _fee
                ]
            ),
            "Invalid withdraw proof"
        );

        nullifierHashes[_nullifierHash] = true;
        _processWithdraw(_recipient, _amount, _relayer, _fee);
        emit Withdrawal(_recipient, _nullifierHash, _relayer, _fee);

        uint128 newCurrentRootIndex = uint128((currentRootIndex + 1) % ROOT_HISTORY_SIZE);

        // update currentRootIndex
        currentRootIndex = newCurrentRootIndex;

        // update root
        roots[newCurrentRootIndex] = _newRoot;
        uint256 _nextIndex = nextIndex;

        // update next index
        nextIndex += 1;
        emit Deposit(_newCommitmentHash, _nextIndex, block.timestamp);
    }

    /**
     * @notice Allows two parties to confidentially exchange monetary value without any body knowing the `from`, `to`, or `amount` sent.
     * @dev Shielded transfer lets users partially withdraw from a commitmenthash they have the nullifier to, send the change to the next available leaf index and create another leaf index for the amount `sent`
     *      then they can share the nullifier of this amount-sent leaf index to the recipient,
     *      The recipient in turn creates a partial withdraw proof from this amount sent's leaf index to a new leaf index that only they know the nullifier to. This way the receiver is sure that the sender cannot
     *      spend sent funds.
     *      This is basically two partial withdraw operations but with extra constriants since both happen offchain first before onchain, we have to ensure that the state transition is correct between both root changes too.
     */
    function shieldedTransfer(ShieldedTransferStruct calldata sendProof, ShieldedClaimStruct calldata redepositProof)
        external
        payable
        nonReentrant
    {
        // send proof
        require(!nullifierHashes[sendProof._nullifierHash], "The note has been already spent");
        require(isKnownRoot(sendProof._root), "Cannot find your merkle root"); // Make sure to use a recent one

        require(
            shieldedTransferVerifier.verifyProof(
                sendProof._proof.a,
                sendProof._proof.b,
                sendProof._proof.c,
                [
                    uint256(sendProof._root),
                    uint256(sendProof._nullifierHash),
                    uint256(sendProof._changeCommitmentHash),
                    uint256(sendProof._destCommitmentHash),
                    uint256(sendProof._rootAfterChangeWasAdded),
                    uint256(sendProof._rootAfterDestWasAdded)
                ]
            ),
            "Invalid shielded transfer proof"
        );

        nullifierHashes[sendProof._nullifierHash] = true;

        // update root
        uint128 newCurrentRootIndex = uint128((currentRootIndex + 1) % ROOT_HISTORY_SIZE);
        roots[newCurrentRootIndex] = sendProof._rootAfterChangeWasAdded;

        newCurrentRootIndex = uint128((newCurrentRootIndex + 1) % ROOT_HISTORY_SIZE);
        roots[newCurrentRootIndex] = sendProof._rootAfterDestWasAdded;

        // redeposit proof
        // send proof
        require(!nullifierHashes[redepositProof._nullifierHash], "The note has been already spent");

        require(
            shieldedClaimVerifier.verifyProof(
                redepositProof._proof.a,
                redepositProof._proof.b,
                redepositProof._proof.c,
                [
                    uint256(sendProof._rootAfterDestWasAdded), // use the last root of send proof as current root of claim proof
                    uint256(redepositProof._nullifierHash),
                    uint256(redepositProof._newCommitmentHash),
                    uint256(redepositProof._newRoot)
                ]
            ),
            "Invalid shielded claim proof"
        );

        nullifierHashes[redepositProof._nullifierHash] = true;

        newCurrentRootIndex = uint128((newCurrentRootIndex + 1) % ROOT_HISTORY_SIZE);

        // update root
        roots[newCurrentRootIndex] = redepositProof._newRoot;

        // update currentRootIndex
        currentRootIndex = newCurrentRootIndex;

        // update next index
        uint256 _nextIndex = nextIndex;
        // add by 3 since 3 roots are created i.e sender's change root, destination's public root and destination's private root
        // destination's public root is the root given to them by the sender (hence public)
        // destination's private root is the root they created after withdrawing from the public commitment hash
        nextIndex += 3;

        emit ShieldedTransfer(
            sendProof._changeCommitmentHash,
            sendProof._destCommitmentHash,
            redepositProof._newCommitmentHash,
            _nextIndex,
            sendProof._nullifierHash,
            redepositProof._nullifierHash
        );
    }

    /**
     * @dev this function is defined in a child contract
     */
    function _processWithdraw(address payable _recipient, uint256 amount, address payable _relayer, uint256 _fee)
        internal
        virtual;

    /**
     * @dev Whether the root is present in the root history
     */
    function isKnownRoot(bytes32 _root) public view returns (bool) {
        if (_root == 0) return false;

        uint256 i = currentRootIndex;
        do {
            if (_root == roots[i]) return true;
            if (i == 0) i = ROOT_HISTORY_SIZE;
            --i;
        } while (i != currentRootIndex);
        return false;
    }

    ///@notice offchain utility that checks if a nullifier hashes has been consumed or not, returns a boolean
    function isSpent(bytes32 _nullifierHash) public view returns (bool) {
        return nullifierHashes[_nullifierHash];
    }

    ///@notice batch version of isSpent(bytes32), returns an array of booleans
    function isSpentArray(bytes32[] calldata _nullifierHashes) external view returns (bool[] memory spent) {
        spent = new bool[](_nullifierHashes.length);
        for (uint256 i = 0; i < _nullifierHashes.length; i++) {
            if (isSpent(_nullifierHashes[i])) {
                spent[i] = true;
            }
        }
    }
}
