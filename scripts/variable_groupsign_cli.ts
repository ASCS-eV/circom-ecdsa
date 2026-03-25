const snarkjs = require('snarkjs');
const readline = require('readline');
const { BigNumber, Wallet } = require('ethers');
const fs = require('fs');
const path = require('path');

// --- PATH CONFIGURATION ---
// Use resolve to get absolute paths from the start
const PROJECT_ROOT = path.resolve(__dirname, '..');
const BUILD_BASE = path.join(PROJECT_ROOT, 'build', 'groupsig');
const wtnsFile = path.join(BUILD_BASE, 'witness.wtns');

// --- HELPER FUNCTIONS ---

function getAvailableGroupSizes(): number[] {
    if (!fs.existsSync(BUILD_BASE)) return [];
    return fs.readdirSync(BUILD_BASE)
        .filter((name: string) => name.startsWith('m_'))
        .map((name: string) => parseInt(name.split('_')[1]))
        .sort((a: number, b: number) => a - b);
}

function isHex(str: string): boolean {
    if (str.startsWith('0x')) str = str.slice(2);
    const allowedChars = '0123456789abcdefABCDEF';
    for (let i = 0; i < str.length; i++)
        if (!allowedChars.includes(str[i])) return false;
    return true;
}

function isValidAddr(addr: string): boolean {
    if (addr.length !== 42) return false;
    if (!isHex(addr)) return false;
    return true;
}

function toWordArray(x: bigint, nWords: number, bitsPerWord: number): string[] {
    const res: string[] = [];
    let remaining = x;
    const base = 2n ** BigInt(bitsPerWord);
    for (let i = 0; i < nWords; i++) {
        res.push((remaining % base).toString());
        remaining /= base;
    }
    return res;
}

async function generateWitness(inputs: any, wasmPath: string, sizeDir: string) {
    const wcPath = path.join(sizeDir, 'secure_variable_groupsig_js', 'witness_calculator.js');

    console.log(`Using WASM: ${wasmPath}`);
    
    if (!fs.existsSync(wcPath)) {
        throw new Error(`witness_calculator.js not found at ${wcPath}`);
    }

    // Dynamic require using absolute path
    const builder = require(wcPath);
    
    const buffer = fs.readFileSync(wasmPath);
    const witnessCalculator = await builder(buffer);
    const buff = await witnessCalculator.calculateWTNSBin(inputs, 0);
    fs.writeFileSync(wtnsFile, buff);
}

// --- MAIN LOGIC ---

async function run() {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    const availableSizes = getAvailableGroupSizes();

    if (availableSizes.length === 0) {
        console.error(`❌ No compiled circuits found. Searched in: ${BUILD_BASE}`);
        process.exit(1);
    }

    console.log(`Found compiled circuits for group sizes: ${availableSizes.join(', ')}`);

    // 1. Private Key Input
    const privKeyStr = await new Promise<string>((res) => {
        rl.question("Enter an ETH private key:\n", (ans: string) => res(ans));
    });
    const wallet = new Wallet(privKeyStr);
    console.log(`Your address is: ${wallet.address}`);

    // 2. Select Group Size
    const mStr = await new Promise<string>((res) => {
        rl.question(`How many total addresses (${availableSizes[0]}-${availableSizes[availableSizes.length-1]})?\n`, (ans: string) => res(ans));
    });
    const m = parseInt(mStr);

    if (!availableSizes.includes(m)) {
        console.error(`❌ Circuit for size ${m} not found.`);
        process.exit(1);
    }

    // Define ABSOLUTE paths for the selected size
    const sizeDir = path.join(BUILD_BASE, `m_${m}`);
    const wasm = path.join(sizeDir, 'secure_variable_groupsig_js', 'secure_variable_groupsig.wasm');
    const zkey = path.join(sizeDir, 'secure_variable_groupsig.zkey');
    const vkey = path.join(sizeDir, 'vkey.json');

    // 3. Collect Other Addresses
    const otherAddrs: string[] = [];
    for (let i = 0; i < m - 1; i++) {
        const addr = await new Promise<string>((res) => {
            rl.question(`Enter address ${i + 1}/${m - 1} of other members:\n`, (ans: string) => res(ans));
        });
        if (!isValidAddr(addr)) throw new Error('Invalid address');
        otherAddrs.push(addr);
    }

    // 4. Group Construction (Shuffle)
    const groupAddresses: string[] = otherAddrs.map(a => BigInt(a).toString());
    const myIdx = Math.floor(Math.random() * m);
    groupAddresses.splice(myIdx, 0, BigInt(wallet.address).toString());

    // 5. Message & Nonce
    const msg = await new Promise<string>((res) => {
        rl.question("Enter message:\n", (ans: string) => res(ans));
    });
    const nonce = await new Promise<string>((res) => {
        rl.question("Enter nonce:\n", (ans: string) => res(ans));
    });

    const input = {
        privkey: toWordArray(BigInt(privKeyStr), 4, 64),
        addrs: groupAddresses,
        msg,
        nonce
    };

    // 6. Witness & Proof
    console.log('⚡ Generating witness...');
    await generateWitness(input, wasm, sizeDir);

    console.log('⚡ Generating proof...');
    const { proof, publicSignals } = await snarkjs.groth16.prove(zkey, wtnsFile);

    // 7. Verify
    const vkeyJson = JSON.parse(fs.readFileSync(vkey));
    const verified = await snarkjs.groth16.verify(vkeyJson, publicSignals, proof);

    if (verified) {
        console.log("\n-----------------------------------------");
        console.log("✅ Verification SUCCESSFUL");
        // Public signals for Main(n, k, m) are:
        // [0] msgAttestation, [1...m] addrs, [m+1] msg, [m+2] nonce
        console.log(`Message: ${publicSignals[m+1]}`);
        console.log(`Nonce:   ${publicSignals[m+2]}`);
        console.log("Proved membership in group:");
        for (let i = 0; i < m; i++) {
            console.log(`- ${BigNumber.from(publicSignals[i+1]).toHexString()}`);
        }
        console.log("-----------------------------------------");
    } else {
        console.log("❌ Invalid proof");
    }
    process.exit(0);
}

run();