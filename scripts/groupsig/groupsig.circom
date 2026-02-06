pragma circom 2.0.2;

include "../../node_modules/circomlib/circuits/mimcsponge.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../circuits/eth_addr.circom";

/*
  Inputs:
  - addr1 (pub)
  - addr2 (pub)
  - addr3 (pub)
  - msg (pub)
  - nonce (pub)
  - privkey

  Intermediate values:
  - myAddr (supposed to be addr of privkey)
  
  Output:
  - msgAttestation
  
  Prove:
  - PrivKeyToAddr(privkey) == myAddr
  - (x - addr1)(x - addr2)(x - addr3) == 0
  - msgAttestation == mimc(msg, privkey)
*/

// TODO:
// 1. add nonce for safegarding against replac attacks
// 2. make scalable so that instead of addr1, addr2, and addr3 an array is used called: addrs
// 3. fix: No domain separation issue casued by cross-context replay
// 4. check validity of public key

template Main(n, k) {
    assert(n * k >= 256);
    assert(n * (k-1) < 256);

    // private inputs
    signal input privkey[k];

    // public inputs
    signal input addr1;
    signal input addr2;
    signal input addr3;
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

    // verify address is one of the provided
    signal temp;
    temp <== (myAddr - addr1) * (myAddr - addr2);
    0 === temp * (myAddr - addr3); // enforces: "I know myAddr is part of group (= addr1-3)"
    
    // produce signature
    component mimcAttestation = MiMCSponge(k+2, 220, 1); //+2 bcause of msg and nonce
    mimcAttestation.ins[0] <== msg;
    mimcAttestation.ins[1] <== nonce; // bind the proof to this specific nonce
    for (var i = 0; i < k; i++) {
        mimcAttestation.ins[i+2] <== privkey[i];
    }
    mimcAttestation.k <== 0;
    msgAttestation <== mimcAttestation.outs[0];
}

component main {public [addr1, addr2, addr3, msg, nonce]} = Main(64, 4);