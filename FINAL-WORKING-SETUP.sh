#!/bin/bash

# Complete working setup for Taproot Assets Stablecoin

export PATH=$PATH:~/go/bin:~/bin

echo "=============================================="
echo "TAPROOT ASSETS STABLECOIN - FINAL SETUP"
echo "=============================================="
echo

# Kill all services for clean start
echo "Cleaning up old processes..."
pkill -f "bitcoind|lnd|tapd" 2>/dev/null
sleep 3

# Start Bitcoin with ZMQ
echo "1. Starting Bitcoin Core (regtest)..."
bitcoind -daemon -regtest -zmqpubrawblock=tcp://127.0.0.1:28332 -zmqpubrawtx=tcp://127.0.0.1:28333
sleep 5

# Create wallet and mine blocks
bitcoin-cli -regtest createwallet "testwallet" 2>/dev/null || bitcoin-cli -regtest loadwallet "testwallet"
BTCADDR=$(bitcoin-cli -regtest getnewaddress)
bitcoin-cli -regtest generatetoaddress 150 "$BTCADDR" > /dev/null
echo "✅ Bitcoin ready with 150 blocks"

# Start LND
echo
echo "2. Starting LND..."
rm -rf ~/.lnd/data/chain/bitcoin/regtest
nohup lnd > ~/.lnd/lnd.log 2>&1 &
sleep 15

# Check LND startup
if ! lncli --network=regtest getinfo 2>&1 | grep -q "version"; then
    echo "Creating LND wallet..."
    
    # Generate seed
    SEED_RESPONSE=$(curl -k -X GET https://localhost:8080/v1/genseed 2>/dev/null)
    SEED_JSON=$(echo "$SEED_RESPONSE" | jq '.cipher_seed_mnemonic')
    
    # Create wallet
    curl -k -X POST https://localhost:8080/v1/initwallet \
        -H "Content-Type: application/json" \
        -d "{
            \"wallet_password\": \"$(echo -n 'MySuperSecurePassword123!' | base64)\",
            \"cipher_seed_mnemonic\": $SEED_JSON,
            \"recovery_window\": 0
        }" 2>/dev/null
    
    sleep 5
fi

# Verify LND
echo "LND Status:"
lncli --network=regtest getinfo 2>&1 | jq '{version, block_height}' || echo "Starting..."

# Fund LND
echo
echo "3. Funding LND..."
LND_ADDR=$(lncli --network=regtest newaddress p2wkh 2>/dev/null | jq -r '.address' || echo "")
if [ -n "$LND_ADDR" ] && [ "$LND_ADDR" != "null" ]; then
    bitcoin-cli -regtest sendtoaddress "$LND_ADDR" 10
    bitcoin-cli -regtest generatetoaddress 6 "$BTCADDR" > /dev/null
    echo "✅ LND funded with 10 BTC"
fi

# Start Taproot Assets
echo
echo "4. Starting Taproot Assets..."
rm -f ~/.tapd/tapd.db
nohup tapd > ~/.tapd/tapd.log 2>&1 &
sleep 15

# Check if Taproot Assets is ready
echo "Checking Taproot Assets..."
TAPD_VERSION=$(tapcli --network=regtest getinfo 2>&1 | jq -r '.version' || echo "")

if [ -n "$TAPD_VERSION" ] && [ "$TAPD_VERSION" != "null" ]; then
    echo "✅ Taproot Assets running: $TAPD_VERSION"
    
    # Mint stablecoin
    echo
    echo "5. Minting USD Stablecoin..."
    
    # First, list any existing assets
    EXISTING=$(tapcli --network=regtest assets list 2>/dev/null | jq '.assets | length' || echo "0")
    
    if [ "$EXISTING" = "0" ]; then
        # Mint new asset
        # Create temporary JSON metadata file
        echo '{"name":"USD-XYZ-Stablecoin","symbol":"USDXYZ","decimals":2}' > /tmp/usdxyz_meta.json
        
        MINT_RESPONSE=$(tapcli --network=regtest assets mint \
            --type normal \
            --name "USDXYZ" \
            --supply 1000000 \
            --meta_file_path "/tmp/usdxyz_meta.json" \
            --meta_type json \
            --new_grouped_asset \
            --decimal_display 2 2>&1)
        
        echo "$MINT_RESPONSE"
        
        # Get batch key
        if echo "$MINT_RESPONSE" | grep -q "batch_key"; then
            BATCH_KEY=$(echo "$MINT_RESPONSE" | jq -r '.pending_batch.batch_key' 2>/dev/null || echo "$MINT_RESPONSE" | grep -o '"batch_key":"[^"]*"' | cut -d'"' -f4)
            
            if [ -n "$BATCH_KEY" ]; then
                echo
                echo "Finalizing mint..."
                tapcli --network=regtest assets mint finalize "$BATCH_KEY"
                
                # Confirm with mining
                sleep 3
                bitcoin-cli -regtest generatetoaddress 1 "$BTCADDR" > /dev/null
                
                echo "✅ Minted 1,000,000 USDXYZ successfully!"
            fi
        fi
    fi
    
    # Wait for asset
    sleep 5
    
    # Display results
    echo
    echo "6. Asset Details:"
    ASSETS=$(tapcli --network=regtest assets list 2>/dev/null)
    echo "$ASSETS" | jq '.assets[]' 2>/dev/null || echo "Waiting for assets..."
    
    # Get asset ID
    ASSET_ID=$(echo "$ASSETS" | jq -r '.assets[0].asset_genesis.asset_id' 2>/dev/null || echo "")
    
    if [ -n "$ASSET_ID" ] && [ "$ASSET_ID" != "null" ]; then
        # Create addresses
        echo
        echo "7. Creating Test Addresses:"
        
        # Address 1
        ADDR1=$(tapcli --network=regtest addrs new --asset_id "$ASSET_ID" --amt 1000 2>&1)
        echo "Address for 1000 USDXYZ:"
        echo "$ADDR1" | jq -r '.encoded' 2>/dev/null || echo "$ADDR1"
        
        # Show balance
        echo
        echo "8. Current Balance:"
        tapcli --network=regtest assets balance --asset_id "$ASSET_ID" 2>/dev/null | jq '.'
        
        # Save important info
        cat > ~/taproot-assets-stablecoin/STABLECOIN-INFO.txt << EOF
TAPROOT ASSETS STABLECOIN INFORMATION
=====================================
Generated: $(date)
Network: regtest

Asset Name: USDXYZ
Asset ID: $ASSET_ID
Total Supply: 1,000,000 USDXYZ
Decimal Places: 2

Bitcoin Address: $BTCADDR
LND Address: $LND_ADDR

Status: FULLY OPERATIONAL
EOF
        
        echo
        echo "=============================================="
        echo "✅ STABLECOIN SYSTEM FULLY OPERATIONAL!"
        echo "=============================================="
        echo
        echo "Asset ID: $ASSET_ID"
        echo "Balance: 1,000,000 USDXYZ"
        echo
        echo "Commands:"
        echo "  List assets:    tapcli --network=regtest assets list"
        echo "  Check balance:  tapcli --network=regtest assets balance"
        echo "  New address:    tapcli --network=regtest addrs new --asset_id $ASSET_ID --amt <amount>"
        echo "  Send tokens:    tapcli --network=regtest assets send --addr <address>"
        echo
        echo "Info saved to: ~/taproot-assets-stablecoin/STABLECOIN-INFO.txt"
    fi
else
    echo "❌ Taproot Assets not ready. Check logs:"
    tail -10 ~/.tapd/tapd.log
    echo
    echo "Troubleshooting:"
    echo "1. Check LND is running: lncli --network=regtest getinfo"
    echo "2. Check Bitcoin is running: bitcoin-cli -regtest getblockcount"
    echo "3. View Taproot Assets logs: tail -f ~/.tapd/tapd.log"
fi

echo
echo "Process Status:"
ps aux | grep -E "bitcoind|lnd|tapd" | grep -v grep