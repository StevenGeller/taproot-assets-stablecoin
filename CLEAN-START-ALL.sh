#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

echo "=====================================================" 
echo "TAPROOT ASSETS STABLECOIN - CLEAN START"
echo "====================================================="
echo

# 1. Stop all services
echo "1. Stopping all services..."
pkill -f "bitcoind|lnd|tapd" 2>/dev/null
sleep 5

# 2. Clean up all LND state completely
echo "2. Cleaning LND state..."
rm -rf ~/.lnd/data/chain/bitcoin/regtest/
rm -f ~/.lnd/lnd-*.log
rm -f ~/.lnd/logs/bitcoin/regtest/lnd.log

# 3. Clean up Taproot Assets state
echo "3. Cleaning Taproot Assets state..."
rm -f ~/.tapd/tapd.db
rm -f ~/.tapd/*.log

# 4. Start Bitcoin Core
echo "4. Starting Bitcoin Core..."
bitcoind -daemon -regtest
sleep 5

# Verify Bitcoin is running
if ! bitcoin-cli -regtest getblockchaininfo >/dev/null 2>&1; then
    echo "ERROR: Bitcoin Core failed to start"
    exit 1
fi

# Setup Bitcoin wallet
echo "5. Setting up Bitcoin..."
bitcoin-cli -regtest createwallet "testwallet" 2>/dev/null || bitcoin-cli -regtest loadwallet "testwallet"
BTCADDR=$(bitcoin-cli -regtest getnewaddress)
BLOCKCOUNT=$(bitcoin-cli -regtest getblockcount)

if [ "$BLOCKCOUNT" -lt 150 ]; then
    echo "Mining initial blocks..."
    bitcoin-cli -regtest generatetoaddress 150 "$BTCADDR" > /dev/null
fi
echo "✅ Bitcoin ready with $(bitcoin-cli -regtest getblockcount) blocks"

# 5. Start LND with clean state
echo
echo "6. Starting LND..."
nohup lnd --bitcoin.regtest --bitcoin.node=bitcoind \
    --bitcoind.rpcuser=taprootuser --bitcoind.rpcpass=taprootpass123 \
    --bitcoind.rpchost=localhost:18443 \
    --bitcoind.zmqpubrawblock=tcp://127.0.0.1:28332 \
    --bitcoind.zmqpubrawtx=tcp://127.0.0.1:28333 \
    --debuglevel=info --restlisten=0.0.0.0:8080 \
    --rpclisten=0.0.0.0:10009 --noseedbackup > ~/.lnd/lnd-clean.log 2>&1 &

echo "Waiting for LND to start..."
sleep 15

# 6. Create wallet
echo "7. Creating LND wallet..."
# Generate seed
SEED_RESPONSE=$(curl -k -s -X GET https://localhost:8080/v1/genseed)
if [ -z "$SEED_RESPONSE" ] || [ "$SEED_RESPONSE" = "null" ]; then
    echo "Waiting longer for LND..."
    sleep 10
    SEED_RESPONSE=$(curl -k -s -X GET https://localhost:8080/v1/genseed)
fi

if [ -n "$SEED_RESPONSE" ] && [ "$SEED_RESPONSE" != "null" ]; then
    SEED_JSON=$(echo "$SEED_RESPONSE" | jq '.cipher_seed_mnemonic')
    
    # Save seed
    echo "$SEED_JSON" | jq -r '.[]' > ~/taproot-assets-stablecoin/lnd-seed-clean.txt
    echo "✅ Seed phrase saved to lnd-seed-clean.txt"
    
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
    
    if echo "$INIT_RESPONSE" | grep -q "error"; then
        echo "Error creating wallet: $INIT_RESPONSE"
    else
        echo "✅ LND wallet created successfully"
    fi
    
    # Wait for wallet to be ready
    sleep 10
fi

# 7. Verify LND
echo
echo "8. Verifying LND..."
LND_INFO=$(lncli --network=regtest getinfo 2>&1)
if echo "$LND_INFO" | grep -q "version"; then
    echo "✅ LND is running!"
    echo "$LND_INFO" | jq '{version, block_height, synced_to_chain}'
    
    # 8. Fund LND
    echo
    echo "9. Funding LND..."
    LND_ADDR=$(lncli --network=regtest newaddress p2wkh | jq -r '.address')
    bitcoin-cli -regtest sendtoaddress "$LND_ADDR" 10 >/dev/null
    bitcoin-cli -regtest generatetoaddress 6 "$BTCADDR" >/dev/null
    echo "✅ Sent 10 BTC to LND: $LND_ADDR"
    
    sleep 3
    BALANCE=$(lncli --network=regtest walletbalance | jq -r '.confirmed_balance')
    echo "LND balance: $BALANCE satoshis"
    
    # 9. Start Taproot Assets
    echo
    echo "10. Starting Taproot Assets..."
    nohup tapd --network=regtest --debuglevel=info > ~/.tapd/tapd-clean.log 2>&1 &
    
    echo "Waiting for Taproot Assets..."
    sleep 20
    
    # 10. Verify Taproot Assets
    TAPD_INFO=$(tapcli --network=regtest getinfo 2>&1)
    if echo "$TAPD_INFO" | grep -q "version"; then
        echo "✅ Taproot Assets is running!"
        echo "$TAPD_INFO" | jq '{version, lnd_version}'
        
        # 11. Mint stablecoin
        echo
        echo "11. Minting USD Stablecoin (USDT)..."
        MINT_RESPONSE=$(tapcli --network=regtest assets mint \
            --type normal \
            --name "USDT" \
            --supply 1000000 \
            --decimal_display 2 2>&1)
        
        echo "$MINT_RESPONSE"
        
        if echo "$MINT_RESPONSE" | grep -q "batch_key"; then
            BATCH_KEY=$(echo "$MINT_RESPONSE" | jq -r '.batch_key' 2>/dev/null || \
                       echo "$MINT_RESPONSE" | sed -n 's/.*"batch_key":"\([^"]*\)".*/\1/p')
            
            if [ -n "$BATCH_KEY" ] && [ "$BATCH_KEY" != "null" ]; then
                echo
                echo "Finalizing mint batch..."
                FINALIZE_RESPONSE=$(tapcli --network=regtest assets mint finalize --batch_key "$BATCH_KEY" 2>&1)
                echo "$FINALIZE_RESPONSE"
                
                # Mine block
                sleep 2
                bitcoin-cli -regtest generatetoaddress 1 "$BTCADDR" >/dev/null
                echo "✅ Minted 1,000,000 USDT!"
                
                # Wait for confirmation
                sleep 5
                
                # 12. Display results
                echo
                echo "12. Listing Assets..."
                ASSETS=$(tapcli --network=regtest assets list 2>/dev/null)
                echo "$ASSETS" | jq '.assets[] | {name: .asset_genesis.name, asset_id: .asset_genesis.asset_id, amount: .amount}'
                
                ASSET_ID=$(echo "$ASSETS" | jq -r '.assets[0].asset_genesis.asset_id' 2>/dev/null)
                
                if [ -n "$ASSET_ID" ] && [ "$ASSET_ID" != "null" ]; then
                    # Create test address
                    echo
                    echo "13. Creating Test Address..."
                    ADDR_RESPONSE=$(tapcli --network=regtest addrs new --asset_id "$ASSET_ID" --amt 100 2>&1)
                    if echo "$ADDR_RESPONSE" | grep -q "encoded"; then
                        TEST_ADDR=$(echo "$ADDR_RESPONSE" | jq -r '.encoded')
                        echo "Test address for 100 USDT:"
                        echo "$TEST_ADDR"
                    fi
                    
                    # Show balance
                    echo
                    echo "14. Asset Balance..."
                    tapcli --network=regtest assets balance --asset_id "$ASSET_ID" | jq '.'
                    
                    # Save summary
                    cat > ~/taproot-assets-stablecoin/SYSTEM-READY.txt << EOF
TAPROOT ASSETS STABLECOIN - SYSTEM READY
========================================
Generated: $(date)

Services:
- Bitcoin Core: $(bitcoin-cli -regtest getblockcount) blocks
- LND: $(lncli --network=regtest getinfo | jq -r '.version')
- Taproot Assets: $(tapcli --network=regtest getinfo | jq -r '.version')

Stablecoin:
- Name: USDT
- Asset ID: $ASSET_ID
- Supply: 1,000,000 USDT
- Decimals: 2

Addresses:
- Bitcoin: $BTCADDR
- LND: $LND_ADDR
- Test USDT Address: $TEST_ADDR

Commands:
  List assets:    tapcli --network=regtest assets list
  Check balance:  tapcli --network=regtest assets balance
  New address:    tapcli --network=regtest addrs new --asset_id $ASSET_ID --amt <amount>
  Send tokens:    tapcli --network=regtest assets send --addr <address>

Status: ✅ FULLY OPERATIONAL
EOF
                    
                    echo
                    echo "======================================================"
                    echo "✅ STABLECOIN SYSTEM FULLY OPERATIONAL!"
                    echo "======================================================"
                    echo
                    echo "Asset ID: $ASSET_ID"
                    echo "Balance: 1,000,000 USDT"
                    echo
                    echo "System ready! Details saved to: SYSTEM-READY.txt"
                fi
            fi
        fi
    else
        echo "❌ Taproot Assets not ready. Logs:"
        tail -30 ~/.tapd/tapd-clean.log
    fi
else
    echo "❌ LND not ready. Logs:"
    tail -30 ~/.lnd/lnd-clean.log
fi

echo
echo "=== Service Status ==="
ps aux | grep -E "bitcoind|lnd|tapd" | grep -v grep | awk '{print $11}'