#!/bin/bash

set -e

CONFIG_FILE="../configs/stablecoin-config.json"

# Load configuration
ASSET_NAME=$(jq -r '.asset.name' "$CONFIG_FILE")
ASSET_TICKER=$(jq -r '.asset.ticker' "$CONFIG_FILE")
INITIAL_SUPPLY=$(jq -r '.minting.initial_supply' "$CONFIG_FILE")
DECIMAL_PLACES=$(jq -r '.minting.decimal_places' "$CONFIG_FILE")
BATCH_SIZE=$(jq -r '.minting.batch_size' "$CONFIG_FILE")

echo "=== Minting $ASSET_NAME ($ASSET_TICKER) Stablecoin ==="
echo

# Function to mint assets
mint_asset() {
    local amount=$1
    echo "Minting $amount $ASSET_TICKER tokens..."
    
    # Create the minting command
    MINT_RESPONSE=$(tapcli assets mint \
        --type normal \
        --name "$ASSET_TICKER" \
        --supply "$amount" \
        --meta_bytes "$(echo -n "$ASSET_NAME" | xxd -p)" \
        --enable_emission \
        --decimal_display "$DECIMAL_PLACES")
    
    echo "$MINT_RESPONSE"
    
    # Extract batch key
    BATCH_KEY=$(echo "$MINT_RESPONSE" | jq -r '.batch_key')
    echo "Batch key: $BATCH_KEY"
    
    # Finalize the batch
    echo "Finalizing batch..."
    tapcli assets mint finalize --batch_key "$BATCH_KEY"
    
    echo "✅ Minted $amount $ASSET_TICKER tokens"
}

# Function to list minted assets
list_assets() {
    echo
    echo "=== Current Assets ==="
    tapcli assets list --show_spent --show_leased
}

# Function to check balance
check_balance() {
    echo
    echo "=== Asset Balance ==="
    tapcli assets balance --asset_id "$1" || tapcli assets balance
}

# Function to export proof
export_proof() {
    local asset_id=$1
    local output_file="../backups/mint_proof_$(date +%Y%m%d_%H%M%S).proof"
    
    echo
    echo "Exporting proof to $output_file..."
    tapcli proofs export --asset_id "$asset_id" --proof_file "$output_file"
    echo "✅ Proof exported"
}

# Main minting process
main() {
    # Check if tapd is running
    if ! tapcli getinfo &> /dev/null; then
        echo "❌ Taproot Assets daemon is not running!"
        echo "Start it with: sudo systemctl start tapd"
        exit 1
    fi
    
    echo "Configuration:"
    echo "- Asset Name: $ASSET_NAME"
    echo "- Ticker: $ASSET_TICKER"
    echo "- Initial Supply: $INITIAL_SUPPLY"
    echo "- Decimal Places: $DECIMAL_PLACES"
    echo
    
    read -p "Proceed with minting? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Minting cancelled."
        exit 0
    fi
    
    # Mint in batches if supply is large
    if [ "$INITIAL_SUPPLY" -gt "$BATCH_SIZE" ]; then
        REMAINING=$INITIAL_SUPPLY
        while [ "$REMAINING" -gt 0 ]; do
            if [ "$REMAINING" -ge "$BATCH_SIZE" ]; then
                mint_asset "$BATCH_SIZE"
                REMAINING=$((REMAINING - BATCH_SIZE))
            else
                mint_asset "$REMAINING"
                REMAINING=0
            fi
            sleep 2
        done
    else
        mint_asset "$INITIAL_SUPPLY"
    fi
    
    # List assets and get asset ID
    echo
    echo "Waiting for asset to be confirmed..."
    sleep 5
    
    ASSETS=$(tapcli assets list)
    echo "$ASSETS"
    
    # Extract asset ID for our stablecoin
    ASSET_ID=$(echo "$ASSETS" | jq -r ".assets[] | select(.asset_genesis.name == \"$ASSET_TICKER\") | .asset_genesis.asset_id" | head -1)
    
    if [ -n "$ASSET_ID" ]; then
        echo
        echo "✅ Asset ID: $ASSET_ID"
        
        # Save asset ID
        echo "$ASSET_ID" > ../configs/asset_id.txt
        
        # Export proof
        export_proof "$ASSET_ID"
        
        # Check balance
        check_balance "$ASSET_ID"
    else
        echo "⚠️  Could not retrieve asset ID. Check with: tapcli assets list"
    fi
    
    echo
    echo "=== Minting Complete ==="
    echo
    echo "Next steps:"
    echo "1. Sync with universe: tapcli universe sync --universe_host testnet.universe.lightning.finance"
    echo "2. Create Lightning channels: ~/taproot-assets-stablecoin/scripts/create-channels.sh"
    echo "3. Start issuing tokens: ~/taproot-assets-stablecoin/scripts/issue-tokens.sh"
}

# Run main function
main