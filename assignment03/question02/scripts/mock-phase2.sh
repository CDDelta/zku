cd circuits

snarkjs powersoftau prepare phase2 ../../../pot14_0001.ptau pot14_final.ptau -v

snarkjs groth16 setup ./dist/cardcommit.r1cs pot14_final.ptau cardcommit_0000.zkey

snarkjs zkey contribute cardcommit_0000.zkey cardcommit_0001.zkey --name=mock-contrib -v

snarkjs zkey export verificationkey cardcommit_0001.zkey verification_key.json
