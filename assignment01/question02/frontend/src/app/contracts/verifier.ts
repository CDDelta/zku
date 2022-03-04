import * as ethers from 'ethers';

export function createVerifierContractInstance(
  provider: ethers.providers.Provider
) {
  return new ethers.Contract(verifierAddress, verifierAbi, provider);
}

const verifierAddress = '0x918f36f22689e13aae8907545576cc5386ed3b73';

const verifierAbi = `[
	{
		"inputs": [
			{
				"internalType": "uint256[2]",
				"name": "a",
				"type": "uint256[2]"
			},
			{
				"internalType": "uint256[2][2]",
				"name": "b",
				"type": "uint256[2][2]"
			},
			{
				"internalType": "uint256[2]",
				"name": "c",
				"type": "uint256[2]"
			},
			{
				"internalType": "uint256[9]",
				"name": "input",
				"type": "uint256[9]"
			}
		],
		"name": "verifyProof",
		"outputs": [
			{
				"internalType": "bool",
				"name": "r",
				"type": "bool"
			}
		],
		"stateMutability": "view",
		"type": "function"
	}
]`;
