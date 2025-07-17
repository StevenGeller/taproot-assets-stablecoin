#!/bin/bash

set -e

CONFIG_FILE="../configs/stablecoin-config.json"
ASSET_ID_FILE="../configs/asset_id.txt"

# Load configuration
ASSET_TICKER=$(jq -r '.asset.ticker' "$CONFIG_FILE")
DECIMAL_PLACES=$(jq -r '.minting.decimal_places' "$CONFIG_FILE")

# Check if asset ID exists
if [ ! -f "$ASSET_ID_FILE" ]; then
    echo "❌ Asset ID not found. Please run mint-stablecoin.sh first."
    exit 1
fi

ASSET_ID=$(cat "$ASSET_ID_FILE")

echo "=== Token Issuance System ==="
echo "Asset: $ASSET_TICKER (ID: $ASSET_ID)"
echo

# Function to create a new address for receiving tokens
create_address() {
    echo "Creating new Taproot Assets address..."
    
    ADDRESS_RESPONSE=$(tapcli addrs new --asset_id "$ASSET_ID" --amt "$1")
    ADDRESS=$(echo "$ADDRESS_RESPONSE" | jq -r '.encoded')
    
    echo "✅ New address created:"
    echo "$ADDRESS"
    echo
    
    # Save address for reference
    echo "$ADDRESS_RESPONSE" >> ../backups/addresses_$(date +%Y%m%d).json
    
    echo "$ADDRESS"
}

# Function to send tokens
send_tokens() {
    local recipient_address=$1
    local amount=$2
    
    echo "Sending $amount $ASSET_TICKER to $recipient_address..."
    
    # Send the assets
    SEND_RESPONSE=$(tapcli assets send --addr "$recipient_address")
    
    echo "$SEND_RESPONSE"
    
    # Extract transfer ID
    TRANSFER_ID=$(echo "$SEND_RESPONSE" | jq -r '.transfer_txid')
    echo "✅ Transfer initiated. ID: $TRANSFER_ID"
    
    # Save transfer record
    echo "{\"transfer_id\": \"$TRANSFER_ID\", \"amount\": $amount, \"recipient\": \"$recipient_address\", \"timestamp\": \"$(date -Iseconds)\"}" >> ../backups/transfers_$(date +%Y%m%d).json
}

# Function to check pending transfers
check_transfers() {
    echo
    echo "=== Pending Transfers ==="
    tapcli assets transfers
}

# Function to generate invoice
generate_invoice() {
    local amount=$1
    local memo=$2
    
    echo "Generating invoice for $amount $ASSET_TICKER..."
    echo "Memo: $memo"
    
    # First create a Taproot Assets address
    ADDRESS=$(create_address "$amount")
    
    # Create Lightning invoice if LND is connected
    if lncli getinfo &> /dev/null; then
        # Convert to satoshis based on exchange rate
        EXCHANGE_RATE=$(jq -r '.lightning.exchange_rate.btc_per_token' "$CONFIG_FILE")
        SATS=$(echo "scale=0; $amount * $EXCHANGE_RATE * 100000000 / 1" | bc)
        
        INVOICE=$(lncli addinvoice --amt "$SATS" --memo "$memo" | jq -r '.payment_request')
        
        echo
        echo "Lightning Invoice:"
        echo "$INVOICE"
    fi
    
    echo
    echo "Taproot Assets Address:"
    echo "$ADDRESS"
}

# Function to burn tokens
burn_tokens() {
    local amount=$1
    local reason=$2
    
    echo "Burning $amount $ASSET_TICKER..."
    echo "Reason: $reason"
    
    # Create a burn address (sending to an unspendable address)
    BURN_ADDRESS=$(tapcli addrs new --asset_id "$ASSET_ID" --amt "$amount" | jq -r '.encoded')
    
    # Send to burn address
    tapcli assets send --addr "$BURN_ADDRESS"
    
    echo "✅ Tokens burned"
    
    # Log burn event
    echo "{\"amount\": $amount, \"reason\": \"$reason\", \"timestamp\": \"$(date -Iseconds)\"}" >> ../backups/burns_$(date +%Y%m%d).json
}

# Function to display balance
display_balance() {
    echo
    echo "=== Current Balance ==="
    tapcli assets balance --asset_id "$ASSET_ID"
}

# Interactive menu
show_menu() {
    echo
    echo "=== Token Operations ==="
    echo "1. Create new address"
    echo "2. Send tokens"
    echo "3. Generate invoice"
    echo "4. Check transfers"
    echo "5. Display balance"
    echo "6. Burn tokens"
    echo "7. Exit"
    echo
    read -p "Select operation (1-7): " choice
    
    case $choice in
        1)
            read -p "Amount of tokens: " amount
            create_address "$amount"
            ;;
        2)
            read -p "Recipient address: " recipient
            read -p "Amount to send: " amount
            send_tokens "$recipient" "$amount"
            ;;
        3)
            read -p "Amount: " amount
            read -p "Memo: " memo
            generate_invoice "$amount" "$memo"
            ;;
        4)
            check_transfers
            ;;
        5)
            display_balance
            ;;
        6)
            read -p "Amount to burn: " amount
            read -p "Reason: " reason
            burn_tokens "$amount" "$reason"
            ;;
        7)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
}

# Main loop
main() {
    while true; do
        show_menu
        read -p "Press Enter to continue..."
    done
}

# Check if running interactively
if [ "$1" == "--create-address" ]; then
    create_address "$2"
elif [ "$1" == "--send" ]; then
    send_tokens "$2" "$3"
elif [ "$1" == "--invoice" ]; then
    generate_invoice "$2" "$3"
else
    main
fi