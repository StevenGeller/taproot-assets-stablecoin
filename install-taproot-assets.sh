#!/bin/bash

set -e

# Add paths
export PATH=$PATH:~/go/bin:~/bin

echo "=== Installing Taproot Assets Daemon ==="
echo

# Check if prerequisites are met
check_prerequisites() {
    echo "Checking prerequisites..."
    
    if ! command -v go &> /dev/null; then
        echo "❌ Go is not installed. Please run setup-prerequisites.sh first."
        exit 1
    fi
    
    if ! command -v lnd &> /dev/null; then
        echo "❌ LND is not installed. Please run setup-prerequisites.sh first."
        exit 1
    fi
    
    if ! command -v bitcoind &> /dev/null; then
        echo "❌ Bitcoin Core is not installed. Please run setup-prerequisites.sh first."
        exit 1
    fi
    
    echo "✅ All prerequisites are installed"
}

# Install Taproot Assets
install_taproot_assets() {
    echo
    echo "Installing Taproot Assets from source..."
    
    # Clone and build
    git clone --recurse-submodules https://github.com/lightninglabs/taproot-assets.git
    cd taproot-assets
    make install
    cd ..
    
    # Verify installation
    if command -v tapd &> /dev/null; then
        echo "✅ Taproot Assets daemon (tapd) installed successfully"
        tapd --version
    else
        echo "❌ Installation failed"
        exit 1
    fi
    
    if command -v tapcli &> /dev/null; then
        echo "✅ Taproot Assets CLI (tapcli) installed successfully"
    else
        echo "❌ CLI installation failed"
        exit 1
    fi
}

# Create Taproot Assets configuration
create_tapd_config() {
    echo
    echo "Creating Taproot Assets configuration..."
    
    mkdir -p ~/.tapd
    
    # Get LND admin macaroon path
    LND_MACAROON_PATH="${HOME}/.lnd/data/chain/bitcoin/testnet/admin.macaroon"
    LND_TLS_PATH="${HOME}/.lnd/tls.cert"
    
    cat > ~/.tapd/tapd.conf << EOF
# Taproot Assets Configuration
[Application Options]
debuglevel=debug
network=testnet

# API settings
restlisten=0.0.0.0:8089
rpclisten=0.0.0.0:10029

# LND connection
lnd.host=localhost:10009
lnd.macaroonpath=${LND_MACAROON_PATH}
lnd.tlspath=${LND_TLS_PATH}

# Database
sqlite.databasefile=~/.tapd/tapd.db

# Proof courier
proof-courier.hashmailcourier.addr=testnet.universe.lightning.finance:443

# Universe settings
universe.sync-all-assets=true
EOF

    echo "✅ Configuration created at ~/.tapd/tapd.conf"
}

# Create systemd service files
create_systemd_services() {
    echo
    echo "Creating systemd service files..."
    
    # Bitcoin service
    sudo tee /etc/systemd/system/bitcoind.service > /dev/null << EOF
[Unit]
Description=Bitcoin daemon
After=network.target

[Service]
ExecStart=/usr/local/bin/bitcoind -daemon=0
ExecStop=/usr/local/bin/bitcoin-cli stop
User=$USER
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    # LND service
    sudo tee /etc/systemd/system/lnd.service > /dev/null << EOF
[Unit]
Description=LND Lightning Network Daemon
After=bitcoind.service
Requires=bitcoind.service

[Service]
ExecStart=/usr/local/bin/lnd
User=$USER
Restart=on-failure
RestartSec=30
TimeoutStartSec=infinity

[Install]
WantedBy=multi-user.target
EOF

    # Taproot Assets service
    sudo tee /etc/systemd/system/tapd.service > /dev/null << EOF
[Unit]
Description=Taproot Assets Daemon
After=lnd.service
Requires=lnd.service

[Service]
ExecStart=/usr/local/bin/tapd
User=$USER
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    echo "✅ Systemd service files created"
    
    # Reload systemd
    sudo systemctl daemon-reload
}

# Create helper scripts
create_helper_scripts() {
    echo
    echo "Creating helper scripts..."
    
    # Start all services
    cat > ~/taproot-assets-stablecoin/scripts/start-services.sh << 'EOF'
#!/bin/bash
echo "Starting all services..."
sudo systemctl start bitcoind
echo "Waiting for Bitcoin Core to start..."
sleep 10
sudo systemctl start lnd
echo "Waiting for LND to start..."
sleep 15
sudo systemctl start tapd
echo "All services started!"
echo
echo "Check status with:"
echo "  sudo systemctl status bitcoind lnd tapd"
EOF
    
    # Stop all services
    cat > ~/taproot-assets-stablecoin/scripts/stop-services.sh << 'EOF'
#!/bin/bash
echo "Stopping all services..."
sudo systemctl stop tapd
sudo systemctl stop lnd
sudo systemctl stop bitcoind
echo "All services stopped!"
EOF
    
    # Check sync status
    cat > ~/taproot-assets-stablecoin/scripts/check-sync.sh << 'EOF'
#!/bin/bash
echo "=== Service Status ==="
echo
echo "Bitcoin Core:"
bitcoin-cli getblockchaininfo | jq '{chain, blocks, headers, verificationprogress}'
echo
echo "LND:"
lncli getinfo | jq '{synced_to_chain, block_height, block_hash}'
echo
echo "Taproot Assets:"
tapcli getinfo
EOF
    
    chmod +x ~/taproot-assets-stablecoin/scripts/*.sh
    echo "✅ Helper scripts created"
}

# Main execution
check_prerequisites
install_taproot_assets
create_tapd_config
create_systemd_services
create_helper_scripts

echo
echo "=== Taproot Assets Installation Complete ==="
echo
echo "Next steps:"
echo "1. Start all services: ~/taproot-assets-stablecoin/scripts/start-services.sh"
echo "2. Wait for Bitcoin Core and LND to sync"
echo "3. Check sync status: ~/taproot-assets-stablecoin/scripts/check-sync.sh"
echo "4. Once synced, you can mint your stablecoin!"
echo
echo "Important paths:"
echo "- Taproot Assets data: ~/.tapd/"
echo "- Configuration: ~/.tapd/tapd.conf"
echo "- Logs: journalctl -u tapd -f"