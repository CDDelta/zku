pragma circom 2.0.0;

include "../../../node_modules/circomlib/circuits/comparators.circom";
include "../../../node_modules/circomlib/circuits/gates.circom";
include "../../../node_modules/circomlib/circuits/mimcsponge.circom";

template CardCommit() {
    signal input trapdoor;
    signal input currCard;
    signal input prevCard;
    signal input prevCardCommitment;

    signal output currCardCommitment;

    assert(currCard <= 52);
    assert(prevCard <= 52);

    // Verify that the computed commitment of the previous card matches the one provided
    // or that no card was selected previously.
    component prevCardCommitmentValidator = ValidateCardCommitment();
    prevCardCommitmentValidator.card <== prevCard;
    prevCardCommitmentValidator.trapdoor <== trapdoor;
    prevCardCommitmentValidator.commitment <== prevCardCommitment;

    // Treat 52 as the sentinel for no card having previously been selected.
    component prevCardNotSelectedComparator = IsEqual();
    prevCardNotSelectedComparator.in[0] <== prevCard;
    prevCardNotSelectedComparator.in[1] <== 52;

    component prevCardValidator = XOR();
    prevCardValidator.a <== prevCardCommitmentValidator.out;
    prevCardValidator.b <== prevCardNotSelectedComparator.out;

    prevCardValidator.out === 1;

    // Verify that the two cards are from the same suite,
    // if a card had previously been selected.
    component prevCardSelectedGate = NOT();
    prevCardSelectedGate.in <== prevCardNotSelectedComparator.out;

    signal prevSuite;
    signal currSuite;

    prevSuite <== prevCard \ 13;
    currSuite <== currCard \ 13;

    (currSuite - prevSuite) * prevCardSelectedGate.out === 0;

    // Compute and return a commitment to the current card.
    component currCardCommitter = ComputeCardCommitment();
    currCardCommitter.card <== currCard;
    currCardCommitter.trapdoor <== trapdoor;

    currCardCommitment <== currCardCommitter.out;
}

template ValidateCardCommitment() {
    signal input card;
    signal input trapdoor;
    signal input commitment;
    signal output out;

    component committer = ComputeCardCommitment();
    committer.card <== card;
    committer.trapdoor <== trapdoor;

    component commitmentValidator = IsEqual();
    commitmentValidator.in[0] <== commitment;
    commitmentValidator.in[1] <== committer.out;

    out <== commitmentValidator.out;
}

template ComputeCardCommitment() {
    signal input card;
    signal input trapdoor;
    signal output out;

    component hasher = MiMCSponge(2, 220, 1);
    hasher.k <== 0;
    hasher.ins[0] <== card;
    hasher.ins[1] <== trapdoor;

    out <== hasher.outs[0];
}

component main {public [prevCardCommitment]} = CardCommit();