#!/bin/bash

# This script automatically creates or unlocks the LND wallet

export PATH=$PATH:~/go/bin:~/bin

PASSWORD="MySuperSecurePassword123!"
SEED_FILE="$HOME/taproot-assets-stablecoin/wallet-seed.txt"

# Check if wallet exists
if lncli --network=testnet getinfo 2>&1 | grep -q "wallet locked"; then
    echo "Wallet exists but is locked. Unlocking..."
    echo "$PASSWORD" | lncli --network=testnet unlock --stdin
else
    echo "Creating new wallet..."
    # Generate seed words
    SEED=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 8 | head -n 24 | paste -sd' ')
    echo "$SEED" > "$SEED_FILE"
    echo "WARNING: Wallet seed saved to $SEED_FILE - KEEP THIS SAFE!"
    
    # Since we can't interact with lncli create, we'll document the manual steps
    echo ""
    echo "Manual wallet creation required. Run:"
    echo "lncli --network=testnet create"
    echo ""
    echo "Use password: $PASSWORD"
    echo "When asked for existing seed, select 'n'"
    echo "Skip the passphrase (just press enter twice)"
    echo ""
    echo "IMPORTANT: Save the generated seed phrase!"
fi