#!/bin/bash

set -e

CONFIG_FILE="../configs/stablecoin-config.json"
ASSET_ID_FILE="../configs/asset_id.txt"

# Load configuration
ASSET_TICKER=$(jq -r '.asset.ticker' "$CONFIG_FILE")
MIN_CHANNEL_SIZE=$(jq -r '.lightning.min_channel_size' "$CONFIG_FILE")
MAX_CHANNEL_SIZE=$(jq -r '.lightning.max_channel_size' "$CONFIG_FILE")
EXCHANGE_RATE=$(jq -r '.lightning.exchange_rate.btc_per_token' "$CONFIG_FILE")

# Check if asset ID exists
if [ ! -f "$ASSET_ID_FILE" ]; then
    echo "❌ Asset ID not found. Please run mint-stablecoin.sh first."
    exit 1
fi

ASSET_ID=$(cat "$ASSET_ID_FILE")

echo "=== Lightning Channel Setup for $ASSET_TICKER ==="
echo "Asset ID: $ASSET_ID"
echo

# Function to list available peers
list_peers() {
    echo "=== Connected Peers ==="
    lncli listpeers | jq -r '.peers[] | "\(.pub_key) - \(.address)"'
}

# Function to connect to a peer
connect_peer() {
    local peer_uri=$1
    echo "Connecting to peer: $peer_uri"
    
    lncli connect "$peer_uri"
    echo "✅ Connected to peer"
}

# Function to open a regular channel
open_regular_channel() {
    local peer_pubkey=$1
    local local_amt=$2
    
    echo "Opening regular Lightning channel..."
    echo "Peer: $peer_pubkey"
    echo "Amount: $local_amt sats"
    
    lncli openchannel --node_key "$peer_pubkey" --local_amt "$local_amt"
    echo "✅ Channel opening initiated"
}

# Function to fund a Taproot Assets channel
fund_asset_channel() {
    local channel_point=$1
    local asset_amount=$2
    
    echo "Funding channel with $asset_amount $ASSET_TICKER..."
    
    # Create funding address for the channel
    FUNDING_ADDR=$(tapcli addrs new --asset_id "$ASSET_ID" --amt "$asset_amount")
    
    # Fund the channel with assets
    tapcli channels fund --asset_id "$ASSET_ID" --amt "$asset_amount" --chan_point "$channel_point"
    
    echo "✅ Channel funded with Taproot Assets"
}

# Function to create asset invoice
create_asset_invoice() {
    local amount=$1
    local memo=$2
    
    echo "Creating Taproot Assets Lightning invoice..."
    
    # Calculate satoshi amount based on exchange rate
    SATS=$(echo "scale=0; $amount * $EXCHANGE_RATE * 100000000 / 1" | bc)
    
    # Create the invoice
    INVOICE=$(tapcli lninvoice add \
        --asset_id "$ASSET_ID" \
        --amt "$amount" \
        --memo "$memo")
    
    echo "$INVOICE"
}

# Function to pay asset invoice
pay_asset_invoice() {
    local invoice=$1
    
    echo "Paying Taproot Assets invoice..."
    
    tapcli lnpayment pay --pay_req "$invoice"
    
    echo "✅ Payment sent"
}

# Function to list asset channels
list_asset_channels() {
    echo
    echo "=== Taproot Asset Channels ==="
    tapcli channels list
}

# Function to show channel balance
show_channel_balance() {
    echo
    echo "=== Channel Balances ==="
    
    # Regular Lightning balance
    echo "Bitcoin channels:"
    lncli channelbalance
    
    echo
    echo "Asset channels:"
    tapcli channels balance --asset_id "$ASSET_ID"
}

# Interactive menu
show_menu() {
    echo
    echo "=== Lightning Channel Operations ==="
    echo "1. List connected peers"
    echo "2. Connect to new peer"
    echo "3. Open regular Lightning channel"
    echo "4. Fund channel with assets"
    echo "5. Create asset invoice"
    echo "6. Pay asset invoice"
    echo "7. List asset channels"
    echo "8. Show channel balances"
    echo "9. Exit"
    echo
    read -p "Select operation (1-9): " choice
    
    case $choice in
        1)
            list_peers
            ;;
        2)
            read -p "Peer URI (pubkey@host:port): " peer_uri
            connect_peer "$peer_uri"
            ;;
        3)
            read -p "Peer public key: " peer_key
            read -p "Channel size (sats): " channel_size
            open_regular_channel "$peer_key" "$channel_size"
            ;;
        4)
            read -p "Channel point (txid:output): " chan_point
            read -p "Asset amount: " asset_amt
            fund_asset_channel "$chan_point" "$asset_amt"
            ;;
        5)
            read -p "Amount ($ASSET_TICKER): " amount
            read -p "Memo: " memo
            create_asset_invoice "$amount" "$memo"
            ;;
        6)
            read -p "Invoice: " invoice
            pay_asset_invoice "$invoice"
            ;;
        7)
            list_asset_channels
            ;;
        8)
            show_channel_balance
            ;;
        9)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
}

# Setup script for first-time channel creation
setup_first_channel() {
    echo "=== First-Time Channel Setup ==="
    echo
    echo "This wizard will help you create your first Taproot Assets channel."
    echo
    
    # Check LND status
    if ! lncli getinfo &> /dev/null; then
        echo "❌ LND is not running or not accessible"
        exit 1
    fi
    
    # Check if we have peers
    PEER_COUNT=$(lncli listpeers | jq '.peers | length')
    if [ "$PEER_COUNT" -eq 0 ]; then
        echo "No peers connected. Let's connect to a peer first."
        echo
        echo "Popular testnet nodes:"
        echo "1. ACINQ: 03933884aaf1d6b108397e5efe5c86bcf2d8ca8d2f700eda99db9214fc2712b134@endurance.acinq.co:9735"
        echo "2. Blockstream: 02f900856ea3b1c5b26aea70c930c24cf0a3d79bbdd8045dd03ff7b6eadb0b9b59@54.87.189.201:9735"
        echo
        read -p "Enter peer URI or number (1-2): " peer_choice
        
        case $peer_choice in
            1)
                PEER_URI="03933884aaf1d6b108397e5efe5c86bcf2d8ca8d2f700eda99db9214fc2712b134@endurance.acinq.co:9735"
                ;;
            2)
                PEER_URI="02f900856ea3b1c5b26aea70c930c24cf0a3d79bbdd8045dd03ff7b6eadb0b9b59@54.87.189.201:9735"
                ;;
            *)
                PEER_URI="$peer_choice"
                ;;
        esac
        
        connect_peer "$PEER_URI"
    fi
    
    echo
    echo "Ready to create a channel with Taproot Assets support!"
    echo
    echo "Minimum channel size: $MIN_CHANNEL_SIZE $ASSET_TICKER"
    echo "Maximum channel size: $MAX_CHANNEL_SIZE $ASSET_TICKER"
    echo "Exchange rate: 1 $ASSET_TICKER = $EXCHANGE_RATE BTC"
    echo
}

# Main execution
main() {
    # Check if this is first run
    if [ "$1" == "--setup" ]; then
        setup_first_channel
    fi
    
    while true; do
        show_menu
        read -p "Press Enter to continue..."
    done
}

# Run main
main "$@"