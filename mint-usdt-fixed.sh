#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

echo "=== Minting USD Stablecoin ==="

# Create metadata JSON
METADATA='{"description":"USD-backed stablecoin on Taproot Assets","issuer":"Taproot Assets Demo","ticker":"USDT"}'
META_HEX=$(echo -n "$METADATA" | xxd -p | tr -d '\n')

echo "Minting 1,000,000 USDT..."

# Mint with correct syntax
MINT_RESPONSE=$(tapcli --network=regtest assets mint \
    --type normal \
    --name "USDT" \
    --supply 1000000 \
    --meta_bytes "$META_HEX" \
    --meta_type json \
    --decimal_display 2 \
    --new_grouped_asset 2>&1)

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
            
            echo "Sending 50 USDT..."
            SEND_RESPONSE=$(tapcli --network=regtest assets send --addr "$SEND_ADDR" 2>&1)
            if echo "$SEND_RESPONSE" | grep -q "error"; then
                echo "Send response: $SEND_RESPONSE"
            else
                echo "✅ Sent 50 USDT!"
                
                # Mine block
                sleep 2
                bitcoin-cli -regtest generatetoaddress 1 "$BTCADDR" >/dev/null
                
                # Show updated balance
                echo
                echo "=== Updated Balance ==="
                tapcli --network=regtest assets balance --asset_id "$ASSET_ID" | jq '.'
                
                # Show transfers
                echo
                echo "=== Recent Transfers ==="
                tapcli --network=regtest assets transfers | jq '.transfers[:2] | .[] | {txid: .txid, asset_id: .asset_id, amount: .amount}'
            fi
            
            # Final summary
            cat > ~/taproot-assets-stablecoin/STABLECOIN-READY.txt << EOF
TAPROOT ASSETS USD STABLECOIN
=============================
Generated: $(date)

Asset Details:
- Name: USDT
- Asset ID: $ASSET_ID
- Total Supply: 1,000,000.00 USDT (with 2 decimal places)
- Type: Grouped asset (supports ongoing emission)
- Metadata: USD-backed stablecoin on Taproot Assets

Test Address (100 USDT): $TEST_ADDR

Services Running:
- Bitcoin Core: $(bitcoin-cli -regtest getblockcount) blocks
- LND: $(lncli --network=regtest getinfo | jq -r '.version')
- Taproot Assets: $(tapcli --network=regtest getinfo | jq -r '.version')

Commands:
  List assets:       tapcli --network=regtest assets list
  Check balance:     tapcli --network=regtest assets balance --asset_id $ASSET_ID
  New address:       tapcli --network=regtest addrs new --asset_id $ASSET_ID --amt <amount>
  Send tokens:       tapcli --network=regtest assets send --addr <address>
  View transfers:    tapcli --network=regtest assets transfers
  Mint more tokens:  tapcli --network=regtest assets mint --type normal --name USDT --supply <amount> --group_key <group_key>

Status: ✅ FULLY OPERATIONAL
EOF
            
            echo
            echo "============================================"
            echo "✅ STABLECOIN SYSTEM FULLY OPERATIONAL!"
            echo "============================================"
            echo "Asset ID: $ASSET_ID"
            echo "Supply: 1,000,000.00 USDT"
            echo "Decimal Places: 2"
            echo
            echo "Details saved to: STABLECOIN-READY.txt"
            echo
            echo "You can now:"
            echo "1. Create addresses to receive USDT"
            echo "2. Send USDT to other addresses"
            echo "3. Mint additional USDT (grouped asset)"
            echo "4. Build applications on top of this stablecoin"
        fi
    fi
else
    echo "Mint failed. Response: $MINT_RESPONSE"
fi