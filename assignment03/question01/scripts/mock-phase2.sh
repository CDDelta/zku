snarkjs powersoftau prepare phase2 ../../pot14_0001.ptau pot14_final.ptau -v

snarkjs groth16 setup ./dist/trianglejump.r1cs pot14_final.ptau trianglejump_0000.zkey

snarkjs zkey contribute trianglejump_0000.zkey trianglejump_0001.zkey --name=mock-contrib -v

snarkjs zkey export verificationkey trianglejump_0001.zkey verification_key.json
