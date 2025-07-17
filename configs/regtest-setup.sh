#!/bin/bash

# Setup for regtest mode - instant blockchain for immediate testing

export PATH=$PATH:~/go/bin:~/bin

echo "=== Setting up Regtest Mode for Immediate Operation ==="
echo

# Update Bitcoin config for regtest
cat > ~/.bitcoin/bitcoin.conf << EOF
# Bitcoin Core configuration for regtest
regtest=1
server=1
rpcuser=taprootuser
rpcpassword=taprootpass123
rpcallowip=127.0.0.1
zmqpubrawblock=tcp://127.0.0.1:28332
zmqpubrawtx=tcp://127.0.0.1:28333
txindex=1
fallbackfee=0.00001
EOF

# Update LND config for regtest
cat > ~/.lnd/lnd.conf << EOF
[Application Options]
debuglevel=info
maxpendingchannels=10
alias=TaprootAssetsNode

[Bitcoin]
bitcoin.active=true
bitcoin.regtest=true
bitcoin.node=bitcoind

[Bitcoind]
bitcoind.rpcuser=taprootuser
bitcoind.rpcpass=taprootpass123
bitcoind.rpchost=localhost:18443
bitcoind.zmqpubrawblock=tcp://127.0.0.1:28332
bitcoind.zmqpubrawtx=tcp://127.0.0.1:28333

[protocol]
protocol.wumbo-channels=true
EOF

# Update Taproot Assets config for regtest
cat > ~/.tapd/tapd.conf << EOF
[Application Options]
debuglevel=debug
network=regtest

# API settings
restlisten=0.0.0.0:8089
rpclisten=0.0.0.0:10029

# LND connection
lnd.host=localhost:10009
lnd.macaroonpath=/home/steven/.lnd/data/chain/bitcoin/regtest/admin.macaroon
lnd.tlspath=/home/steven/.lnd/tls.cert

# Database
databasebackend=sqlite
sqlite.dbfile=/home/steven/.tapd/tapd.db

# Allow public universe
allow-public-uni-proof-courier=true
EOF

echo "✅ Configuration files updated for regtest"
echo

# Start Bitcoin in regtest
echo "Starting Bitcoin Core in regtest mode..."
bitcoind -daemon

sleep 5

# Create/load wallet
echo "Creating Bitcoin wallet..."
bitcoin-cli -regtest createwallet "testwallet" 2>/dev/null || bitcoin-cli -regtest loadwallet "testwallet"

# Generate some blocks to have coins
echo "Generating initial blocks..."
ADDR=$(bitcoin-cli -regtest getnewaddress)
bitcoin-cli -regtest generatetoaddress 150 "$ADDR" > /dev/null

echo "✅ Bitcoin regtest ready with 150 blocks"

# Clean LND data for fresh start
echo "Preparing LND for regtest..."
rm -rf ~/.lnd/data/chain/bitcoin/regtest
rm -f ~/.lnd/tls.cert ~/.lnd/tls.key

# Start LND
echo "Starting LND..."
nohup lnd > ~/.lnd/lnd.log 2>&1 &

sleep 10

# Create new wallet for regtest
echo "Creating LND wallet for regtest..."
curl -k -X POST https://localhost:8080/v1/initwallet \
  -H "Content-Type: application/json" \
  -d "{
    \"wallet_password\": \"$(echo -n 'MySuperSecurePassword123!' | base64)\",
    \"cipher_seed_mnemonic\": [],
    \"recovery_window\": 0
  }" 2>/dev/null

sleep 5

# Get LND address and fund it
echo "Funding LND wallet..."
LND_ADDR=$(lncli --network=regtest newaddress p2wkh | jq -r '.address')
bitcoin-cli -regtest sendtoaddress "$LND_ADDR" 10
bitcoin-cli -regtest generatetoaddress 6 "$ADDR" > /dev/null

echo "✅ LND funded with 10 BTC"

# Clean Taproot Assets data
echo "Preparing Taproot Assets..."
rm -rf ~/.tapd/data/regtest
rm -f ~/.tapd/tapd.db

# Start Taproot Assets
echo "Starting Taproot Assets..."
nohup tapd > ~/.tapd/tapd.log 2>&1 &

sleep 10

echo
echo "=== Regtest Setup Complete ==="
echo "All services are running in regtest mode for immediate operation!"
echo
echo "Next: Running stablecoin minting..."