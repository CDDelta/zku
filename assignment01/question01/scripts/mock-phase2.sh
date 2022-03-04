snarkjs powersoftau prepare phase2 ../../pot14_0001.ptau pot14_final.ptau -v

snarkjs groth16 setup ./dist/merkleroot.r1cs pot14_final.ptau merkleroot_0000.zkey

snarkjs zkey contribute merkleroot_0000.zkey merkleroot_0001.zkey --name=mock-contrib -v

snarkjs zkey export verificationkey merkleroot_0001.zkey verification_key.json
