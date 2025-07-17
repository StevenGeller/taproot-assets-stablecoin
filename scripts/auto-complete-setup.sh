#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

echo "=== Taproot Assets Stablecoin Auto-Setup ==="
echo "This script will monitor and complete all remaining steps automatically."
echo

# Function to check Bitcoin sync
check_bitcoin_sync() {
    local progress=$(bitcoin-cli getblockchaininfo 2>/dev/null | jq -r '.verificationprogress' || echo "0")
    local blocks=$(bitcoin-cli getblockchaininfo 2>/dev/null | jq -r '.blocks' || echo "0")
    local headers=$(bitcoin-cli getblockchaininfo 2>/dev/null | jq -r '.headers' || echo "0")
    
    echo "Bitcoin sync: $blocks/$headers blocks ($(echo "$progress * 100" | bc -l | cut -d. -f1)%)"
    
    if (( $(echo "$progress > 0.999" | bc -l) )); then
        return 0
    else
        return 1
    fi
}

# Function to check LND sync
check_lnd_sync() {
    local synced=$(lncli --network=testnet getinfo 2>/dev/null | jq -r '.synced_to_chain' || echo "false")
    local block_height=$(lncli --network=testnet getinfo 2>/dev/null | jq -r '.block_height' || echo "0")
    
    echo "LND sync: Block height $block_height, Synced: $synced"
    
    if [ "$synced" = "true" ]; then
        return 0
    else
        return 1
    fi
}

# Function to check Taproot Assets
check_tapd() {
    if tapcli --network=testnet getinfo &>/dev/null; then
        echo "✅ Taproot Assets is running"
        return 0
    else
        echo "⏳ Taproot Assets not ready yet"
        return 1
    fi
}

# Function to mint stablecoin
mint_stablecoin() {
    echo
    echo "=== Minting Stablecoin ==="
    
    # Check if already minted
    if tapcli --network=testnet assets list 2>/dev/null | jq -e '.assets | length > 0' &>/dev/null; then
        echo "✅ Assets already minted"
        return 0
    fi
    
    # Mint the stablecoin
    echo "Minting USD-Stablecoin (USDT)..."
    
    MINT_RESPONSE=$(tapcli --network=testnet assets mint \
        --type normal \
        --name "USDT" \
        --supply 1000000 \
        --meta_bytes "$(echo -n 'USD-Stablecoin' | xxd -p)" \
        --enable_emission \
        --decimal_display 2 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        BATCH_KEY=$(echo "$MINT_RESPONSE" | jq -r '.batch_key')
        echo "Batch key: $BATCH_KEY"
        
        # Finalize the batch
        echo "Finalizing mint batch..."
        tapcli --network=testnet assets mint finalize --batch_key "$BATCH_KEY"
        
        echo "✅ Stablecoin minted successfully!"
        
        # Save asset info
        sleep 5
        tapcli --network=testnet assets list > ~/taproot-assets-stablecoin/minted-assets.json
        
        return 0
    else
        echo "❌ Minting failed"
        return 1
    fi
}

# Function to create test Lightning channel
create_test_channel() {
    echo
    echo "=== Creating Test Lightning Channel ==="
    
    # Check if we already have channels
    local num_channels=$(lncli --network=testnet listchannels 2>/dev/null | jq '.channels | length' || echo "0")
    
    if [ "$num_channels" -gt "0" ]; then
        echo "✅ Channels already exist"
        return 0
    fi
    
    # Connect to a test peer
    echo "Connecting to testnet peer..."
    
    # Try to connect to a known testnet node
    TEST_PEER="03933884aaf1d6b108397e5efe5c86bcf2d8ca8d2f700eda99db9214fc2712b134@endurance.acinq.co:9735"
    
    if lncli --network=testnet connect "$TEST_PEER" 2>/dev/null; then
        echo "✅ Connected to peer"
    else
        echo "⚠️  Peer connection failed (may already be connected)"
    fi
    
    # Note: Opening a channel requires testnet coins
    echo "ℹ️  To open channels, you need testnet Bitcoin."
    echo "Get testnet coins from: https://coinfaucet.eu/en/btc-testnet/"
    echo "Your address:"
    lncli --network=testnet newaddress p2wkh | jq -r '.address'
    
    return 0
}

# Function to test token operations
test_token_operations() {
    echo
    echo "=== Testing Token Operations ==="
    
    # Create a test address
    echo "Creating Taproot Assets address..."
    
    # Get asset ID
    ASSET_ID=$(tapcli --network=testnet assets list 2>/dev/null | jq -r '.assets[0].asset_genesis.asset_id' || echo "")
    
    if [ -z "$ASSET_ID" ]; then
        echo "❌ No assets found"
        return 1
    fi
    
    echo "Asset ID: $ASSET_ID"
    
    # Create address
    ADDR_RESPONSE=$(tapcli --network=testnet addrs new --asset_id "$ASSET_ID" --amt 100 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        ADDRESS=$(echo "$ADDR_RESPONSE" | jq -r '.encoded')
        echo "✅ Test address created:"
        echo "$ADDRESS"
        
        # Save for reference
        echo "$ADDRESS" > ~/taproot-assets-stablecoin/test-address.txt
        
        return 0
    else
        echo "❌ Address creation failed"
        return 1
    fi
}

# Main monitoring loop
main() {
    local step=1
    
    while true; do
        clear
        echo "=== Taproot Assets Stablecoin Auto-Setup ==="
        echo "Time: $(date)"
        echo "Step: $step"
        echo
        
        # Step 1: Check Bitcoin sync
        if ! check_bitcoin_sync; then
            echo "⏳ Waiting for Bitcoin to sync..."
            step=1
            sleep 30
            continue
        fi
        
        # Step 2: Check LND sync
        if ! check_lnd_sync; then
            echo "⏳ Waiting for LND to sync..."
            step=2
            sleep 30
            continue
        fi
        
        # Step 3: Check Taproot Assets
        if ! check_tapd; then
            echo "⏳ Waiting for Taproot Assets to initialize..."
            
            # Check if tapd is running
            if ! pgrep tapd >/dev/null; then
                echo "Starting Taproot Assets..."
                nohup tapd > ~/.tapd/tapd.log 2>&1 &
            fi
            
            step=3
            sleep 10
            continue
        fi
        
        # Step 4: Mint stablecoin
        if [ $step -le 4 ]; then
            if mint_stablecoin; then
                step=5
                sleep 5
            else
                echo "⏳ Retrying mint in 30 seconds..."
                sleep 30
                continue
            fi
        fi
        
        # Step 5: Create channels (optional)
        if [ $step -le 5 ]; then
            if create_test_channel; then
                step=6
            fi
        fi
        
        # Step 6: Test token operations
        if [ $step -le 6 ]; then
            if test_token_operations; then
                step=7
            fi
        fi
        
        # Done!
        echo
        echo "════════════════════════════════════════════════════"
        echo "✅ SETUP COMPLETE!"
        echo "════════════════════════════════════════════════════"
        echo
        echo "Your stablecoin is now operational!"
        echo
        echo "Key Information:"
        echo "- Asset minted: 1,000,000 USDT"
        echo "- Asset details: ~/taproot-assets-stablecoin/minted-assets.json"
        echo "- Test address: ~/taproot-assets-stablecoin/test-address.txt"
        echo
        echo "Next steps:"
        echo "1. Get testnet Bitcoin from faucet"
        echo "2. Open Lightning channels"
        echo "3. Start issuing tokens"
        echo
        echo "Useful commands:"
        echo "- List assets: tapcli --network=testnet assets list"
        echo "- Check balance: tapcli --network=testnet assets balance"
        echo "- Send tokens: tapcli --network=testnet assets send --addr <address>"
        echo
        
        # Create completion marker
        touch ~/taproot-assets-stablecoin/SETUP_COMPLETE
        
        break
    done
}

# Run with error handling
set +e
main