pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/mimcsponge.circom";

template MerkleRoot(N) {
    signal input leaves[N];
    signal output out;

    assert(N > 2 && N % 2 == 0);

    component hashers[N - 1];

    for (var i = 0; i < N / 2; i++) {
        hashers[i + N / 2 - 1] = MerkleHasher();
        hashers[i + N / 2 - 1].ins[0] <== leaves[2 * i];
        hashers[i + N / 2 - 1].ins[1] <== leaves[2 * i + 1];
    }

    for (var i = N / 2 - 2; i >= 0; i--) {
        hashers[i] = MerkleHasher();
        hashers[i].ins[0] <== hashers[2 * i + 1].out;
        hashers[i].ins[1] <== hashers[2 * i + 2].out;
    }

    out <== hashers[0].out;
}

template MerkleHasher() {
    signal input ins[2];
    signal output out;

    component hasher = MiMCSponge(2, 220, 1);
    hasher.k <== 0;
    hasher.ins[0] <== ins[0];
    hasher.ins[1] <== ins[1];

    out <== hasher.outs[0];
}

component main {public [leaves]} = MerkleRoot(4);