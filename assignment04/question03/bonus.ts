// a recursive proof system is kind of like an "enum"
@proofSystem
class RollupProof extends ProofWithInput<RollupStateTransition> {
  // Process a rollup deposit.
  @branch static processDeposit(
    pending: MerkleStack<RollupDeposit>,
    accountDb: AccountDb
  ): RollupProof {
    // Get the current state of the rollup.
    let before = new RollupState(pending.commitment, accountDb.commitment());
    // Pop the last inserted deposit from the deposit stack.
    let deposit = pending.pop();
    // Ensure that the account being deposited into does not yet exist.
    let [{ isSome }, mem] = accountDb.get(deposit.publicKey);
    isSome.assertEquals(false);

    // Initialise the rollup account with zero balance and nonce.
    let account = new RollupAccount(
      UInt64.zero,
      UInt32.zero,
      deposit.publicKey
    );
    accountDb.set(mem, account);

    // Get the resulting state of the rollup.
    let after = new RollupState(pending.commitment, accountDb.commitment());

    // Return a proof validating the performed state transition.
    return new RollupProof(new RollupStateTransition(before, after));
  }

  @branch static transaction(
    t: RollupTransaction,
    s: Signature,
    pending: MerkleStack<RollupDeposit>,
    accountDb: AccountDb
  ): RollupProof {
    // Verify that the provide signature was signed by the sender for the specified transaction.
    s.verify(t.sender, t.toFields()).assertEquals(true);

    // Get the current state of the rollup.
    let stateBefore = new RollupState(
      pending.commitment,
      accountDb.commitment()
    );

    // Get the sender's account, ensure that it exists and that the specified transaction nonce
    // matches the account's as expected.
    let [senderAccount, senderPos] = accountDb.get(t.sender);
    senderAccount.isSome.assertEquals(true);
    senderAccount.value.nonce.assertEquals(t.nonce);

    // Subtract the sender's sent amount from their balance and increment their nonce...
    senderAccount.value.balance = senderAccount.value.balance.sub(t.amount);
    senderAccount.value.nonce = senderAccount.value.nonce.add(1);

    // And update the sender's account state with the changes made.
    accountDb.set(senderPos, senderAccount.value);

    // Get the receiver's account, add their received amount, and update their account state.
    let [receiverAccount, receiverPos] = accountDb.get(t.receiver);
    receiverAccount.value.balance = receiverAccount.value.balance.add(t.amount);
    accountDb.set(receiverPos, receiverAccount.value);

    // Get the resulting state of the rollup.
    let stateAfter = new RollupState(
      pending.commitment,
      accountDb.commitment()
    );
    // Return a proof validating the performed state transition.
    return new RollupProof(new RollupStateTransition(stateBefore, stateAfter));
  }

  // Define how rollup proofs should be merged.
  @branch static merge(p1: RollupProof, p2: RollupProof): RollupProof {
    // Ensure that the result of the first proof is the input to the second proof.
    p1.publicInput.target.assertEquals(p2.publicInput.source);
    // Return a proof validating the the transition from the first proof's state to second proof's state.
    return new RollupProof(
      new RollupStateTransition(p1.publicInput.source, p2.publicInput.target)
    );
  }
}
