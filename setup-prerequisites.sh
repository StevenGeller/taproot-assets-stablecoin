#!/bin/bash

set -e

# Add Go to PATH if installed locally
export PATH=$PATH:~/go/bin:~/bin

echo "=== Taproot Assets Stablecoin Setup - Prerequisites ==="
echo

# Check Go version
check_go_version() {
    if ! command -v go &> /dev/null; then
        echo "❌ Go is not installed. Please install Go 1.19 or higher."
        echo "Visit: https://golang.org/doc/install"
        return 1
    fi
    
    GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    MIN_VERSION="1.19"
    
    if [ "$(printf '%s\n' "$MIN_VERSION" "$GO_VERSION" | sort -V | head -n1)" = "$MIN_VERSION" ]; then
        echo "✅ Go version $GO_VERSION is installed (meets minimum requirement: $MIN_VERSION)"
    else
        echo "❌ Go version $GO_VERSION is too old. Please upgrade to Go $MIN_VERSION or higher."
        return 1
    fi
}

# Install Bitcoin Core
install_bitcoin_core() {
    echo
    echo "=== Installing Bitcoin Core ==="
    
    if command -v bitcoind &> /dev/null; then
        echo "✅ Bitcoin Core is already installed"
        bitcoind --version
    else
        echo "Installing Bitcoin Core..."
        
        # Download and install Bitcoin Core
        BITCOIN_VERSION="25.0"
        wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz
        tar -xzvf bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz
        mkdir -p ~/bin
        cp bitcoin-${BITCOIN_VERSION}/bin/* ~/bin/
        rm -rf bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz bitcoin-${BITCOIN_VERSION}
        export PATH=$PATH:~/bin
        
        echo "✅ Bitcoin Core installed successfully"
    fi
}

# Install LND
install_lnd() {
    echo
    echo "=== Installing LND ==="
    
    if command -v lnd &> /dev/null; then
        echo "✅ LND is already installed"
        lnd --version
    else
        echo "Installing LND v0.18.0-beta..."
        
        # Install LND from source
        git clone https://github.com/lightningnetwork/lnd.git
        cd lnd
        git checkout v0.18.0-beta
        make install
        cd ..
        rm -rf lnd
        
        echo "✅ LND installed successfully"
    fi
}

# Create configuration files
create_configs() {
    echo
    echo "=== Creating Configuration Files ==="
    
    # Bitcoin configuration
    mkdir -p ~/.bitcoin
    cat > ~/.bitcoin/bitcoin.conf << EOF
# Bitcoin Core configuration for Taproot Assets
server=1
testnet=1
rpcuser=taprootuser
rpcpassword=$(openssl rand -hex 32)
rpcallowip=127.0.0.1
zmqpubrawblock=tcp://127.0.0.1:28332
zmqpubrawtx=tcp://127.0.0.1:28333
txindex=1
EOF
    
    echo "✅ Bitcoin configuration created at ~/.bitcoin/bitcoin.conf"
    
    # LND configuration
    mkdir -p ~/.lnd
    cat > ~/.lnd/lnd.conf << EOF
# LND configuration for Taproot Assets
[Application Options]
debuglevel=info
maxpendingchannels=10
alias=TaprootAssetsNode

[Bitcoin]
bitcoin.active=true
bitcoin.testnet=true
bitcoin.node=bitcoind

[Bitcoind]
bitcoind.rpcuser=taprootuser
bitcoind.rpcpass=$(grep rpcpassword ~/.bitcoin/bitcoin.conf | cut -d'=' -f2)
bitcoind.rpchost=localhost:18332
bitcoind.zmqpubrawblock=tcp://127.0.0.1:28332
bitcoind.zmqpubrawtx=tcp://127.0.0.1:28333

[protocol]
protocol.wumbo-channels=true

[wtclient]
wtclient.active=true
EOF
    
    echo "✅ LND configuration created at ~/.lnd/lnd.conf"
}

# Main execution
echo "Starting Taproot Assets prerequisites setup..."
echo

check_go_version || exit 1
install_bitcoin_core
install_lnd
create_configs

echo
echo "=== Prerequisites Setup Complete ==="
echo
echo "Next steps:"
echo "1. Start Bitcoin Core: bitcoind -daemon"
echo "2. Wait for blockchain sync (check with: bitcoin-cli getblockchaininfo)"
echo "3. Create LND wallet: lncli create"
echo "4. Start LND: lnd"
echo
echo "Once Bitcoin Core and LND are synced and running, you can proceed with Taproot Assets installation."