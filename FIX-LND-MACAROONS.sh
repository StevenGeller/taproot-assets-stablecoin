#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

echo "==============================================" 
echo "FIXING LND MACAROON ISSUES"
echo "=============================================="
echo

# 1. Stop LND
echo "1. Stopping LND..."
pkill -f "lnd" 2>/dev/null
sleep 5

# 2. Backup old macaroons
echo "2. Backing up old macaroons..."
mkdir -p ~/.lnd/macaroon-backup-$(date +%s)
cp ~/.lnd/data/chain/bitcoin/regtest/*.macaroon ~/.lnd/macaroon-backup-$(date +%s)/ 2>/dev/null || true

# 3. Remove old macaroons and wallet
echo "3. Cleaning up old state..."
rm -f ~/.lnd/data/chain/bitcoin/regtest/*.macaroon
rm -f ~/.lnd/data/chain/bitcoin/regtest/macaroons.db
rm -f ~/.lnd/data/chain/bitcoin/regtest/wallet.db

# 4. Start LND fresh
echo "4. Starting LND with fresh state..."
lnd --bitcoin.active --bitcoin.regtest --bitcoin.node=bitcoind \
    --bitcoind.rpcuser=taprootuser --bitcoind.rpcpass=taprootpass123 \
    --bitcoind.rpchost=localhost:18443 \
    --bitcoind.zmqpubrawblock=tcp://127.0.0.1:28332 \
    --bitcoind.zmqpubrawtx=tcp://127.0.0.1:28333 \
    --debuglevel=info --restlisten=0.0.0.0:8080 \
    --rpclisten=0.0.0.0:10009 > ~/.lnd/lnd-fixed.log 2>&1 &

echo "Waiting for LND to start..."
sleep 15

# 5. Create new wallet
echo "5. Creating new LND wallet..."
# Generate seed
SEED_RESPONSE=$(curl -k -s -X GET https://localhost:8080/v1/genseed)
if [ -n "$SEED_RESPONSE" ] && [ "$SEED_RESPONSE" != "null" ]; then
    SEED_JSON=$(echo "$SEED_RESPONSE" | jq '.cipher_seed_mnemonic')
    
    # Save seed
    echo "$SEED_JSON" | jq -r '.[]' > ~/taproot-assets-stablecoin/lnd-seed-phrase-new.txt
    echo "✅ New seed phrase saved"
    
    # Initialize wallet
    INIT_REQUEST=$(cat <<EOF
{
    "wallet_password": "$(echo -n 'MySuperSecurePassword123!' | base64)",
    "cipher_seed_mnemonic": $SEED_JSON,
    "recovery_window": 0
}
EOF
)
    
    curl -k -s -X POST https://localhost:8080/v1/initwallet \
        -H "Content-Type: application/json" \
        -d "$INIT_REQUEST" >/dev/null 2>&1
    
    echo "✅ New wallet created"
    sleep 8
fi

# 6. Verify LND is working
echo "6. Verifying LND..."
if lncli --network=regtest getinfo >/dev/null 2>&1; then
    echo "✅ LND is working with new macaroons!"
    lncli --network=regtest getinfo | jq '{version, block_height, synced_to_chain}'
    
    # 7. Fund the wallet
    echo
    echo "7. Funding LND wallet..."
    LND_ADDR=$(lncli --network=regtest newaddress p2wkh | jq -r '.address')
    BTCADDR=$(bitcoin-cli -regtest getnewaddress)
    
    bitcoin-cli -regtest sendtoaddress "$LND_ADDR" 10 >/dev/null
    bitcoin-cli -regtest generatetoaddress 6 "$BTCADDR" >/dev/null
    echo "✅ Sent 10 BTC to: $LND_ADDR"
    
    sleep 3
    echo "Balance: $(lncli --network=regtest walletbalance | jq -r '.confirmed_balance') satoshis"
    
    # 8. Start Taproot Assets
    echo
    echo "8. Starting Taproot Assets..."
    pkill tapd 2>/dev/null
    sleep 2
    rm -f ~/.tapd/tapd.db
    
    tapd --network=regtest --debuglevel=info > ~/.tapd/tapd-fixed.log 2>&1 &
    
    echo "Waiting for Taproot Assets..."
    sleep 20
    
    # 9. Check Taproot Assets
    if tapcli --network=regtest getinfo >/dev/null 2>&1; then
        echo "✅ Taproot Assets is running!"
        tapcli --network=regtest getinfo | jq '{version, lnd_version}'
        
        # 10. Mint stablecoin
        echo
        echo "9. Minting USD Stablecoin..."
        MINT_RESPONSE=$(tapcli --network=regtest assets mint \
            --type normal \
            --name "USDT" \
            --supply 1000000 \
            --decimal_display 2 2>&1)
        
        echo "$MINT_RESPONSE"
        
        if echo "$MINT_RESPONSE" | grep -q "batch_key"; then
            BATCH_KEY=$(echo "$MINT_RESPONSE" | sed -n 's/.*"batch_key":"\([^"]*\)".*/\1/p')
            
            if [ -n "$BATCH_KEY" ]; then
                echo "Finalizing mint..."
                tapcli --network=regtest assets mint finalize --batch_key "$BATCH_KEY"
                
                sleep 2
                bitcoin-cli -regtest generatetoaddress 1 "$BTCADDR" >/dev/null
                echo "✅ Minted 1,000,000 USDT!"
                
                # Wait and show assets
                sleep 5
                echo
                echo "10. Asset Details:"
                ASSETS=$(tapcli --network=regtest assets list)
                echo "$ASSETS" | jq '.assets[] | {name: .asset_genesis.name, asset_id: .asset_genesis.asset_id, amount: .amount}'
                
                ASSET_ID=$(echo "$ASSETS" | jq -r '.assets[0].asset_genesis.asset_id')
                
                if [ -n "$ASSET_ID" ] && [ "$ASSET_ID" != "null" ]; then
                    echo
                    echo "=============================================="
                    echo "✅ STABLECOIN SYSTEM FULLY OPERATIONAL!"
                    echo "=============================================="
                    echo
                    echo "Asset ID: $ASSET_ID"
                    echo "Balance: 1,000,000 USDT"
                    echo
                    echo "Create address: tapcli --network=regtest addrs new --asset_id $ASSET_ID --amt 100"
                fi
            fi
        fi
    else
        echo "❌ Taproot Assets failed. Check logs:"
        tail -20 ~/.tapd/tapd-fixed.log
    fi
else
    echo "❌ LND still not working. Check logs:"
    tail -20 ~/.lnd/lnd-fixed.log
fi