#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

echo "==============================================" 
echo "CONTINUING STABLECOIN SETUP"
echo "=============================================="
echo

# Wait for LND macaroons to be ready
echo "1. Waiting for LND to fully initialize..."
sleep 10

# Check if we can access LND now
echo "2. Checking LND status..."
if lncli --network=regtest getinfo >/dev/null 2>&1; then
    echo "✅ LND is ready!"
    lncli --network=regtest getinfo | jq '{version, block_height, synced_to_chain}'
else
    # Try with explicit macaroon path
    if lncli --network=regtest --macaroonpath=/home/steven/.lnd/data/chain/bitcoin/regtest/admin.macaroon --tlscertpath=/home/steven/.lnd/tls.cert getinfo >/dev/null 2>&1; then
        echo "✅ LND is ready (with explicit macaroon)!"
    else
        echo "⚠️ LND may still be initializing. Continuing..."
    fi
fi

# Get Bitcoin address
BTCADDR=$(bitcoin-cli -regtest getnewaddress)

# Fund LND if needed
echo
echo "3. Checking LND wallet balance..."
BALANCE=$(lncli --network=regtest walletbalance 2>/dev/null | jq -r '.confirmed_balance' || echo "0")
if [ "$BALANCE" = "0" ]; then
    echo "Funding LND wallet..."
    LND_ADDR=$(lncli --network=regtest newaddress p2wkh 2>/dev/null | jq -r '.address' || echo "")
    if [ -n "$LND_ADDR" ] && [ "$LND_ADDR" != "null" ]; then
        bitcoin-cli -regtest sendtoaddress "$LND_ADDR" 10 >/dev/null
        bitcoin-cli -regtest generatetoaddress 6 "$BTCADDR" >/dev/null
        echo "✅ Sent 10 BTC to LND: $LND_ADDR"
    fi
else
    echo "✅ LND wallet already has balance: $BALANCE satoshis"
fi

# Start Taproot Assets
echo
echo "4. Starting Taproot Assets..."
pkill tapd 2>/dev/null
sleep 2

# Remove old database
rm -f ~/.tapd/tapd.db

# Start tapd
tapd > ~/.tapd/tapd-startup.log 2>&1 &

echo "Waiting for Taproot Assets to start..."
sleep 20

# Check Taproot Assets
echo
echo "5. Checking Taproot Assets..."
if tapcli --network=regtest getinfo >/dev/null 2>&1; then
    echo "✅ Taproot Assets is running!"
    tapcli --network=regtest getinfo | jq '{version, lnd_version}'
    
    # Mint stablecoin
    echo
    echo "6. Minting USD Stablecoin..."
    
    # Check existing assets
    EXISTING=$(tapcli --network=regtest assets list 2>/dev/null | jq '.assets | length' || echo "0")
    
    if [ "$EXISTING" = "0" ]; then
        echo "Creating new USDT asset..."
        
        # Mint with simpler command
        MINT_RESPONSE=$(tapcli --network=regtest assets mint \
            --type normal \
            --name "USDT" \
            --supply 1000000 \
            --decimal_display 2 2>&1)
        
        echo "$MINT_RESPONSE"
        
        # Check for batch key
        if echo "$MINT_RESPONSE" | grep -q "batch_key"; then
            # Extract batch key more reliably
            BATCH_KEY=$(echo "$MINT_RESPONSE" | sed -n 's/.*"batch_key":"\([^"]*\)".*/\1/p')
            
            if [ -n "$BATCH_KEY" ]; then
                echo
                echo "Finalizing mint with batch key: $BATCH_KEY"
                FINALIZE_RESPONSE=$(tapcli --network=regtest assets mint finalize --batch_key "$BATCH_KEY" 2>&1)
                echo "$FINALIZE_RESPONSE"
                
                # Mine block
                sleep 2
                bitcoin-cli -regtest generatetoaddress 1 "$BTCADDR" >/dev/null
                echo "✅ Minted 1,000,000 USDT!"
            fi
        fi
    fi
    
    # Wait and list assets
    sleep 5
    echo
    echo "7. Listing Assets..."
    ASSETS=$(tapcli --network=regtest assets list 2>/dev/null)
    if [ -n "$ASSETS" ]; then
        echo "$ASSETS" | jq '.assets[] | {name: .asset_genesis.name, asset_id: .asset_genesis.asset_id, amount: .amount}'
        
        # Get asset ID
        ASSET_ID=$(echo "$ASSETS" | jq -r '.assets[0].asset_genesis.asset_id' 2>/dev/null)
        
        if [ -n "$ASSET_ID" ] && [ "$ASSET_ID" != "null" ]; then
            echo
            echo "8. Creating Test Address..."
            ADDR_RESPONSE=$(tapcli --network=regtest addrs new --asset_id "$ASSET_ID" --amt 100 2>&1)
            if echo "$ADDR_RESPONSE" | grep -q "encoded"; then
                echo "Address for 100 USDT:"
                echo "$ADDR_RESPONSE" | jq -r '.encoded'
            fi
            
            echo
            echo "9. Asset Balance..."
            tapcli --network=regtest assets balance --asset_id "$ASSET_ID" 2>/dev/null | jq '.'
            
            echo
            echo "=============================================="
            echo "✅ STABLECOIN SYSTEM OPERATIONAL!"
            echo "=============================================="
            echo
            echo "Asset ID: $ASSET_ID"
            echo "Total Supply: 1,000,000 USDT"
            echo
            echo "Next steps:"
            echo "1. Create addresses: tapcli --network=regtest addrs new --asset_id $ASSET_ID --amt <amount>"
            echo "2. Send tokens: tapcli --network=regtest assets send --addr <tap_address>"
            echo "3. Check balance: tapcli --network=regtest assets balance"
        fi
    else
        echo "No assets found yet. The minting may still be processing."
    fi
else
    echo "❌ Taproot Assets not ready. Checking logs..."
    echo
    echo "=== Recent Taproot Assets Log ==="
    tail -20 ~/.tapd/tapd.log
    echo
    echo "=== Startup Log ==="
    tail -20 ~/.tapd/tapd-startup.log
fi

echo
echo "=== Current Services ==="
ps aux | grep -E "bitcoind|lnd|tapd" | grep -v grep | awk '{print $11, $12, $13}'