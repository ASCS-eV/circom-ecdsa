# circom-ecdsa for private on-chain group signature verification 
This repository builds upon [circom-ecdsa](https://github.com/0xPARC/circom-ecdsa) to implement ECDSA operations adapted for the [ASCS on-chain SSI system](https://github.com/ASCS-eV/on-chain-ssi). 

Starting from the original group signature verification circuit (`./scripts/groupsig/groupsig.circom`), we have introduced several key enhancements:

* **Security & Scalability:** [secure_variable_groupsig.circom](./scripts/groupsig/secure_variable_groupsig.circom) improves security and enables support for variable group sizes.
* **Advanced Privacy:** [private_secure_variable_groupsig.circom](./scripts/groupsig/private_secure_variable_groupsig.circom) further extends these capabilities to include robust privacy features required for the [ASCS on-chain SSI system](https://github.com/ASCS-eV/on-chain-ssi).

## Set up
1. Run `yarn` at the top level to install npm dependencies (`snarkjs` and `circomlib`). 
2. Download `circom` version `>= 2.0.2` on your system. Installation instructions [here](https://docs.circom.io/getting-started/installation/).
3. Download ``ptau`` file with power 21 from the Hermez trusted setup from [this repository](https://github.com/iden3/snarkjs#7-prepare-phase-2) and copy it into the `circuits` folder of this repository, with the name `pot20_final.ptau`.
4. Optionally test the set up by running the group signature demo of the original repository: [circom-ecdsa](https://github.com/0xPARC/circom-ecdsa):
    1. Build key and wittness files by running `yarn build:groupsig` at the top level of this repo. This build process will create `r1cs` and `wasm` files for witness generation, as well as a `zkey` file (proving and verifying keys) in a the folder `./build/groupsig`. If no `zkey` file was generated and you are on windows, then:
        1. Install snarkjs gloablly like so: `npm install -g snarkjs`
        2. Instead of `yarn build:groupsig`, run `cd ./scripts/groupsig && ./windows_build_groupsig.sh` in Git Bash terminal
        3. Optional: move back to root folder (required for next step): `cd ../..`
    2. Run groupsig demo through `yarn groupsig-demo` at the top level of this repository and follow the instructions in your terminal by entering the [randomly generated](https://privatekeys.pw/keys/ethereum/random) valid inputs:
        1. private key: 0x3d87d34a290b124ad0b29b87053363d5dca57cd02650e4b1f4cc75e9c8275648 --> associated eth address: 0x68F3A3AfD9Cbf1cb27b5359b79B563A5E423115a
        2. addr1: 0x0F2D3bF9ce11737566E5bcef7222Df31C0D90395
        3. addr2: 0x46a8801DA492f6d2eADbd3ec30f4255c29aB656b
        4. nonce: 6789

## Usage
### Group signature verification with variable group size
**note**: the circuit for group signature verification with variable group size can be found here: `./scripts/groupsig/secure_variable_groupsig.circom`
1. Build key and wittnesses for variable number of company admins by 
    1. setting `SIZES=(2 3 4)` in script: `./scripts/groupsig/build_circuits.sh` (default is 2 to 4)
    2. executing the script for key and wittnesses by running ``cd ./scripts/groupsig && ./build_circuits.sh`` while in the root folder of this repo
2. For prototype demo of group signature verification with variable group size, run `yarn prototype-demo` at the top level of this repository and follow the instructions in the terminal. The demo requires inputs, for which you can use these [randomly generated](https://privatekeys.pw/keys/ethereum/random) valid inputs:
    1. private key: 0x3d87d34a290b124ad0b29b87053363d5dca57cd02650e4b1f4cc75e9c8275648 --> associated eth address: 0x68F3A3AfD9Cbf1cb27b5359b79B563A5E423115a
    2. addr1: 0x0F2D3bF9ce11737566E5bcef7222Df31C0D90395
    3. addr2: 0x46a8801DA492f6d2eADbd3ec30f4255c29aB656b
    4. addr3: 0xC8a6ab61Cc685586F3399857A4e80a75327fE4C0
    6. msg: bafybeicn7i3soqdgr7dwnrwytgq4zxy7a5jpkizrvhm5mv6bgjd32wm3q4
    6. nonce: 6789

### Private secure on-chain group signature verification with variable group size
**note**: the circuit for private secure group signature verification with variable group size can be found here: `./scripts/groupsig/private_secure_variable_groupsig.circom`

To create ZKPs for private secure on-chain group signature verification with variable group size, do the following steps:
1. build the ZKP generator files by running ``cd ./scripts/groupsig && ./build_private_groupsig_circuits.sh`` while in the root folder of this repository (**note**: enter 4 as input when asked for maximum group size and say "yes" to creation of ZKP-verifier smart contracts - both is essential for integrating private secure on-chain group signature verification as feature in the [on-chain SSI system of ASCS](https://github.com/ASCS-eV/on-chain-ssi))
2. test the ZKP generator files in build folder by running `node ./scripts/test_private_secure_variable_groupsig.js` while in the root folder of this repository (**note**: the test script solely works for four group members which must be considered during the first step's input for maximum group size)
3. Optional: integrate the newly generated files for private secure on-chain group signature verification as feature in the [on-chain SSI system of ASCS](https://github.com/ASCS-eV/on-chain-ssi), do the following steps:
    1. copy the content of the `./build/groupsig/verifiers` folder and add it to `./packages/trust-anchor-did-ethr/contracts/verifiers` folder of the [on-chain-ssi repository](https://github.com/ASCS-eV/on-chain-ssi/tree/main/packages/trust-anchor-did-ethr/contracts/verifiers)
    2. copy all folders with prefix `p_m_` that are in the folder `./build/groupsig` and add them to the `./packages/trust-anchor-did-ethr/circom-zkp-generator` folder of the [on-chain-ssi repository](https://github.com/ASCS-eV/on-chain-ssi/tree/main/packages/trust-anchor-did-ethr/circom-zkp-generator)

## Security analysis
The circuit for private secure group signature verification with variable group size (see `./scripts/groupsig/private_secure_variable_groupsig.circom`) must be used with caution due to existing security issues relevant for production:

1. **Trusted Setup:**
Circom with Groth16 requires a Phase 2 Trusted Setup. If the trust ceremony is not done correctly, or if the "Power of Tau" file is compromised (as it is the case for this prototype since we download a public ptau file), someone could generate fake proofs (forgeries) without knowing any private key.

2. **MiMic vs. ECDSA:**
MiMC is used because it is cheap and easy in zero-knowledge circuits and sufficient for demonstrating private-key ownership. However, it does not provide a standard digital signature. For real-world Ethereum applications, MiMC should ideally be replaced with in-circuit ECDSA verification to ensure compatibility, interoperability, and strong cryptographic guarantees. However, in-circuit ECDSA verification comes at the cost of more circuit constraints and thus worse performance.

3. **Scalar Malleability:**
    - *Risk:* The curve order \\( n \\) is slightly smaller than the field size \\( 2^{256} \\). If the circuit does not enforce that the private key lies in the range \\( 1 \\leq d < n \\), a prover can submit values such as \\( d \\) and \\( d + n \\). Both values generate the same public key and Ethereum address. This allows multiple valid witnesses for the same identity, enabling proof malleability, replay attacks, and potential bypass of double-spending protections.
    - *Recommendation:* Enforce a strict range check ensuring that the private key satisfies \\( 1 \\leq d < n \\), where \\( n \\) is the secp256k1 curve order. This should be implemented using multi-limb comparison circuits (e.g., `BigLessThan`) and zero-value checks to guarantee a unique canonical representation.

4. **Non-existent Points:**
    - *Risk:* Without explicitly verifying that a derived public key lies on the secp256k1 curve (i.e., satisfies \\( y^2 = x^3 + 7 \\)), a prover may use mathematically invalid points. These “fake” points can sometimes be mapped through the public-key-to-address hashing process to a valid Ethereum address, enabling identity forgery without possession of a legitimate private key.
    - *Recommendation:* Enforce point-on-curve validation by constraining the public key coordinates to satisfy the elliptic curve equation. If public keys are derived internally, ensure that the scalar multiplication circuit includes built-in curve membership checks. Prefer using audited elliptic curve components that guarantee valid point generation.

5. **Edge Case Exploits:**
    - *Risk:* Special values such as `0`, `1`, or multiples of the curve order may trigger undefined or unintended behavior in elliptic curve arithmetic, including producing the point at infinity or degenerate keys. These edge cases can result in addresses that do not correspond to any real user but can still be claimed by a malicious prover.
    - *Recommendation:* Explicitly forbid invalid scalar values, e.g. for nonce, by enforcing lower and upper bounds on private keys. Disallow zero and other degenerate values through dedicated zero-check constraints. Ensure that all elliptic curve operations are well-defined for the permitted input range.

6. **Forgery via Public Input Manipulation:**
    - *Risk*: The circuit proves membership in a list of ETH addresses but an attacker could take your valid proof and simply change the list of ETH addresses to different addresses. If the verifier doesn't check the entire set of addresses against a trusted root (like a Merkle Root), the proof is useless.
    - *Recommendation*: Instead of passing a lsit of ETH addresses, pass a Merkle Root as a public input and use a Merkle Proof (private input) to prove your address is in the set.
    - *Note*: In ASCS's use case, we can neglect this security issue (as of now) because the verifier is an on-chain smart contract which checks if the ETH addresses are actually part of the same and correct company by considering the did:ethr-based on-chain company structre.

## Potential optimizations
The circuit for private secure group signature verification with varibale group size (see `./scripts/groupsig/private_secure_variable_groupsig.circom`) should be optimized by considering the following:

1. **Membership Proof Is O(m):**
The current circuit verifies group membership by computing the product \\((myAddr - addrs[0]) \\times (myAddr - addrs[1]) \\times \\dots \\times (myAddr - addrs[m-1])\\), which requires one multiplication per group member. This means that the proving cost and circuit size grow linearly with the number of addresses in the group. As the group becomes large, this approach quickly becomes impractical due to high constraint counts, slower proof generation, and higher verification costs. A more scalable alternative is to use a Merkle tree or cryptographic accumulator. In this design, all valid addresses are committed into a single root hash, and the prover supplies a Merkle proof showing that their address is included in the tree. This reduces the complexity from O(m) to O(log m), making it feasible to support thousands or millions of members. Merkle-based membership proofs are widely used in modern zero-knowledge systems and are well-supported by existing Circom libraries, making them a practical and secure upgrade.

2. **Private Key Inside Circuit:**
The circuit directly includes the full Ethereum private key as a private witness and uses it both to derive the address and to generate the message attestation. While this is functionally correct, it significantly increases circuit complexity and proof generation time, because elliptic-curve operations and full key handling are expensive in zero-knowledge environments. It also increases the risk surface: if the prover’s environment is compromised, exposure of the witness leaks the actual Ethereum private key, which may control real funds. A better approach is to avoid embedding the long-term private key in the circuit and instead use derived or committed secrets. For example, the user can generate a random secret, commit to it on-chain, and link it to their address through a one-time signature or registration step. The circuit then proves knowledge of this secret rather than the main private key. Another option is to use nullifiers or hierarchical keys, where a dedicated ZK key is derived from the Ethereum key and used only for proofs. These approaches reduce computational cost, improve security isolation, and prevent direct exposure of high-value private keys inside zero-knowledge circuits.

3. **Improven Variable Group Size ZKP-Generation with Unified Circuit with Dynamic Group Padding:**
Currently, the system generates separate WASM and ZKey pairs for every possible group size (`m`). This requires the `DIDMultisigController` to maintain a mapping of verifier contracts and forces the client to download specific proving keys based on the admin count. We propose moving to a **Unified Max-Size Circuit** (e.g., `MAX_M = 100`). Instead of a strict product check, the circuit will be updated to ignore "Null Addresses" (`0x0`). This is achieved by implementing a conditional product factor. The final constraint remains $\\prod factor_i = 0$, but it will only be satisfied if `myAddr` matches one of the **non-zero** entries in the provided array. Benefits are **Single Verifier:** Only one `Verifier.sol` needs to be deployed on-chain, **Simplified Client:** The frontend no longer needs to switch between different WASM/ZKey files, and **Privacy:** A fixed array size of 100 hides the *actual* number of admins in a group, providing better metadata private (e.g., a group of 2 looks identical to a group of 50 on-chain). However, the trade-offs are **Proof Generation Time:** Proving for 100 slots takes longer than proving for 2, and **Gas Cost:** The public input array sent to the `verifyProof` function will always be 100 elements long, increasing calldata gas costs.