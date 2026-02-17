#!/bin/bash
set -e

export MSYS_NO_PATHCONV=1


# --------------------------------
# Config
# --------------------------------

PHASE1=../../circuits/pot20_final.ptau
CIRCUIT_NAME=private_secure_variable_groupsig
BUILD_BASE=../../build/groupsig
VERIFIER_DIR="$BUILD_BASE/verifiers"


# --------------------------------
# Check Phase1
# --------------------------------

if [ ! -f "$PHASE1" ]; then
    echo "❌ Phase1 ptau not found: $PHASE1"
    exit 1
fi


# --------------------------------
# User Input
# --------------------------------

read -p "Enter maximum group size (>=2): " MAX_M

if ! [[ "$MAX_M" =~ ^[0-9]+$ ]] || [ "$MAX_M" -lt 2 ]; then
    echo "❌ Invalid group size"
    exit 1
fi


read -p "Create Solidity verifiers? (y/n): " MAKE_VERIFIERS


if [[ "$MAKE_VERIFIERS" == "y" || "$MAKE_VERIFIERS" == "Y" ]]; then
    MAKE_VERIFIERS=true
    mkdir -p "$VERIFIER_DIR"
else
    MAKE_VERIFIERS=false
fi


echo
echo "==================================="
echo " Max group size: $MAX_M"
echo " Generate verifiers: $MAKE_VERIFIERS"
echo "==================================="
echo


# --------------------------------
# Build Loop
# --------------------------------

for (( m=2; m<=MAX_M; m++ ))
do

    echo "-------------------------------------------"
    echo "🔨 BUILDING FOR GROUP SIZE: m = $m"
    echo "-------------------------------------------"


    TARGET_DIR="$BUILD_BASE/p_m_$m"

    mkdir -p "$TARGET_DIR"


    # --------------------------------
    # Patch circuit
    # --------------------------------

    echo "⚙️  Setting group size..."

    sed -i \
      "s/component main {public \[addrs, pubHashHi, pubHashLo, nonce\]} = Main(64, 4, [0-9]*);/component main {public [addrs, pubHashHi, pubHashLo, nonce]} = Main(64, 4, $m);/" \
      "$CIRCUIT_NAME.circom"


    # --------------------------------
    # Compile
    # --------------------------------

    echo "⚙️  Compiling..."

    circom "$CIRCUIT_NAME.circom" \
        --r1cs \
        --wasm \
        --sym \
        --output "$TARGET_DIR"


    # --------------------------------
    # Groth16 Setup
    # --------------------------------

    echo "⚙️  Groth16 setup..."

    snarkjs groth16 setup \
        "$TARGET_DIR/$CIRCUIT_NAME.r1cs" \
        "$PHASE1" \
        "$TARGET_DIR/temp_0.zkey"


    echo "test" | snarkjs zkey contribute \
        "$TARGET_DIR/temp_0.zkey" \
        "$TARGET_DIR/temp_1.zkey" \
        --name="Builder" \
        -v \
        -e="entropy"


    snarkjs zkey beacon \
        "$TARGET_DIR/temp_1.zkey" \
        "$TARGET_DIR/$CIRCUIT_NAME.zkey" \
        0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f \
        10


    # --------------------------------
    # Export vkey
    # --------------------------------

    echo "⚙️  Exporting verification key..."

    snarkjs zkey export verificationkey \
        "$TARGET_DIR/$CIRCUIT_NAME.zkey" \
        "$TARGET_DIR/vkey.json"


    # --------------------------------
    # Export Solidity Verifier
    # --------------------------------
    if [ "$MAKE_VERIFIERS" = true ]; then

        echo "⚙️  Exporting Solidity verifier..."

        # 1. Export with default name (usually 'Groth16Verifier')
        snarkjs zkey export solidityverifier \
            "$TARGET_DIR/$CIRCUIT_NAME.zkey" \
            "$VERIFIER_DIR/VerifierM$m.sol"

        # 2. Use sed to rename the contract inside the file
        # This replaces 'contract Groth16Verifier' with 'contract VerifierMm'
        sed -i "s/contract Groth16Verifier/contract VerifierM$m/g" "$VERIFIER_DIR/VerifierM$m.sol"

        echo "   → $VERIFIER_DIR/VerifierM$m.sol (renamed to VerifierM$m)"
    fi


    # --------------------------------
    # Cleanup
    # --------------------------------

    rm "$TARGET_DIR/temp_0.zkey"
    rm "$TARGET_DIR/temp_1.zkey"
    rm "$TARGET_DIR/$CIRCUIT_NAME.r1cs"


    echo "✅ Done for m=$m"
    echo

done


echo "==================================="
echo " All builds complete"
echo " Output: $BUILD_BASE"
echo "==================================="

if [ "$MAKE_VERIFIERS" = true ]; then
    echo " Verifiers: $VERIFIER_DIR"
fi

echo
