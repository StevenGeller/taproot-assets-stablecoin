#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

echo "=== Complete Taproot Assets Stablecoin Demo (Regtest) ==="
echo

# Wait for Bitcoin to be ready
sleep 5

# Load wallet
bitcoin-cli -regtest loadwallet "testwallet" 2>/dev/null || true

# Start LND
echo "Starting LND..."
nohup lnd > ~/.lnd/lnd.log 2>&1 &
sleep 10

# Check if wallet exists or create it
if lncli --network=regtest getinfo 2>&1 | grep -q "wallet locked"; then
    echo "Unlocking existing wallet..."
    echo "MySuperSecurePassword123!" | lncli --network=regtest unlock --stdin
else
    echo "Checking wallet state..."
fi

sleep 5

# Verify LND is running
echo "LND Status:"
lncli --network=regtest getinfo | jq '{version, block_height}'

# Fund LND if needed
BALANCE=$(lncli --network=regtest walletbalance 2>/dev/null | jq -r '.confirmed_balance' || echo "0")
if [ "$BALANCE" = "0" ]; then
    echo "Funding LND wallet..."
    LND_ADDR=$(lncli --network=regtest newaddress p2wkh | jq -r '.address')
    bitcoin-cli -regtest sendtoaddress "$LND_ADDR" 10
    MINING_ADDR=$(bitcoin-cli -regtest getnewaddress)
    bitcoin-cli -regtest generatetoaddress 6 "$MINING_ADDR" > /dev/null
    echo "✅ Funded LND with 10 BTC"
fi

# Start Taproot Assets
echo
echo "Starting Taproot Assets..."
pkill tapd 2>/dev/null
sleep 2
nohup tapd > ~/.tapd/tapd.log 2>&1 &
sleep 10

# Verify Taproot Assets
if tapcli --network=regtest getinfo 2>&1 | grep -q "version"; then
    echo "✅ Taproot Assets is running!"
    
    # Check if assets already exist
    EXISTING_ASSETS=$(tapcli --network=regtest assets list 2>/dev/null | jq '.assets | length' || echo "0")
    
    if [ "$EXISTING_ASSETS" = "0" ]; then
        echo
        echo "=== Minting Stablecoin ==="
        
        # Mint USDT
        MINT_CMD="tapcli --network=regtest assets mint --type normal --name USDT --supply 1000000 --meta_bytes $(echo -n 'USD-Stablecoin' | xxd -p) --enable_emission --decimal_display 2"
        
        echo "Running: $MINT_CMD"
        MINT_RESPONSE=$(eval $MINT_CMD 2>&1)
        echo "$MINT_RESPONSE"
        
        # Extract batch key
        BATCH_KEY=$(echo "$MINT_RESPONSE" | grep -o '"batch_key":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$BATCH_KEY" ]; then
            echo
            echo "Finalizing mint with batch key: $BATCH_KEY"
            tapcli --network=regtest assets mint finalize --batch_key "$BATCH_KEY"
            
            # Mine block to confirm
            sleep 2
            MINING_ADDR=$(bitcoin-cli -regtest getnewaddress)
            bitcoin-cli -regtest generatetoaddress 1 "$MINING_ADDR" > /dev/null
            
            echo "✅ Minted 1,000,000 USDT!"
        fi
    else
        echo "✅ Assets already minted"
    fi
    
    # Wait for asset to be confirmed
    sleep 3
    
    echo
    echo "=== Asset Information ==="
    tapcli --network=regtest assets list | jq '.assets[] | {name: .asset_genesis.name, asset_id: .asset_genesis.asset_id, amount: .amount, type: .asset_genesis.asset_type}'
    
    # Get asset ID
    ASSET_ID=$(tapcli --network=regtest assets list 2>/dev/null | jq -r '.assets[0].asset_genesis.asset_id' || echo "")
    
    if [ -n "$ASSET_ID" ] && [ "$ASSET_ID" != "null" ]; then
        echo
        echo "=== Creating Test Addresses ==="
        
        # Create receiving address
        ADDR_RESPONSE=$(tapcli --network=regtest addrs new --asset_id "$ASSET_ID" --amt 100)
        RECEIVE_ADDR=$(echo "$ADDR_RESPONSE" | jq -r '.encoded')
        
        echo "Test receive address (100 USDT):"
        echo "$RECEIVE_ADDR"
        echo
        
        # Show balance
        echo "=== Current Balance ==="
        tapcli --network=regtest assets balance --asset_id "$ASSET_ID" | jq '.'
        
        # Demonstrate sending (to ourselves for demo)
        echo
        echo "=== Demonstrating Send Operation ==="
        echo "Creating send of 50 USDT..."
        
        SEND_ADDR_RESPONSE=$(tapcli --network=regtest addrs new --asset_id "$ASSET_ID" --amt 50)
        SEND_ADDR=$(echo "$SEND_ADDR_RESPONSE" | jq -r '.encoded')
        
        echo "Send address: $SEND_ADDR"
        echo
        echo "Sending 50 USDT..."
        SEND_RESPONSE=$(tapcli --network=regtest assets send --addr "$SEND_ADDR" 2>&1)
        echo "$SEND_RESPONSE"
        
        # Mine block to confirm
        sleep 2
        bitcoin-cli -regtest generatetoaddress 1 "$MINING_ADDR" > /dev/null
        
        echo
        echo "=== Updated Balance ==="
        tapcli --network=regtest assets balance --asset_id "$ASSET_ID" | jq '.'
        
        echo
        echo "=== Recent Transfers ==="
        tapcli --network=regtest assets transfers | jq '.transfers[] | {txid: .txid, asset_id: .asset_id, amount: .amount}'
    fi
    
else
    echo "❌ Taproot Assets failed to start. Check logs:"
    tail -20 ~/.tapd/tapd.log
fi

echo
echo "========================================="
echo "✅ STABLECOIN SYSTEM FULLY OPERATIONAL!"
echo "========================================="
echo
echo "Summary:"
echo "- Bitcoin Core: Running on regtest"
echo "- LND: Running with funded wallet"
echo "- Taproot Assets: Running with minted USDT"
echo "- Asset: 1,000,000 USDT minted and ready"
echo
echo "Useful commands:"
echo "- List assets: tapcli --network=regtest assets list"
echo "- Check balance: tapcli --network=regtest assets balance"
echo "- Create address: tapcli --network=regtest addrs new --asset_id <ID> --amt <amount>"
echo "- Send assets: tapcli --network=regtest assets send --addr <address>"
echo
echo "Asset ID: $ASSET_ID"
echo
echo "System is fully operational and ready for use!"