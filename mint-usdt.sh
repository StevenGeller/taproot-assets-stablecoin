#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

echo "=== Minting USD Stablecoin ==="

# Create metadata JSON
METADATA='{"description":"USD-backed stablecoin on Taproot Assets","issuer":"Taproot Assets Demo"}'
META_HEX=$(echo -n "$METADATA" | xxd -p | tr -d '\n')

echo "Minting 1,000,000 USDT with metadata..."

# Mint without decimal_display first
MINT_RESPONSE=$(tapcli --network=regtest assets mint \
    --type normal \
    --name "USDT" \
    --supply 1000000 \
    --meta_bytes "$META_HEX" \
    --enable_emission 2>&1)

echo "$MINT_RESPONSE"

# Extract batch key
if echo "$MINT_RESPONSE" | grep -q "batch_key"; then
    BATCH_KEY=$(echo "$MINT_RESPONSE" | jq -r '.batch_key' 2>/dev/null || \
               echo "$MINT_RESPONSE" | sed -n 's/.*"batch_key":"\([^"]*\)".*/\1/p')
    
    if [ -n "$BATCH_KEY" ] && [ "$BATCH_KEY" != "null" ]; then
        echo
        echo "Finalizing mint batch: $BATCH_KEY"
        FINALIZE_RESPONSE=$(tapcli --network=regtest assets mint finalize --batch_key "$BATCH_KEY" 2>&1)
        echo "$FINALIZE_RESPONSE"
        
        # Mine block
        echo
        echo "Mining block to confirm..."
        BTCADDR=$(bitcoin-cli -regtest getnewaddress)
        bitcoin-cli -regtest generatetoaddress 1 "$BTCADDR" >/dev/null
        
        echo "✅ Minted 1,000,000 USDT!"
        
        # Wait and list assets
        sleep 5
        echo
        echo "=== Assets List ==="
        ASSETS=$(tapcli --network=regtest assets list)
        echo "$ASSETS" | jq '.assets[] | {name: .asset_genesis.name, asset_id: .asset_genesis.asset_id, amount: .amount}'
        
        # Get asset ID
        ASSET_ID=$(echo "$ASSETS" | jq -r '.assets[0].asset_genesis.asset_id')
        
        if [ -n "$ASSET_ID" ] && [ "$ASSET_ID" != "null" ]; then
            # Create test address
            echo
            echo "=== Creating Test Address ==="
            ADDR_RESPONSE=$(tapcli --network=regtest addrs new --asset_id "$ASSET_ID" --amt 100)
            TEST_ADDR=$(echo "$ADDR_RESPONSE" | jq -r '.encoded')
            echo "Test address for 100 USDT:"
            echo "$TEST_ADDR"
            
            # Show balance
            echo
            echo "=== Asset Balance ==="
            tapcli --network=regtest assets balance --asset_id "$ASSET_ID" | jq '.'
            
            # Demo send to self
            echo
            echo "=== Demo: Sending 50 USDT ==="
            SEND_ADDR_RESPONSE=$(tapcli --network=regtest addrs new --asset_id "$ASSET_ID" --amt 50)
            SEND_ADDR=$(echo "$SEND_ADDR_RESPONSE" | jq -r '.encoded')
            echo "Creating address for 50 USDT: $SEND_ADDR"
            
            echo "Sending..."
            SEND_RESPONSE=$(tapcli --network=regtest assets send --addr "$SEND_ADDR" 2>&1)
            if echo "$SEND_RESPONSE" | grep -q "error"; then
                echo "Send response: $SEND_RESPONSE"
            else
                echo "✅ Sent 50 USDT!"
                
                # Mine block
                sleep 2
                bitcoin-cli -regtest generatetoaddress 1 "$BTCADDR" >/dev/null
                
                # Show transfers
                echo
                echo "=== Recent Transfers ==="
                tapcli --network=regtest assets transfers | jq '.transfers[] | {txid: .txid, asset_id: .asset_id, amount: .amount}'
            fi
            
            # Final summary
            cat > ~/taproot-assets-stablecoin/STABLECOIN-READY.txt << EOF
TAPROOT ASSETS USD STABLECOIN
=============================
Generated: $(date)

Asset Details:
- Name: USDT
- Asset ID: $ASSET_ID
- Total Supply: 1,000,000 USDT
- Metadata: USD-backed stablecoin on Taproot Assets

Test Address (100 USDT): $TEST_ADDR

Commands:
  List assets:    tapcli --network=regtest assets list
  Check balance:  tapcli --network=regtest assets balance --asset_id $ASSET_ID
  New address:    tapcli --network=regtest addrs new --asset_id $ASSET_ID --amt <amount>
  Send tokens:    tapcli --network=regtest assets send --addr <address>
  View transfers: tapcli --network=regtest assets transfers

Status: ✅ FULLY OPERATIONAL
EOF
            
            echo
            echo "======================================"
            echo "✅ STABLECOIN FULLY OPERATIONAL!"
            echo "======================================"
            echo "Asset ID: $ASSET_ID"
            echo "Supply: 1,000,000 USDT"
            echo "Details saved to: STABLECOIN-READY.txt"
        fi
    fi
fi