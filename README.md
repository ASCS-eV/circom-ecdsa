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
    6. msg: bafybeicn7i3soqdgr7dwnrwytgq4zxy7a5jpkizrvhm5mv6bgjd32wm3q4
    6. nonce: 6789

## Build and test final circuit for ASCS project goal
1. executing the script by running ``cd ./scripts/groupsig && ./build_private_groupsig_circuits.sh`` while root folder of repo
2. test by running `node ./scripts/test_private_secure_variable_groupsig.js` while root folder of repo (note: the test script solely works for three group members which must be considered during the first step)
3. copy the `./build/groupsig/verifiers` folder and add the folder to `./packages/trust-anchor-did-ethr/contracts` of the [on-chain-ssi repo](https://github.com/ASCS-eV/on-chain-ssi/tree/main/packages/trust-anchor-did-ethr/contracts)

## Produce files for on-chain verification of

## Requirements for ASCS project goal
1. Enhanced security:
    1. replay attack: solved with nonce logic
    2. domain seperation
2. Variable number of eth addresses as public input of circuit
3. Enhanced privacy by making the signature a private input of the circuit

## Security analysis
The upper requirements ensure enhanced security but other security matters must be consdiered and are divide in security issues for production and for the potential future of the project:

### Security issues for production
1. **Trusted Setup**
Circom with Groth16 requires a Phase 2 Trusted Setup. If the trust ceremony is not done correctly, or if the "Power of Tau" file is compromised (as it is the case for this prototype since we download a public ptau file), someone could generate fake proofs (forgeries) without knowing any private key.

2. **MiMic vs. ECDSA**
MiMC is used because it is cheap and easy in zero-knowledge circuits and sufficient for demonstrating private-key ownership. However, it does not provide a standard digital signature. For real-world Ethereum applications, MiMC should ideally be replaced with in-circuit ECDSA verification to ensure compatibility, interoperability, and strong cryptographic guarantees. However, in-circuit ECDSA verification comes at the cost of more circuit constraints and thus worse performance.

3. **Scalar Malleability**
    - *Risk:* The curve order \\( n \\) is slightly smaller than the field size \\( 2^{256} \\). If the circuit does not enforce that the private key lies in the range \\( 1 \\leq d < n \\), a prover can submit values such as \\( d \\) and \\( d + n \\). Both values generate the same public key and Ethereum address. This allows multiple valid witnesses for the same identity, enabling proof malleability, replay attacks, and potential bypass of double-spending protections.
    - *Recommendation:* Enforce a strict range check ensuring that the private key satisfies \\( 1 \\leq d < n \\), where \\( n \\) is the secp256k1 curve order. This should be implemented using multi-limb comparison circuits (e.g., `BigLessThan`) and zero-value checks to guarantee a unique canonical representation.

4. **Non-existent Points**
    - *Risk:* Without explicitly verifying that a derived public key lies on the secp256k1 curve (i.e., satisfies \\( y^2 = x^3 + 7 \\)), a prover may use mathematically invalid points. These “fake” points can sometimes be mapped through the public-key-to-address hashing process to a valid Ethereum address, enabling identity forgery without possession of a legitimate private key.
    - *Recommendation:* Enforce point-on-curve validation by constraining the public key coordinates to satisfy the elliptic curve equation. If public keys are derived internally, ensure that the scalar multiplication circuit includes built-in curve membership checks. Prefer using audited elliptic curve components that guarantee valid point generation.

5. **Edge Case Exploits**
    - *Risk:* Special values such as `0`, `1`, or multiples of the curve order may trigger undefined or unintended behavior in elliptic curve arithmetic, including producing the point at infinity or degenerate keys. These edge cases can result in addresses that do not correspond to any real user but can still be claimed by a malicious prover.
    - *Recommendation:* Explicitly forbid invalid scalar values by enforcing lower and upper bounds on private keys. Disallow zero and other degenerate values through dedicated zero-check constraints. Ensure that all elliptic curve operations are well-defined for the permitted input range.

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

## Potential optimizations
1. **Membership Proof Is O(m)**
The current circuit verifies group membership by computing the product \\((myAddr - addrs[0]) \\times (myAddr - addrs[1]) \\times \\dots \\times (myAddr - addrs[m-1])\\), which requires one multiplication per group member. This means that the proving cost and circuit size grow linearly with the number of addresses in the group. As the group becomes large, this approach quickly becomes impractical due to high constraint counts, slower proof generation, and higher verification costs. A more scalable alternative is to use a Merkle tree or cryptographic accumulator. In this design, all valid addresses are committed into a single root hash, and the prover supplies a Merkle proof showing that their address is included in the tree. This reduces the complexity from O(m) to O(log m), making it feasible to support thousands or millions of members. Merkle-based membership proofs are widely used in modern zero-knowledge systems and are well-supported by existing Circom libraries, making them a practical and secure upgrade.

2. **Private Key Inside Circuit**
The circuit directly includes the full Ethereum private key as a private witness and uses it both to derive the address and to generate the message attestation. While this is functionally correct, it significantly increases circuit complexity and proof generation time, because elliptic-curve operations and full key handling are expensive in zero-knowledge environments. It also increases the risk surface: if the prover’s environment is compromised, exposure of the witness leaks the actual Ethereum private key, which may control real funds. A better approach is to avoid embedding the long-term private key in the circuit and instead use derived or committed secrets. For example, the user can generate a random secret, commit to it on-chain, and link it to their address through a one-time signature or registration step. The circuit then proves knowledge of this secret rather than the main private key. Another option is to use nullifiers or hierarchical keys, where a dedicated ZK key is derived from the Ethereum key and used only for proofs. These approaches reduce computational cost, improve security isolation, and prevent direct exposure of high-value private keys inside zero-knowledge circuits.

---
---
---
# README OF CRICOM-ECSDSA

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
