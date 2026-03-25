#!/bin/bash
set -e # Exit on error

export MSYS_NO_PATHCONV=1
PHASE1=../../circuits/pot20_final.ptau
CIRCUIT_NAME=secure_variable_groupsig
BUILD_BASE=../../build/groupsig

# Check for Phase 1
if [ ! -f "$PHASE1" ]; then
    echo "Error: Phase 1 ptau file not found at $PHASE1"
    exit 1
fi

# Sizes we want to support
SIZES=(2 3 4)

for m in "${SIZES[@]}"
do
    echo "-------------------------------------------"
    echo "🔨 BUILDING FOR GROUP SIZE: m = $m"
    echo "-------------------------------------------"

    # Create a specific directory for this size
    TARGET_DIR="$BUILD_BASE/m_$m"
    mkdir -p "$TARGET_DIR"

    # 1. Modify the circom file temporarily to set the group size
    # This replaces the 'Main(64, 4, X)' line with the current size 'm'
    sed -i "s/component main {public \[addrs, msg, nonce\]} = Main(64, 4, [0-9]*);/component main {public [addrs, msg, nonce]} = Main(64, 4, $m);/" "$CIRCUIT_NAME".circom

    echo "**** COMPILING ****"
    circom "$CIRCUIT_NAME".circom --r1cs --wasm --output "$TARGET_DIR"

    echo "**** GENERATING ZKEY ****"
    # Groth16 Setup
    snarkjs groth16 setup "$TARGET_DIR/$CIRCUIT_NAME.r1cs" "$PHASE1" "$TARGET_DIR/temp_0.zkey"
    
    # Quick Contribution (using 'test' as entropy)
    echo "test" | snarkjs zkey contribute "$TARGET_DIR/temp_0.zkey" "$TARGET_DIR/temp_1.zkey" --name="Builder" -v -e="entropy"
    
    # Final Beacon and ZKey
    snarkjs zkey beacon "$TARGET_DIR/temp_1.zkey" "$TARGET_DIR/$CIRCUIT_NAME.zkey" 0102030405060708090a0b0c0d0e0f101112231415161718221a1b1c1d1e1f 10
    
    echo "**** EXPORTING VKEY ****"
    snarkjs zkey export verificationkey "$TARGET_DIR/$CIRCUIT_NAME.zkey" "$TARGET_DIR/vkey.json"

    # Cleanup intermediate files to save space
    rm "$TARGET_DIR/temp_0.zkey" "$TARGET_DIR/temp_1.zkey" "$TARGET_DIR/$CIRCUIT_NAME.r1cs"
    
    echo "✅ Done for m=$m"
done

echo "-------------------------------------------"
echo "All builds complete in $BUILD_BASE"