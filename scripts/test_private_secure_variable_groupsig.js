const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const snarkjs = require("snarkjs");
const { ethers } = require("ethers");

// --------------------------------------------------
// Utils
// --------------------------------------------------

function splitHash(hashHex) {
    const hashBigInt = BigInt(hashHex);
    const lo = hashBigInt & ((1n << 128n) - 1n);
    const hi = hashBigInt >> 128n;

    return {
        hi: hi.toString(),
        lo: lo.toString()
    };
}

function generatePrivKey() {
    let privKey;

    do {
        privKey = BigInt("0x" + crypto.randomBytes(32).toString("hex"));
    } while (privKey === 0n || privKey >= ethers.constants.MaxUint256);

    return privKey;
}

function privKeyToAddress(privKey) {
    const wallet = new ethers.Wallet(
        privKey.toString(16).padStart(64, "0")
    );

    return BigInt(wallet.address);
}

function now() {
    return process.hrtime.bigint();
}

function elapsedMs(start, end) {
    return Number(end - start) / 1e6;
}


// --------------------------------------------------
// Main
// --------------------------------------------------

async function main() {

    const TOTAL_START = now();

    console.log("=================================");
    console.log(" ZK GroupSig Performance Test");
    console.log("=================================\n");


    // --------------------------------------------------
    // Message
    // --------------------------------------------------

    const nonce = 42;

    const cid = "QmTestCid123";
    const company = "0x1234567890123456789012345678901234567890";
    const marketplace = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd";

    const msgStr =
        `ZK_PUBLISH_V1-${nonce}-${cid}-for-${company}-on-${marketplace}`;

    const msgHash = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes(msgStr)
    );

    const { hi, lo } = splitHash(msgHash);


    // --------------------------------------------------
    // Private key
    // --------------------------------------------------

    const privKey = generatePrivKey();

    const privKeyWords = [];

    let pk = privKey;
    const mask64 = (1n << 64n) - 1n;

    for (let i = 0; i < 4; i++) {
        privKeyWords.push((pk & mask64).toString());
        pk >>= 64n;
    }


    // --------------------------------------------------
    // Group
    // --------------------------------------------------

    const addr = privKeyToAddress(privKey);

    const addrs = [
        addr,
        addr + 1n,
        addr + 2n,
        addr + 3n
    ];


    // --------------------------------------------------
    // Circuit input
    // --------------------------------------------------

    const input = {
        privkey: privKeyWords,

        privHashHi: hi,
        privHashLo: lo,

        pubHashHi: hi,
        pubHashLo: lo,

        addrs: addrs.map(a => a.toString()),

        nonce: nonce.toString()
    };


    // --------------------------------------------------
    // Paths
    // --------------------------------------------------

    const BASE = path.join(
        __dirname,
        "..",
        "build",
        "groupsig",
        "p_m_3"
    );

    const wasmPath = path.join(
        BASE,
        "private_secure_variable_groupsig_js",
        "private_secure_variable_groupsig.wasm"
    );

    const wcPath = path.join(
        BASE,
        "private_secure_variable_groupsig_js",
        "witness_calculator.js"
    );

    const zkeyPath = path.join(
        BASE,
        "private_secure_variable_groupsig.zkey"
    );

    const vkeyPath = path.join(
        BASE,
        "vkey.json"
    );

    const wtnsPath = path.join(
        BASE,
        "bench.wtns"
    );


    // --------------------------------------------------
    // Witness
    // --------------------------------------------------

    console.log("⚡ Generating witness...");

    const tWitStart = now();

    const builder = require(wcPath);

    const buffer = fs.readFileSync(wasmPath);

    const witnessCalculator = await builder(buffer);

    const witness = await witnessCalculator.calculateWTNSBin(
        input,
        0
    );

    fs.writeFileSync(wtnsPath, witness);

    const tWitEnd = now();

    console.log("✅ Witness done:",
        elapsedMs(tWitStart, tWitEnd).toFixed(2),
        "ms"
    );


    // --------------------------------------------------
    // Proof
    // --------------------------------------------------

    console.log("\n⚡ Generating proof...");

    const tProofStart = now();

    const { proof, publicSignals } =
        await snarkjs.groth16.prove(
            zkeyPath,
            wtnsPath
        );

    const tProofEnd = now();

    console.log("✅ Proof done:",
        elapsedMs(tProofStart, tProofEnd).toFixed(2),
        "ms"
    );


    // --------------------------------------------------
    // Verify
    // --------------------------------------------------

    console.log("\n⚡ Verifying proof...");

    const tVerStart = now();

    const vkey = JSON.parse(
        fs.readFileSync(vkeyPath)
    );

    const verified = await snarkjs.groth16.verify(
        vkey,
        publicSignals,
        proof
    );

    const tVerEnd = now();

    console.log("✅ Verify done:",
        elapsedMs(tVerStart, tVerEnd).toFixed(2),
        "ms"
    );


    // --------------------------------------------------
    // Summary
    // --------------------------------------------------

    const TOTAL_END = now();

    console.log("\n=================================");
    console.log(" Benchmark Results");
    console.log("=================================\n");

    console.log("Witness: ",
        elapsedMs(tWitStart, tWitEnd).toFixed(2), "ms");

    console.log("Proof:   ",
        elapsedMs(tProofStart, tProofEnd).toFixed(2), "ms");

    console.log("Verify:  ",
        elapsedMs(tVerStart, tVerEnd).toFixed(2), "ms");

    console.log("Total:   ",
        elapsedMs(TOTAL_START, TOTAL_END).toFixed(2), "ms");


    console.log("\nVerified:", verified ? "YES ✅" : "NO ❌");

    console.log("\n=================================\n");

    process.exit(0);
}


// --------------------------------------------------

main().catch(err => {
    console.error("ERROR:", err);
    process.exit(1);
});
