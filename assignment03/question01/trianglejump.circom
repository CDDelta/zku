pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/gates.circom";

template TriangleJump() {
    signal input energy;
    signal input a[2];
    signal input b[2];
    signal input c[2];
    signal output out;

    // Compute whether the jump from A to B is within the allowed distance.
    component ABWithinDistComparator = WithinDistance();
    ABWithinDistComparator.distance <== energy;
    ABWithinDistComparator.a[0] <== a[0];
    ABWithinDistComparator.a[1] <== a[1];
    ABWithinDistComparator.b[0] <== b[0];
    ABWithinDistComparator.b[1] <== b[1];

    // Compute whether the jump from B to C is within the allowed distance.
    component BCWithinDistComparator = WithinDistance();
    BCWithinDistComparator.distance <== energy;
    BCWithinDistComparator.a[0] <== b[0];
    BCWithinDistComparator.a[1] <== b[1];
    BCWithinDistComparator.b[0] <== c[0];
    BCWithinDistComparator.b[1] <== c[1];

    // Compute whether the points form a triangle.
    component triangleValidator = CheckPointsFormTriangle();
    triangleValidator.a[0] <== a[0];
    triangleValidator.a[1] <== a[1];
    triangleValidator.b[0] <== b[0];
    triangleValidator.b[1] <== b[1];
    triangleValidator.c[0] <== c[0];
    triangleValidator.c[1] <== c[1];
    
    // Check that all constraints for this move are met.
    component constraintsValidGate = MultiAND(3);
    constraintsValidGate.in[0] <== ABWithinDistComparator.out;
    constraintsValidGate.in[1] <== BCWithinDistComparator.out;
    constraintsValidGate.in[2] <== triangleValidator.out;
    
    out <== constraintsValidGate.out;
}

template WithinDistance() {
    signal input distance;
    signal input a[2];
    signal input b[2];
    signal output out;

    component sqDistanceCalulator = CalculateSquaredDistance();
    sqDistanceCalulator.a[0] <== a[0];
    sqDistanceCalulator.a[1] <== a[1];
    sqDistanceCalulator.b[0] <== b[0];
    sqDistanceCalulator.b[1] <== b[1];

    component distanceComparator = LessEqThan(64);
    distanceComparator.in[0] <== sqDistanceCalulator.out;
    distanceComparator.in[1] <== distance * distance;

    out <== distanceComparator.out;
}

template CalculateSquaredDistance() {
    signal input a[2];
    signal input b[2];
    signal output out;

    signal xDiff;
    signal yDiff;

    xDiff <== a[0] - b[0];
    yDiff <== a[1] - b[1];

    signal sqXDiff;
    signal sqYDiff;

    sqXDiff <== xDiff * xDiff;
    sqYDiff <== yDiff * yDiff;

    out <== sqXDiff + sqYDiff;
}

template CheckPointsFormTriangle() {
    signal input a[2];
    signal input b[2];
    signal input c[2];
    signal output out;

    signal s1;
    signal s2;
    signal s3;

    s1 <== a[0] * (b[1] - c[1]);
    s2 <== b[0] * (c[1] - a[1]);
    s3 <== c[0] * (a[1] - b[1]);

    signal s;
    s <== s1 + s2 + s3;

    component areaIsZeroComparator = IsZero();
    areaIsZeroComparator.in <== s;

    component areaIsNotZeroGate = NOT();
    areaIsNotZeroGate.in <== areaIsZeroComparator.out;

    out <== areaIsNotZeroGate.out;
}

component main = TriangleJump();