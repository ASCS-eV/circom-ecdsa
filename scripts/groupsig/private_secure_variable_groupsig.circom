pragma circom 2.0.2;

include "../../node_modules/circomlib/circuits/mimcsponge.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../circuits/eth_addr.circom";

/*
  Inputs:
  - addrs[m] (pub)
  - pubHashHi, pubHashLo (pub)   // keccak(message) split
  - nonce (pub)

  - privHashHi, privHashLo (priv)
  - privkey

  Intermediate values:
  - myAddr

  Output:
  - msgAttestation

  Prove:
  - PrivKeyToAddr(privkey) == myAddr
  - myAddr ∈ addrs
  - privHash == pubHash
  - msgAttestation == mimc(hash, nonce, privkey)
*/


template Main(n, k, m) {

    assert(n * k >= 256);
    assert(n * (k-1) < 256);

    // --------------------------------------------------
    // Private Inputs
    // --------------------------------------------------

    signal input privkey[k];

    // Private keccak hash (split)
    signal input privHashHi;
    signal input privHashLo;


    // --------------------------------------------------
    // Public Inputs
    // --------------------------------------------------

    signal input addrs[m];

    // Public keccak hash (split)
    signal input pubHashHi;
    signal input pubHashLo;

    signal input nonce;


    // --------------------------------------------------
    // Internal
    // --------------------------------------------------

    signal myAddr;

    signal output msgAttestation;


    // --------------------------------------------------
    // Validate private key size
    // --------------------------------------------------

    component n2bs[k];

    for (var i = 0; i < k; i++) {

        n2bs[i] = Num2Bits(
            i == k-1 ? 256 - (k-1)*n : n
        );

        n2bs[i].in <== privkey[i];
    }


    // --------------------------------------------------
    // Compute Ethereum address
    // --------------------------------------------------

    component privToAddr = PrivKeyToAddr(n, k);

    for (var i = 0; i < k; i++) {
        privToAddr.privkey[i] <== privkey[i];
    }

    myAddr <== privToAddr.addr;


    // --------------------------------------------------
    // Group membership check
    // --------------------------------------------------

    signal products[m];

    products[0] <== myAddr - addrs[0];

    for (var i = 1; i < m; i++) {
        products[i] <== products[i-1] * (myAddr - addrs[i]);
    }

    0 === products[m-1];


    // --------------------------------------------------
    // Enforce hash consistency
    // --------------------------------------------------

    // Proves:
    // I know the preimage of pubHash
    privHashHi === pubHashHi;
    privHashLo === pubHashLo;


    // --------------------------------------------------
    // Produce ZK signature
    // --------------------------------------------------

    /*
      We sign:

      H(
        hash_hi,
        hash_lo,
        nonce,
        privkey
      )
    */

    component mimcAttestation = MiMCSponge(
        k + 3,     // hi, lo, nonce, privkey[]
        220,
        1
    );


    // Bind message hash
    mimcAttestation.ins[0] <== privHashHi;
    mimcAttestation.ins[1] <== privHashLo;

    // Bind nonce
    mimcAttestation.ins[2] <== nonce;


    // Bind private key
    for (var i = 0; i < k; i++) {
        mimcAttestation.ins[i+3] <== privkey[i];
    }

    mimcAttestation.k <== 0;

    msgAttestation <== mimcAttestation.outs[0];
}



// --------------------------------------------------
// Instantiation
// --------------------------------------------------

component main {public [
    addrs,
    pubHashHi,
    pubHashLo,
    nonce
]} = Main(64, 4, 2);
