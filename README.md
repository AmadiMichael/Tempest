# Tempest

Tempest is a privacy solution, enables users to deposit tokens into a smart contract and anonymously withdraw, partially withdraw or confidentially `send` (trustlessly exchange knowledge of preimage of commitment hash) of these tokens.

## Features

- Deposit: Depositing a note (any amount of a token) into the smart contract. Not a confidential operation
- Withdraw: Withdrawing all of the note anonymously via incentivized relayers (No link between your withdrawal and your deposit)
- Partial Withdraw: Withdrawing part of a notes total value anonymously via incentivized relayers. This results in a new note (change) similar to how you get a #50 change if you give a shop a #100 note for a #50 product
- Shielded (Confidential) transfer: Send part of all of the value of a note to a new note where only the recipient has the info to generate a proof to use that new note. This works in 2 steps with the sender generating a `send proof` and sends this alongside some info to the receiver who uses this info to generate a `claim proof` and submits both proofs onchain. `This process, when used with a relayer leaks no info about what the sender, receiver or amount is`.
  - This can also be used to make open-ended transfers where a sender generates a `transfer proof` and broadcasts it to a set of people, whoever generates a `claim proof` first and submits the transaction gets the value sent.

## Brief Overview

- All deposits are stored in a sparse merkle tree of a fixed leaf node length of 2\*\*20 and arity of 2.
- Each leaf node is assumed to have a default value of `0x2b0f6fc0179fa65b6f73627c0e1e84c7374d2eaec44c9a48f2571393ea77bcbb`.
- Commitment hash: Poseidon(nullifier, 0, denomination)
- Nullifier hash: Poseidon(nullifier, 1, leafIndex, denomination)
- New deposits create a commitment hash that overwrites the default values of a leaf node, starting at index 0.
- Withdrawals use a nullifier hash that is `nullified` when used to prevent double-spend.
- Partial withdrawals can be made where a note (commitment hash) is consumed and the change is redeposited into a new leaf node which the withdrawer is assumed to know the preimage of the commitment hash of.
- Shielded (confidential) transfers where the sender can send any amount of tokens <= "any note they can prove that they know the preimage of" to another user and only this user know this new preimage to prevent the sender from spending it. This can be done by:
  - Sender has 10 eth at index 2 (nb: current next leaf index is 7)
  - Sender wants to send 5 eth to receiver
  - Sender creates a `partial-like withdrawal proof` that proves:
    - Withdrawal of 10 eth from index 2
    - deposit of 5 eth into index 7 (next leaf index) as change
    - deposit of remaining 5 eth into index 8 as a `shared receiver leaf`
    - sends the nullifier hash and preimage of `shared receiver leaf` and also proof created above to recipient
  - Recipient creates a `partial-like withdrawal proof` also that proves:
    - Withdrawal of 5 eth from index 8
    - deposit of 5 eth into index 9 (next leaf index) as change
    - sends the proof from above and proof received from sender to contract.
  - Because recipient redeposits the `shared receiver leaf`'s balance into a leaf that only they know the preimage of the commitment hash of, they are sure that only they can make a withdrawal.
  - With this, nobody knows the sender, receiver or amount sent.

## Technical Overview

### Deposit:

- Signals:
  - Public: `oldRoot`, `commitmentHash`, `denomination`, `root`
  - Private: `nullifier`, `topNodes`, `pathElements`, `pathIndices`
- Circuit: The circuit constrains that

  - The commitment hash signal is same as poseidon(`nullifier`, 0, `denomination`) calculated in the circuit
  - `topNodes`[0] is equal to the top `pathElement` or `topNodes`[1] is equal to the top `pathElement`
  - poseidon(`topNodes`[0], `topNodes`[1]) == `oldRoot`
  - `oldRoot`.insert(`commitmentHash`) hashes up to a new root == `root`

### Withdraw:

- Signals:
  - Public: `root`, `nullifierHash`, `denomination`, `recipient`, `relayer`, `fee`
  - Private: `nullifier`, `pathElements`, `pathIndices`
- Circuit:
  - The nullifier hash signal is same as poseidon(`nullifier`, 1, `leafIndex`, `denomination`) calculated in the circuit
  - The commitment hash signal is same as poseidon(`nullifier`, 0, `denomination`) calculated in the circuit
  - commitment hash when added to the pathElements hash up to the root
  - square `recipient`, `relayer`, `fee` to add them into the constraint to avoid relayer/frontrunners replacing them and contract not reverting

### Partial Withdraw:

- Signals:
  - Public: `oldRoot`, `nullifierHash`, `amount`, `changeCommitmentHash`, `newRoot`, `recipient`, `relayer`, `fee`
  - Private: `denomination`, `nullifier`, `changeNullifier`, `pathElements`, `pathIndices`, `topNodes`, `afterPathElements`, `afterPathIndices`
- Circuit:
  - Prove everything in the withdrawal circuit above to withdraw from src leaf node
  - prove `amount` <= `denomination`
  - prove `amount` > 0
  - prove everything in the deposit circuit above to deposit change (denomination - change) into next leaf index

### Shielded (Confidential) Transfers:

- Sender generates Shielded Transfer proof:
  - Signals:
    - Public: `oldRoot`, `nullifierHash`, `changeCommitmentHash`, `destCommitmentHash`, `rootAfterChangeWasAdded`, `rootAfterDestWasAdded`
    - Private: `amount`, `denomination`, `nullifier`, `changeNullifier`, `destNullifier`, `pathElements`, `pathIndices`, `topNodes`, `afterPathElements`, `afterPathIndices`, `topNodes2`, `afterPathElements2`, `afterPathIndices2`
  - Circuit:
    - Prove everything in the withdrawal circuit above to withdraw from src leaf node
    - Prove amount <= denomination
    - Prove everything in the deposit circuit above to deposit change amount (denomination - amount) into next leaf index
    - Prove everything in the deposit circuit above to deposit recipient amount (amount) into next leaf index (shared recipient leaf)
- Recipient generates Shielded Claim proof:
  - Signals:
    - Public: `oldRoot`, `nullifierHash`, `changeCommitmentHash`, `newRoot`
    - Private: `denomination`, `nullifier`, `changeNullifier`, `pathElements`, `pathIndices`, `topNodes`, `afterPathElements`, `afterPathIndices`
  - Circuit:
    - Prove everything in the withdrawal circuit above to withdraw everything from shared recipient leaf
    - prove everything in the deposit circuit above to deposit everything into next leaf index

## Using relayers for shielded (confidential) transfers

`Relayer` and `fee` are not included for shielded transfers. This was intentional and was done to avoid giving out info on the amount being sent. But then this might mean (to outside observers) that someone aware of the transaction (one of the parties) will be the one to broadcast the transaction and this might give a hint as to who the sender/recipient is. A solution to this is for the recipient to create another shielded transfer proof and send this to the relayer who creates a shielded claim proof for that and then sends both (`sender <-> recipient` & `recipient <-> relayer`) confidential transfers onchain via a multicall contract. This way, only the sender and recipient know the exact amount and parties involved and all the relayer knows is the logical lower bound the amount might be (if they assume that the recipient won't pay a fee higher than or even close to the actual amount sent). There is a test showcasing this in `test/ShieldedTransfer.t.sol:ShieldedTransferTest::test_shielded_transfer_via_relayer()`
