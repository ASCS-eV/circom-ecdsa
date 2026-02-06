pragma circom 2.0.2;

include "../../node_modules/circomlib/circuits/mimcsponge.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../circuits/eth_addr.circom";

/*
  Inputs:
  - addrs[m] (pub)
  - msg (pub)
  - nonce (pub)
  - privkey

  Intermediate values:
  - myAddr (supposed to be addr of privkey)
  
  Output:
  - msgAttestation
  
  Prove:
  - PrivKeyToAddr(privkey) == myAddr
  - (myAddr - addrs[0]) * (myAddr - addrs[1]) * ... * (myAddr - addrs[m-1]) == 0
  - msgAttestation == mimc(msg, nonce, privkey)
*/

// TODO:
// 1. add nonce for safegarding against replac attacks
// 2. make scalable so that instead of addr1, addr2, and addr3 an array is used called: addrs
// 3. fix: No domain separation issue casued by cross-context replay
// 4. check validity of public key

// n: bits per word, k: number of words for privkey, m: number of addresses in group
template Main(n, k, m) {
    assert(n * k >= 256);
    assert(n * (k-1) < 256);

    // private inputs
    signal input privkey[k];

    // public inputs
    signal input addrs[m]; // Scalable array of addresses
    signal input msg;
    signal input nonce; // to protect against replay attacks

    signal myAddr;

    signal output msgAttestation;

    // check that privkey properly represents a 256-bit number
    component n2bs[k];
    for (var i = 0; i < k; i++) {
        n2bs[i] = Num2Bits(i == k-1 ? 256 - (k-1) * n : n);
        n2bs[i].in <== privkey[i];
    }

    // compute addr
    component privToAddr = PrivKeyToAddr(n, k);
    for (var i = 0; i < k; i++) {
        privToAddr.privkey[i] <== privkey[i];
    }
    myAddr <== privToAddr.addr; // enforces: "I know a private key whose Ethereum address is myAddr"

    // verify address is one of the provided (SCALABLE MEMBERSHIP CHECK)
    // We check: (myAddr - addrs[0]) * (myAddr - addrs[1]) * ... * (myAddr - addrs[m-1]) === 0
    // If myAddr is equal to any one of the addrs, the entire product becomes zero.
    signal products[m];
    products[0] <== myAddr - addrs[0];
    for (var i = 1; i < m; i++) {
        products[i] <== products[i-1] * (myAddr - addrs[i]);
    }
    
    // The final result must be 0
    0 === products[m-1]; // enforces: "I know myAddr is part of group (= addrs[m])"
    
    // produce signature
    component mimcAttestation = MiMCSponge(k+2, 220, 1); //+2 bcause of msg and nonce
    mimcAttestation.ins[0] <== msg;
    mimcAttestation.ins[1] <== nonce; // bind the proof to this specific nonce
    for (var i = 0; i < k; i++) {
        mimcAttestation.ins[i+2] <== privkey[i]; // enforces: "I know that the private key of myAddr signed msg"
    }
    mimcAttestation.k <== 0;
    msgAttestation <== mimcAttestation.outs[0];
}

// Set 'm' (third argument) to the number of addresses you want in your group
component main {public [addrs, msg, nonce]} = Main(64, 4, 4);