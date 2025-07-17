#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

echo "=== Complete Regtest Setup ==="

# Clean restart LND
echo "Restarting LND with fresh wallet..."
pkill lnd 2>/dev/null
sleep 3

# Remove old macaroons
rm -rf ~/.lnd/data/chain/bitcoin/regtest

# Start LND
nohup lnd > ~/.lnd/lnd.log 2>&1 &
sleep 10

# Create new wallet using REST API with auto-generated seed
echo "Creating new LND wallet..."

WALLET_RESPONSE=$(curl -k -X GET https://localhost:8080/v1/genseed 2>/dev/null)
SEED_JSON=$(echo "$WALLET_RESPONSE" | jq '.cipher_seed_mnemonic')

if [ "$SEED_JSON" != "null" ]; then
    # Create wallet with generated seed
    INIT_REQUEST=$(cat <<EOF
{
    "wallet_password": "$(echo -n 'MySuperSecurePassword123!' | base64)",
    "cipher_seed_mnemonic": $SEED_JSON,
    "recovery_window": 0
}
EOF
)
    
    curl -k -X POST https://localhost:8080/v1/initwallet \
        -H "Content-Type: application/json" \
        -d "$INIT_REQUEST" 2>/dev/null
    
    echo "✅ Wallet created"
    sleep 5
fi

# Verify LND is ready
echo "Checking LND status..."
lncli --network=regtest getinfo

# Fund LND wallet
echo "Funding LND wallet..."
LND_ADDR=$(lncli --network=regtest newaddress p2wkh 2>/dev/null | jq -r '.address')

if [ -n "$LND_ADDR" ] && [ "$LND_ADDR" != "null" ]; then
    bitcoin-cli -regtest sendtoaddress "$LND_ADDR" 10
    MINING_ADDR=$(bitcoin-cli -regtest getnewaddress)
    bitcoin-cli -regtest generatetoaddress 6 "$MINING_ADDR" > /dev/null
    echo "✅ Sent 10 BTC to LND: $LND_ADDR"
fi

# Restart Taproot Assets
echo "Starting Taproot Assets..."
pkill tapd 2>/dev/null
sleep 2
nohup tapd > ~/.tapd/tapd.log 2>&1 &
sleep 10

# Check Taproot Assets
echo "Checking Taproot Assets..."
if tapcli --network=regtest getinfo 2>/dev/null; then
    echo "✅ Taproot Assets is running!"
    
    # Now mint the stablecoin
    echo
    echo "=== Minting Stablecoin ==="
    
    # Mint USDT
    MINT_RESPONSE=$(tapcli --network=regtest assets mint \
        --type normal \
        --name "USDT" \
        --supply 1000000 \
        --meta_bytes "$(echo -n 'USD-Stablecoin' | xxd -p)" \
        --enable_emission \
        --decimal_display 2 2>&1)
    
    echo "$MINT_RESPONSE"
    
    if echo "$MINT_RESPONSE" | grep -q "batch_key"; then
        BATCH_KEY=$(echo "$MINT_RESPONSE" | grep -o '"batch_key":"[^"]*"' | cut -d'"' -f4)
        
        echo "Finalizing mint batch: $BATCH_KEY"
        tapcli --network=regtest assets mint finalize --batch_key "$BATCH_KEY"
        
        echo "✅ Stablecoin minted!"
        
        # Wait for confirmation
        sleep 3
        
        # Mine a block to confirm
        bitcoin-cli -regtest generatetoaddress 1 "$MINING_ADDR" > /dev/null
        
        sleep 2
        
        # List assets
        echo
        echo "=== Minted Assets ==="
        tapcli --network=regtest assets list
        
        # Create test address
        echo
        echo "=== Creating Test Address ==="
        ASSET_ID=$(tapcli --network=regtest assets list 2>/dev/null | jq -r '.assets[0].asset_genesis.asset_id')
        
        if [ -n "$ASSET_ID" ] && [ "$ASSET_ID" != "null" ]; then
            ADDR_RESPONSE=$(tapcli --network=regtest addrs new --asset_id "$ASSET_ID" --amt 100)
            echo "$ADDR_RESPONSE"
            
            # Get balance
            echo
            echo "=== Asset Balance ==="
            tapcli --network=regtest assets balance
        fi
    fi
else
    echo "❌ Taproot Assets not ready yet"
fi

echo
echo "=== Status Summary ==="
echo "Bitcoin: $(bitcoin-cli -regtest getblockcount) blocks"
echo "LND: $(lncli --network=regtest getinfo 2>/dev/null | jq -r '.block_height' || echo 'checking...')"
echo "Taproot Assets: $(tapcli --network=regtest getinfo 2>/dev/null | jq -r '.version' || echo 'starting...')"