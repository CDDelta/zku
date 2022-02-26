async function deployContract(contractName) {
  const constructorArgs = [["0x45495031353539"]];

  const artifactsPath = `browser/contracts/artifacts/${contractName}.json`;

  const metadata = JSON.parse(
    await remix.call("fileManager", "getFile", artifactsPath)
  );
  const accounts = await web3.eth.getAccounts();

  let contract = new web3.eth.Contract(metadata.abi);

  contract = contract.deploy({
    data: metadata.data.bytecode.object,
    arguments: constructorArgs,
  });

  const newContractInstance = await contract.send({
    from: accounts[0],
    gas: 1500000,
    gasPrice: "30000000000",
  });

  console.log(
    "Contract deployed at address: ",
    newContractInstance.options.address
  );

  return newContractInstance;
}

(async () => {
  try {
    console.log("Running compareBallotGas script...");

    const accounts = await web3.eth.getAccounts();
    const originalBallotContract = await deployContract("BallotOriginal");
    const ballotContract = await deployContract("Ballot");

    let gasUsedOriginally = 0;

    for (let i = 1; i <= 10; i++) {
      const tx = await originalBallotContract.methods
        .giveRightToVote(accounts[i])
        .send({
          from: accounts[0],
        });

      gasUsedOriginally += tx.gasUsed;
    }

    const newBallotTx = await ballotContract.methods
      .giveRightToVote(accounts.slice(1, 11))
      .send({
        from: accounts[0],
      });

    console.log("Original gas usage: " + gasUsedOriginally + " gwei");
    console.log("Optimized gas usage: " + newBallotTx.gasUsed + " gwei");
  } catch (e) {
    console.log(e.message);
  }
})();
