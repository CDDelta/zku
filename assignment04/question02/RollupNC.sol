pragma solidity ^0.5.0;

import "../build/Update_verifier.sol";
import "../build/Withdraw_verifier.sol";

contract IMiMC {
    function MiMCpe7(uint256,uint256) public pure returns(uint256) {}
}

contract IMiMCMerkle {

    uint[16] public zeroCache;
    function getRootFromProof(
        uint256,
        uint256[] memory,
        uint256[] memory
    ) public view returns(uint) {}
    function hashMiMC(uint[] memory) public view returns(uint){}
}

contract ITokenRegistry {
    address public coordinator;
    uint256 public numTokens;
    mapping(address => bool) public pendingTokens;
    mapping(uint256 => address) public registeredTokens;
    modifier onlyCoordinator(){
        assert (msg.sender == coordinator);
        _;
    }
    function registerToken(address tokenContract) public {}
    function approveToken(address tokenContract) public onlyCoordinator{}
}

contract IERC20 {
    function transferFrom(address from, address to, uint256 value) public returns(bool) {}
	function transfer(address recipient, uint value) public returns (bool) {}
}

contract RollupNC is Update_verifier, Withdraw_verifier{

    IMiMC public mimc;
    IMiMCMerkle public mimcMerkle;
    ITokenRegistry public tokenRegistry;
    IERC20 public tokenContract;

    uint256 public currentRoot;
    address public coordinator;
    uint256[] public pendingDeposits;
    uint public queueNumber;
    uint public depositSubtreeHeight;
    uint256 public updateNumber;

    uint256 public BAL_DEPTH = 4;
    uint256 public TX_DEPTH = 2;

    // (queueNumber => [pubkey_x, pubkey_y, balance, nonce, token_type])
    mapping(uint256 => uint256) public deposits; //leaf idx => leafHash
    mapping(uint256 => uint256) public updates; //txRoot => update idx

    event RegisteredToken(uint tokenType, address tokenContract);
    event RequestDeposit(uint[2] pubkey, uint amount, uint tokenType);
    event UpdatedState(uint currentRoot, uint oldRoot, uint txRoot);
    event Withdraw(uint[9] accountInfo, address recipient);

    constructor(
        address _mimcContractAddr,
        address _mimcMerkleContractAddr,
        address _tokenRegistryAddr
    ) public {
        mimc = IMiMC(_mimcContractAddr);
        mimcMerkle = IMiMCMerkle(_mimcMerkleContractAddr);
        tokenRegistry = ITokenRegistry(_tokenRegistryAddr);
        currentRoot = mimcMerkle.zeroCache(BAL_DEPTH);
        coordinator = msg.sender;
        queueNumber = 0;
        depositSubtreeHeight = 0;
        updateNumber = 0;
    }

    modifier onlyCoordinator(){
        assert(msg.sender == coordinator);
        _;
    }

    /// Assignment 4 Q2.1.1
    function updateState(
            uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c,
            uint[3] memory input
        // Only accept a state update from the rollup coordinator.
        // This actually degrades the security of the rollup as users need to be able to advance the
        // rollup state to force exit but this is fine for a demo. Rollups in production generally
        // allow users to take over updating state after some period of coordinator downtime.
        ) public onlyCoordinator {
        // Verify that the proof being provided actually proves a transition from the current state.
        require(currentRoot == input[2], "input does not match current root");
        // Validate the proof of the specified state transition.
        require(update_verifyProof(a,b,c,input), "SNARK proof is invalid");
        // If the proof provided was valid, accept the state transition by updating our stored state root.
        currentRoot = input[0];

        updateNumber++;
        updates[input[1]] = updateNumber;
        // Emit a state updated event for anyone interested in tracking it.
        emit UpdatedState(input[0], input[1], input[2]); //newRoot, txRoot, oldRoot
    }

    /// Assignment 4 Q2.1.2
    // user tries to deposit ERC20 tokens
    function deposit(
        uint[2] memory pubkey,
        uint amount,
        uint tokenType
    ) public payable {
        if ( tokenType == 0 ) {
            // Validate rollup coordinator deposit (is actually the coordinator, not sending anything of value).
            require(
			   msg.sender == coordinator,
			   "tokenType 0 is reserved for coordinator");
            require(
			    amount == 0 && msg.value == 0,
			    "tokenType 0 does not have real value");
        } else if ( tokenType == 1 ) {
            // Validate parameters of user ETH transfer.
            require(
			    msg.value > 0 && msg.value >= amount,
			    "msg.value must at least equal stated amount in wei");
        } else if ( tokenType > 1 ) {
            // Validate that the token the user is trying to deposit is actually acceptable
            // and that they have approved the token for deposit.
            require(
				amount > 0,
				"token deposit must be greater than 0");
            address tokenContractAddress = tokenRegistry.registeredTokens(tokenType);
            tokenContract = IERC20(tokenContractAddress);
            require(
                tokenContract.transferFrom(msg.sender, address(this), amount),
                "token transfer not approved"
            );
        }

        // Push a leaf representing this deposit to the deposit queue.
        uint[] memory depositArray = new uint[](5);
        depositArray[0] = pubkey[0];
        depositArray[1] = pubkey[1];
        depositArray[2] = amount;
        depositArray[3] = 0;
        depositArray[4] = tokenType;

        uint depositHash = mimcMerkle.hashMiMC(
            depositArray
        );
        pendingDeposits.push(depositHash);
        // Emit a deposit request event for the coordinator and others to observe.
        emit RequestDeposit(pubkey, amount, tokenType);
        queueNumber++;
        // Update the deposit Merkle root with the new deposit included.
        uint tmpDepositSubtreeHeight = 0;
        uint tmp = queueNumber;
        while(tmp % 2 == 0){
            uint[] memory array = new uint[](2);
            array[0] = pendingDeposits[pendingDeposits.length - 2];
            array[1] = pendingDeposits[pendingDeposits.length - 1];
            pendingDeposits[pendingDeposits.length - 2] = mimcMerkle.hashMiMC(
                array
            );
            removeDeposit(pendingDeposits.length - 1);
            tmp = tmp / 2;
            tmpDepositSubtreeHeight++;
        }
        if (tmpDepositSubtreeHeight > depositSubtreeHeight){
            depositSubtreeHeight = tmpDepositSubtreeHeight;
        }
    }



    // coordinator adds certain number of deposits to balance tree
    // coordinator must specify subtree index in the tree since the deposits
    // are being inserted at a nonzero height
    function processDeposits(
        uint subtreeDepth,
        uint[] memory subtreePosition,
        uint[] memory subtreeProof
    ) public onlyCoordinator returns(uint256){
        uint emptySubtreeRoot = mimcMerkle.zeroCache(subtreeDepth); //empty subtree of height 2
        require(currentRoot == mimcMerkle.getRootFromProof(
            emptySubtreeRoot, subtreePosition, subtreeProof),
            "specified subtree is not empty");
        currentRoot = mimcMerkle.getRootFromProof(
            pendingDeposits[0], subtreePosition, subtreeProof);
        removeDeposit(0);
        queueNumber = queueNumber - 2**depositSubtreeHeight;
        return currentRoot;
    }

    /// Assignment 4 Q2.1.3
    function withdraw(
        uint[9] memory txInfo, //[pubkeyX, pubkeyY, index, toX ,toY, nonce, amount, token_type_from, txRoot]
        uint[] memory position,
        uint[] memory proof,
        address payable recipient,
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c
    ) public{
        // Validate the user is withdrawing a valid token.
        require(txInfo[7] > 0, "invalid tokenType");
        // Validate that the transaction root the user proved against was actually
        // once a part of the rollup.
        require(updates[txInfo[8]] > 0, "txRoot does not exist");
        uint[] memory txArray = new uint[](8);
        for (uint i = 0; i < 8; i++){
            txArray[i] = txInfo[i];
        }

        // Validate that the withdrawal transaction the user proved was actually
        // performed within the rollup.
        uint txLeaf = mimcMerkle.hashMiMC(txArray);
        require(txInfo[8] == mimcMerkle.getRootFromProof(
            txLeaf, position, proof),
            "transaction does not exist in specified transactions root"
        );

        // message is hash of nonce and recipient address
        uint[] memory msgArray = new uint[](2);
        msgArray[0] = txInfo[5];
        msgArray[1] = uint(recipient);

        // Validate that the withdrawal proof the user submitted is actually valid.
        require(withdraw_verifyProof(
            a, b, c,
            [txInfo[0], txInfo[1], mimcMerkle.hashMiMC(msgArray)]
            ),
            "eddsa signature is not valid");

        // Transfer the user their withdrawn tokens.
        if (txInfo[7] == 1){
            // ETH
            recipient.transfer(txInfo[6]);
        } else {
            // ERC20
            address tokenContractAddress = tokenRegistry.registeredTokens(txInfo[7]);
            tokenContract = IERC20(tokenContractAddress);
            require(
                tokenContract.transfer(recipient, txInfo[6]),
                "transfer failed"
            );
        }

        emit Withdraw(txInfo, recipient);
    }

    //call methods on TokenRegistry contract

    function registerToken(
        address tokenContractAddress
    ) public {
        tokenRegistry.registerToken(tokenContractAddress);
    }

    function approveToken(
        address tokenContractAddress
    ) public onlyCoordinator {
        tokenRegistry.approveToken(tokenContractAddress);
        emit RegisteredToken(tokenRegistry.numTokens(),tokenContractAddress);
    }

    // helper functions
    function removeDeposit(uint index) internal returns(uint[] memory) {
        require(index < pendingDeposits.length, "index is out of bounds");

        for (uint i = index; i<pendingDeposits.length-1; i++){
            pendingDeposits[i] = pendingDeposits[i+1];
        }
        delete pendingDeposits[pendingDeposits.length-1];
        pendingDeposits.length--;
        return pendingDeposits;
    }
}
