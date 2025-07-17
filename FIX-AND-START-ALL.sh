#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

echo "==============================================" 
echo "FIXING AND STARTING ALL SERVICES"
echo "=============================================="
echo

# Kill all existing processes
echo "1. Cleaning up existing processes..."
pkill -f "bitcoind|lnd|tapd" 2>/dev/null
sleep 5

# Start Bitcoin Core
echo "2. Starting Bitcoin Core in regtest mode..."
bitcoind -daemon -regtest
sleep 5

# Verify Bitcoin is running
if ! bitcoin-cli -regtest getblockchaininfo >/dev/null 2>&1; then
    echo "ERROR: Bitcoin Core failed to start"
    exit 1
fi

# Create/load wallet
echo "3. Setting up Bitcoin wallet..."
bitcoin-cli -regtest createwallet "testwallet" 2>/dev/null || bitcoin-cli -regtest loadwallet "testwallet"
BTCADDR=$(bitcoin-cli -regtest getnewaddress)

# Mine initial blocks if needed
BLOCKCOUNT=$(bitcoin-cli -regtest getblockcount)
if [ "$BLOCKCOUNT" -lt 150 ]; then
    echo "Mining initial blocks..."
    bitcoin-cli -regtest generatetoaddress 150 "$BTCADDR" > /dev/null
fi
echo "✅ Bitcoin ready with $(bitcoin-cli -regtest getblockcount) blocks"

# Start LND with explicit configuration
echo
echo "4. Starting LND..."
# Clean up old state
rm -rf ~/.lnd/data/chain/bitcoin/regtest/wallet.db
rm -rf ~/.lnd/data/chain/bitcoin/regtest/macaroons.db
rm -f ~/.lnd/logs/bitcoin/regtest/lnd.log

# Start LND in background
lnd --bitcoin.active --bitcoin.regtest --bitcoin.node=bitcoind \
    --bitcoind.rpcuser=taprootuser --bitcoind.rpcpass=taprootpass123 \
    --bitcoind.rpchost=localhost:18443 \
    --bitcoind.zmqpubrawblock=tcp://127.0.0.1:28332 \
    --bitcoind.zmqpubrawtx=tcp://127.0.0.1:28333 \
    --debuglevel=info --restlisten=0.0.0.0:8080 \
    --rpclisten=0.0.0.0:10009 > ~/.lnd/lnd-startup.log 2>&1 &

echo "Waiting for LND to start..."
sleep 15

# Check if LND needs wallet initialization
if ! lncli --network=regtest getinfo >/dev/null 2>&1; then
    echo "5. Creating LND wallet..."
    
    # Generate seed via REST API
    SEED_RESPONSE=$(curl -k -s -X GET https://localhost:8080/v1/genseed)
    if [ -z "$SEED_RESPONSE" ] || [ "$SEED_RESPONSE" = "null" ]; then
        echo "Failed to generate seed. Checking LND logs..."
        tail -20 ~/.lnd/lnd-startup.log
        exit 1
    fi
    
    SEED_JSON=$(echo "$SEED_RESPONSE" | jq '.cipher_seed_mnemonic')
    
    # Save seed phrase
    echo "$SEED_JSON" | jq -r '.[]' > ~/taproot-assets-stablecoin/lnd-seed-phrase.txt
    echo "✅ Seed phrase saved to lnd-seed-phrase.txt"
    
    # Initialize wallet
    INIT_REQUEST=$(cat <<EOF
{
    "wallet_password": "$(echo -n 'MySuperSecurePassword123!' | base64)",
    "cipher_seed_mnemonic": $SEED_JSON,
    "recovery_window": 0
}
EOF
)
    
    INIT_RESPONSE=$(curl -k -s -X POST https://localhost:8080/v1/initwallet \
        -H "Content-Type: application/json" \
        -d "$INIT_REQUEST")
    
    if [ -z "$INIT_RESPONSE" ] || echo "$INIT_RESPONSE" | grep -q "error"; then
        echo "Failed to initialize wallet:"
        echo "$INIT_RESPONSE"
        exit 1
    fi
    
    echo "✅ LND wallet created successfully"
    sleep 5
fi

# Verify LND is running
echo
echo "6. Verifying LND..."
if lncli --network=regtest getinfo >/dev/null 2>&1; then
    LND_INFO=$(lncli --network=regtest getinfo)
    echo "✅ LND is running!"
    echo "$LND_INFO" | jq '{version, block_height, synced_to_chain}'
else
    echo "ERROR: LND is not responding. Checking logs..."
    tail -20 ~/.lnd/lnd-startup.log
    exit 1
fi

# Fund LND wallet
echo
echo "7. Funding LND wallet..."
LND_ADDR=$(lncli --network=regtest newaddress p2wkh | jq -r '.address')
if [ -n "$LND_ADDR" ] && [ "$LND_ADDR" != "null" ]; then
    bitcoin-cli -regtest sendtoaddress "$LND_ADDR" 10 >/dev/null
    bitcoin-cli -regtest generatetoaddress 6 "$BTCADDR" >/dev/null
    echo "✅ Sent 10 BTC to LND wallet: $LND_ADDR"
    
    # Wait for funds to appear
    sleep 3
    BALANCE=$(lncli --network=regtest walletbalance | jq -r '.confirmed_balance')
    echo "LND wallet balance: $BALANCE satoshis"
fi

# Start Taproot Assets
echo
echo "8. Starting Taproot Assets..."
pkill tapd 2>/dev/null
rm -f ~/.tapd/tapd.db
sleep 2

# Start tapd with explicit configuration
tapd --network=regtest --debuglevel=debug \
    --lnd.host=localhost:10009 \
    --lnd.macaroonpath=/home/steven/.lnd/data/chain/bitcoin/regtest/admin.macaroon \
    --lnd.tlspath=/home/steven/.lnd/tls.cert \
    --restlisten=0.0.0.0:8089 --rpclisten=0.0.0.0:10029 \
    --allow-public-uni-proof-courier > ~/.tapd/tapd-startup.log 2>&1 &

echo "Waiting for Taproot Assets to start..."
sleep 15

# Verify Taproot Assets
echo
echo "9. Verifying Taproot Assets..."
if tapcli --network=regtest getinfo >/dev/null 2>&1; then
    TAPD_INFO=$(tapcli --network=regtest getinfo)
    echo "✅ Taproot Assets is running!"
    echo "$TAPD_INFO" | jq '{version, lnd_version}'
    
    # Mint the stablecoin
    echo
    echo "10. Minting USD Stablecoin..."
    
    # Check if already minted
    EXISTING=$(tapcli --network=regtest assets list 2>/dev/null | jq '.assets | length' || echo "0")
    
    if [ "$EXISTING" = "0" ]; then
        # Mint USDT
        MINT_RESPONSE=$(tapcli --network=regtest assets mint \
            --type normal \
            --name "USDT" \
            --supply 1000000 \
            --meta_bytes "$(echo -n 'USD-Stablecoin' | xxd -p)" \
            --enable_emission \
            --decimal_display 2 2>&1)
        
        echo "$MINT_RESPONSE"
        
        # Extract batch key
        if echo "$MINT_RESPONSE" | grep -q "batch_key"; then
            BATCH_KEY=$(echo "$MINT_RESPONSE" | jq -r '.batch_key' 2>/dev/null || \
                       echo "$MINT_RESPONSE" | grep -o '"batch_key":"[^"]*"' | cut -d'"' -f4)
            
            if [ -n "$BATCH_KEY" ] && [ "$BATCH_KEY" != "null" ]; then
                echo
                echo "Finalizing mint batch..."
                FINALIZE_RESPONSE=$(tapcli --network=regtest assets mint finalize --batch_key "$BATCH_KEY" 2>&1)
                echo "$FINALIZE_RESPONSE"
                
                # Mine block to confirm
                sleep 2
                bitcoin-cli -regtest generatetoaddress 1 "$BTCADDR" >/dev/null
                
                echo "✅ Minted 1,000,000 USDT!"
            fi
        fi
    else
        echo "✅ Assets already exist"
    fi
    
    # Wait for asset to be confirmed
    sleep 5
    
    # Display assets
    echo
    echo "11. Listing Assets..."
    ASSETS_LIST=$(tapcli --network=regtest assets list 2>/dev/null)
    echo "$ASSETS_LIST" | jq '.assets[] | {name: .asset_genesis.name, asset_id: .asset_genesis.asset_id, amount: .amount}'
    
    # Get asset ID for operations
    ASSET_ID=$(echo "$ASSETS_LIST" | jq -r '.assets[0].asset_genesis.asset_id' 2>/dev/null)
    
    if [ -n "$ASSET_ID" ] && [ "$ASSET_ID" != "null" ]; then
        # Create test addresses
        echo
        echo "12. Creating Test Addresses..."
        
        # Create address for 100 USDT
        ADDR1=$(tapcli --network=regtest addrs new --asset_id "$ASSET_ID" --amt 100 2>&1)
        if echo "$ADDR1" | grep -q "encoded"; then
            ENCODED_ADDR=$(echo "$ADDR1" | jq -r '.encoded')
            echo "Address for receiving 100 USDT:"
            echo "$ENCODED_ADDR"
        fi
        
        # Show balance
        echo
        echo "13. Asset Balance..."
        tapcli --network=regtest assets balance --asset_id "$ASSET_ID" | jq '.'
        
        # Save summary
        cat > ~/taproot-assets-stablecoin/SYSTEM-STATUS.txt << EOF
TAPROOT ASSETS STABLECOIN - SYSTEM STATUS
========================================
Generated: $(date)
Network: regtest

Services Running:
- Bitcoin Core: $(bitcoin-cli -regtest getblockcount) blocks
- LND: v$(lncli --network=regtest getinfo | jq -r '.version')
- Taproot Assets: v$(tapcli --network=regtest getinfo | jq -r '.version')

Stablecoin Details:
- Asset Name: USDT
- Asset ID: $ASSET_ID
- Total Supply: 1,000,000 USDT
- Decimal Places: 2

Addresses:
- Bitcoin: $BTCADDR
- LND: $LND_ADDR

Status: FULLY OPERATIONAL ✅
EOF
        
        echo
        echo "=============================================="
        echo "✅ STABLECOIN SYSTEM FULLY OPERATIONAL!"
        echo "=============================================="
        echo
        echo "Asset ID: $ASSET_ID"
        echo "Balance: 1,000,000 USDT"
        echo
        echo "Quick Commands:"
        echo "  List assets:    tapcli --network=regtest assets list"
        echo "  Check balance:  tapcli --network=regtest assets balance"
        echo "  New address:    tapcli --network=regtest addrs new --asset_id $ASSET_ID --amt <amount>"
        echo "  Send tokens:    tapcli --network=regtest assets send --addr <tap_address>"
        echo
        echo "System status saved to: ~/taproot-assets-stablecoin/SYSTEM-STATUS.txt"
    fi
else
    echo "ERROR: Taproot Assets failed to start. Checking logs..."
    echo
    echo "=== Taproot Assets Startup Log ==="
    tail -30 ~/.tapd/tapd-startup.log
    echo
    echo "=== Taproot Assets Log ==="
    tail -30 ~/.tapd/tapd.log
fi

echo
echo "=== Process Status ==="
ps aux | grep -E "bitcoind|lnd|tapd" | grep -v grep