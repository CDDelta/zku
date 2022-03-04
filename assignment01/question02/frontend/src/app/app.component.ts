import { Component } from '@angular/core';
import * as ethers from 'ethers';
import { createNFTContractInstance } from './contracts/nft';

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
      const currentRoot = await nftContract.merkleRoot();

      this.mintLog += `Current NFT contract Merkle root: ${currentRoot}\n`;
    });

    this.mintLog += 'Initiating mint transaction...\n';

    // @ts-ignore
    await nftContract.safeMint(signerAddress);
  }
}
