import { Component } from '@angular/core';
import * as ethers from 'ethers';
import { createNFTContractInstance } from './contracts/nft';
import { createVerifierContractInstance } from './contracts/verifier';

const snarkjs = (window as any).snarkjs;

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss'],
})
export class AppComponent {
  readonly provider = new ethers.providers.Web3Provider(
    (window as any).ethereum
  );

  mintLog = '';
  proofLog = '';

  async mint() {
    this.mintLog += 'Requesting MetaMask accounts...\n';

    await this.provider.send('eth_requestAccounts', []);

    const { chainId } = await this.provider.getNetwork();

    if (chainId != 3) {
      this.mintLog +=
        'Please change to the Ropsten network before continuing.\n';
      return;
    }

    const signer = this.provider.getSigner();
    const signerAddress = await signer.getAddress();

    const nftContract = createNFTContractInstance(this.provider).connect(
      signer
    );

    nftContract.on('Transfer', async (from, to, tokenId, event) => {
      if (to !== signerAddress) {
        return;
      }

      this.mintLog += `Minted NFT to ${to} with token id ${tokenId}!\n`;

      // @ts-ignore
      const currentRoot = await nftContract.readMerkleTreeNode(0);

      this.mintLog += `Current NFT contract Merkle root: ${currentRoot}\n`;
    });

    this.mintLog += 'Initiating mint transaction...\n';

    // @ts-ignore
    await nftContract.safeMint(signerAddress);
  }

  async generateAndVerifyMiMCMerkleTreeSNARKProof() {
    this.proofLog += 'Requesting MetaMask accounts...\n';

    await this.provider.send('eth_requestAccounts', []);

    const { chainId } = await this.provider.getNetwork();
    const signer = this.provider.getSigner();

    if (chainId != 3) {
      this.proofLog +=
        'Please change to the Ropsten network before continuing.\n';
      return;
    }

    this.proofLog += 'Retrieving NFT contract Merkle tree leaves...\n';

    const nftContract = createNFTContractInstance(this.provider).connect(
      signer
    );

    const leaves = await Promise.all(
      [...Array(8).keys()].map((leafIndex) => {
        const leafOffset = 8 - 1;
        // @ts-ignore
        return nftContract.retrieveMerkleTreeNode(leafIndex + leafOffset);
      })
    );

    this.proofLog += 'Generating MiMC Merkle tree SNARK proof...\n';

    const { proof, publicSignals } = await snarkjs.groth16.fullProve(
      { leaves },
      '/assets/prover/merkleroot.wasm',
      '/assets/prover/merkleroot_0001.zkey'
    );

    this.proofLog += 'Successfully generated MiMC Merkle tree SNARK proof!\n';

    const verifierContract = createVerifierContractInstance(
      this.provider
    ).connect(signer);

    this.proofLog += 'Initiating proof verification transaction...\n';

    // @ts-ignore
    const valid = await verifierContract.verifyProof(
      [proof.pi_a[0], proof.pi_a[1]],
      [proof.pi_b[0], proof.pi_b[1]],
      [proof.pi_c[0], proof.pi_c[1]],
      publicSignals
    );

    this.proofLog += `Proof verification resolved to: ${valid}\n`;
  }
}
