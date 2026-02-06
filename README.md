# circom-ecdsa

Implementation of ECDSA operations in circom.

## Set up for ASCS project goal
- Run `yarn` at the top level to install npm dependencies (`snarkjs` and `circomlib`). 

- Download `circom` version `>= 2.0.2` on your system. Installation instructions [here](https://docs.circom.io/getting-started/installation/).

- Download ``ptau`` file with power 21 from the Hermez trusted setup from [this repository](https://github.com/iden3/snarkjs#7-prepare-phase-2) and copy it into the `circuits` subdirectory of the project, with the name `pot20_final.ptau`.

- Build key and wittness by running `yarn build:groupsig` at the top level. This build process will create `r1cs` and `wasm` files for witness generation, as well as a `zkey` file (proving and verifying keys) in a the folder `./build/groupsig`. If no `zkey` file was generated and you are on windows, then:
    1. Install snarkjs gloablly like so: `npm install -g snarkjs`
    2. Instead of `yarn build:groupsig`, run `cd ./scripts/groupsig && ./windows_build_groupsig.sh` in Git Bash terminal
    3. Optional: move back to root folder (required for next step): `cd ../..`

- Test set up by running groupsig demo through `yarn groupsig-demo` at the top level and follow the instructions in your terminal. [Randomly generated](https://privatekeys.pw/keys/ethereum/random) valid inputs for demo:
    1. private key: 0x3d87d34a290b124ad0b29b87053363d5dca57cd02650e4b1f4cc75e9c8275648 --> associated eth address: 0x68F3A3AfD9Cbf1cb27b5359b79B563A5E423115a
    2. addr1: 0x0F2D3bF9ce11737566E5bcef7222Df31C0D90395
    3. addr2: 0x46a8801DA492f6d2eADbd3ec30f4255c29aB656b
    4. nonce: 6789

- For prototype: Build key and wittnesses for variable number of company admins by 
    1. setting `SIZES=(2 3 4)` in script: `./scripts/groupsig/build_circuits.sh` (default is 2 to 4)
    2. executing the script by running ``cd ./scripts/groupsig && ./build_circuits.sh`` while root folder of repo
- For prototype demo run `yarn prototype-demo` at the top level and follow the instructions in your terminal. [Randomly generated](https://privatekeys.pw/keys/ethereum/random) valid inputs for demo:
    1. private key: 0x3d87d34a290b124ad0b29b87053363d5dca57cd02650e4b1f4cc75e9c8275648 --> associated eth address: 0x68F3A3AfD9Cbf1cb27b5359b79B563A5E423115a
    2. addr1: 0x0F2D3bF9ce11737566E5bcef7222Df31C0D90395
    3. addr2: 0x46a8801DA492f6d2eADbd3ec30f4255c29aB656b
    4. addr3: 0xC8a6ab61Cc685586F3399857A4e80a75327fE4C0
    4. nonce: 6789

## Requirements for ASCS project goal
1. Enhanced security:
    1. replay attack: solved with nonce logic
2. Variable number of eth addresses as public input of circuit

## Security analysis
The upper requirements ensure enhanced security but other security matters must be consdiered and are divide in security issues for production and for the potential future of the project:

### Security issues for production
### Trusted Setup
Circom with Groth16 requires a Phase 2 Trusted Setup. If the trust ceremony is not done correctly, or if the "Power of Tau" file is compromised (as it is the case for this prototype since we download a public ptau file), someone could generate fake proofs (forgeries) without knowing any private key.

### Public key validation
The risk of missing public key validation boils down to **Proof Malleability** and **Identity Forgery**. In a production environment, if you don't constrain the public key to the rules of the elliptic curve ( for Ethereum), you leave the door open for mathematically "illegal" inputs that can trick the circuit.

The Risks are:
1. **Scalar Malleability:** The curve order (n) is slightly smaller than the field size (2^256). If you don't check that , a user could provide . Both might result in the same Ethereum address, allowing a user to generate two different valid proofs for the same "action," potentially bypassing double-spending or replay protections.
2. **Non-existent Points:** Without point validation (y^2 = x^3 + 7), a prover could potentially input a "fake" public key that doesn't exist on the curve but, through a collision in the hashing process (PubKey to Address), matches a target address.
3. **Edge Case Exploits:** Values like `0` or `1` can cause certain elliptic curve library components to behave unexpectedly (e.g., returning a "point at infinity"), which might result in an address that doesn't actually belong to anyone but can be claimed by a malicious prover.

The potential solutions for production are:
1. Range Constraints (The Scalar Check): You must ensure the private key is within the valid range of the secp256k1 group order. **How:** Use a `LessThan` component or a dedicated `BigLessThan` (since it's 256 bits) to compare the `privkey` against the constant  (the curve order).
2. Point-on-Curve Verification: If your `PrivKeyToAddr` component doesn't already do it, you must explicitly check the public key coordinates. **How:** Add a constraint that verifies the coordinates  of the public key satisfy the equation .
3. Use Audited Libraries: Don't write the curve math from scratch. For production, integrate tested circuits from established repositories. **Recommendation:** Use the `PrivKeyToAddr` or `VerifyPubkey` templates from the **[circom-ecdsa](https://github.com/0xPARC/circom-ecdsa)** library. These components are specifically designed to handle the 256-bit "BigInt" math and curve constraints required for Ethereum-compatible keys.


### Potential future security issues
1. **Deterministic Signatures (MiMC Vulnerability)**
    - *Risk*: The groupsig circuit uses mimc(msg, privkey). If you ever sign the same msg with the same privkey but a different nonce, you aren't leaking the key, but you are creating a linkable trail.
    - *Recommendation*: Ensure your attestation always includes all unique context (like a domain_separator) to ensure signatures cannot be "imported" from one app to another.
    - *Note*: In ASCS's use case, we can neglect this security issue (as of now) because the msg always contains the CID of the digital data asset uploaded to IPFS and to be published on the digital data asset marketplace. Therefore, the CID ensures domain seperation!
2. **Forgery via Public Input Manipulation**
    - *Risk*: The groupsig circuit proves membership in a list of ETH addresses but an attacker could take your valid proof and simply change the list of ETH addresses to different addresses. If the verifier doesn't check the entire set of addresses against a trusted root (like a Merkle Root), the proof is useless.
    - *Recommendation*: Instead of passing a lsit of ETH addresses, pass a Merkle Root as a public input and use a Merkle Proof (private input) to prove your address is in the set.
    - *Note*: In ASCS's use case, we can neglect this security issue (as of now) because the verifier is an on-chain smart contract which checks if the ETH addresses are actually part of the same and correct company by considering the did:ethr-based on-chain company structre.
3. **The "Frozen Heart" (Input Aliasing)**
    - *Risk*: Circom signals are in a prime field.If msg or nonce are larger than the field size ($p \approx 2^{254}$), they will wrap around (modulo $p$). An attacker could provide a msg that is OriginalMsg + p, and the circuit would produce the exact same attestation.
    - *Recommendation*: Always constrain your public inputs to be within a specific bit range (e.g., 253 bits) if they are derived from external data like Ethereum hashes.
    - *Note*: TODO: think about if this is an issue for the ASCS's use case?


## Project overview

This repository provides proof-of-concept implementations of ECDSA operations in circom. **These implementations are for demonstration purposes only**.  These circuits are not audited, and this is not intended to be used as a library for production-grade applications.

Circuits can be found in `circuits`. `scripts` contains various utility scripts (most importantly, scripts for building a few example zkSNARKs using the ECDSA circuit primitives). `test` contains some unit tests for the circuits, mostly for witness generation.

## Install dependencies
- Run `yarn` at the top level to install npm dependencies (`snarkjs` and `circomlib`). 
- You'll also need `circom` version `>= 2.0.2` on your system. Installation instructions [here](https://docs.circom.io/getting-started/installation/).
- If you want to build the `pubkeygen`, `eth_addr`, and `groupsig` circuits, you'll need to download a Powers of Tau file with `2^20` constraints and copy it into the `circuits` subdirectory of the project, with the name `pot20_final.ptau`. We do not provide such a file in this repo due to its large size. You can download and copy Powers of Tau files from the Hermez trusted setup from [this repository](https://github.com/iden3/snarkjs#7-prepare-phase-2).
- If you want to build the `verify` circuits, you'll also need a Powers of Tau file that can support at least `2^21` constraints (place it in the same directory as above with the same naming convention).

## Building keys and witness generation files

We provide examples of four circuits using the ECDSA primitives implemented here:
- `pubkeygen`: Prove knowledge of a private key corresponding to a ECDSA public key.
- `eth_addr`: Prove knowledge of a private key corresponding to an Ethereum address.
- `groupsig`: Prove knowledge of a private key corresponding to one of three Ethereum addresses, and attest to a specific message.
- `verify`: Prove that a ECDSA verification ran properly on a provided signature and message. Note that this circuit does not verify that the public key itself is valid. This must be done separately by the user.

Run `yarn build:pubkeygen`, `yarn build:eth_addr`, `yarn build:groupsig`, `yarn build:verify` at the top level to compile each respective circuit and keys.

Each of these will create a subdirectory inside a `build` directory at the top level (which will be created if it doesn't already exist). Inside this directory, the build process will create `r1cs` and `wasm` files for witness generation, as well as a `zkey` file (proving and verifying keys). Note that this process will take several minutes (see full benchmarks below).  Building `verify` requires 56G of RAM.

This process will also generate and verify a proof for a dummy input in the respective `scripts/[circuit_name]` subdirectory, as a smoke test.

## Circuits Description

The following circuits are implemented and can be found in `circuits/ecdsa.circom`.
* `ECDSAPrivToPub`: Given a secp256k1 private key, outputs the corresponding public key by computing `(private_key) * G` where `G` is the base point of secp256k1.
* `ECDSAVerifyNoPubkeyCheck`: Given a signature `(r, s)`, a message hash, and a secp256k1 public key, it follows ecdsa verification algorithm to extract `r'` from `s`, message hash and public key, and then compares `r'` with `r` to see if the signaure is correct. The output result is `1` if `r'` and `r` are equal, `0` otherwise.

The 256-bits input and output are chunked and represented as `k` `n`-bits values where `k` is `4` and `n` is `64`. Please see above examples for concrete usages.

WARNING: Beware that the input to the above circuits should be properly checked and guarded (Lies on the curve, not equal to zero, etc). The purpose of the above circuits is to serve as building blocks but not as stand alone circuits to deploy.

## Benchmarks

All benchmarks were run on a 16-core 3.0GHz, 32G RAM machine (AWS c5.4xlarge instance).

||pubkeygen|eth_addr|groupsig|verify|
|---|---|---|---|---|
|Constraints                          |95444 |247380 |250938 |1508136 |
|Circuit compilation                  |21s   |47s    |48s    |72s     |
|Witness generation                   |11s   |11s    |12s    |175s    |
|Trusted setup phase 2 key generation |71s   |94s    |98s    |841s    |
|Trusted setup phase 2 contribution   |9s    |20s    |19s    |149s    |
|Proving key size                     |62M   |132M   |134M   |934M    |
|Proving key verification             |61s   |81s    |80s    |738s    |
|Proving time                         |3s    |7s     |6s     |45s     |
|Proof verification time              |1s    |<1s    |1s     |1s      |

## Testing

Run `yarn test` at the top level to run tests. Note that these tests only test correctness of witness generation.  They do not check that circuits are properly constrained, i.e. that only valid witnesses satisfy the constraints.  This is a much harder problem that we're currently working on!

Circuit unit tests are written in typescript, in the `test` directory using `chai`, `mocha`, and `circom_tester`.  Running all tests takes about 1 hour on our 3.3GHz, 64G RAM test machine. To run a subset of the tests, use `yarn test --grep [test_str]` to run all tests whose description matches `[test_str]`.

## Groupsig CLI Demo

You can run a CLI demo of a zkSNARK-enabled group signature generator once you've built the `groupsig` keys. Simply run `yarn groupsig-demo` at the top level and follow the instructions in your terminal.

## Acknowledgments

This project was built during [0xPARC](http://0xparc.org/)'s [Applied ZK Learning Group #1](https://0xparc.org/blog/zk-learning-group).

We use a [circom implementation of keccak](https://github.com/vocdoni/keccak256-circom) from Vocdoni. We also use some circom utilities for converting an ECDSA public key to an Ethereum address implemented by [lsankar4033](https://github.com/lsankar4033), [jefflau](https://github.com/jefflau), and [veronicaz41](https://github.com/veronicaz41) for another ZK Learning Group project in the same cohort.  We use an optimization for big integer multiplication from [xJsnark](https://github.com/akosba/xjsnark).
