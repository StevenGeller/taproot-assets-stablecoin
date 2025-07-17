#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

# Asset configuration
ASSET_ID="60d399559238fd2f2d563989594bd641e60860384bc35c5c9509f1c8fe28bd3b"
WALLET_DIR="$HOME/taproot-assets-stablecoin/wallets"

# Colors for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize wallet directory
mkdir -p "$WALLET_DIR"

# Function to display header
show_header() {
    clear
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}   USDT STABLECOIN WALLET SYSTEM    ${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo
}

# Function to get or create user wallet
get_user_wallet() {
    local user=$1
    local wallet_file="$WALLET_DIR/${user}.wallet"
    
    if [ -f "$wallet_file" ]; then
        cat "$wallet_file"
    else
        echo ""
    fi
}

# Function to save wallet info
save_wallet_info() {
    local user=$1
    local address=$2
    local wallet_file="$WALLET_DIR/${user}.wallet"
    
    echo "$address" > "$wallet_file"
}

# Function to check balance
check_balance() {
    local address=$1
    
    # Get all assets and filter for our address
    BALANCE=$(tapcli --network=regtest assets balance 2>/dev/null | jq -r ".asset_balances.\"$ASSET_ID\".balance // \"0\"")
    
    # If address is provided, try to get specific balance
    if [ -n "$address" ]; then
        # For now, we'll use the total balance since Taproot Assets doesn't easily show per-address balance
        echo "$BALANCE"
    else
        echo "$BALANCE"
    fi
}

# Function to create new address
create_address() {
    local amount=$1
    local response=$(tapcli --network=regtest addrs new --asset_id "$ASSET_ID" --amt "$amount" 2>&1)
    
    if echo "$response" | grep -q "encoded"; then
        echo "$response" | jq -r '.encoded'
    else
        echo "ERROR"
    fi
}

# Function to send tokens
send_tokens() {
    local to_address=$1
    
    echo -e "${YELLOW}Sending USDT to address...${NC}"
    SEND_RESPONSE=$(tapcli --network=regtest assets send --addr "$to_address" 2>&1)
    
    if echo "$SEND_RESPONSE" | grep -q "error"; then
        echo -e "${RED}Error: Failed to send tokens${NC}"
        echo "$SEND_RESPONSE"
        return 1
    else
        TXID=$(echo "$SEND_RESPONSE" | jq -r '.transfer.anchor_tx_hash' 2>/dev/null)
        echo -e "${GREEN}✅ Transaction sent successfully!${NC}"
        echo -e "Transaction ID: ${YELLOW}$TXID${NC}"
        
        # Mine a block to confirm
        echo -e "${YELLOW}Mining block to confirm transaction...${NC}"
        bitcoin-cli -regtest generatetoaddress 1 $(bitcoin-cli -regtest getnewaddress) >/dev/null 2>&1
        echo -e "${GREEN}✅ Transaction confirmed!${NC}"
        return 0
    fi
}

# Main menu function
main_menu() {
    while true; do
        show_header
        
        echo "1. Alice's Wallet"
        echo "2. Bob's Wallet"
        echo "3. Check Total System Balance"
        echo "4. Transaction History"
        echo "5. Exit"
        echo
        read -p "Select option (1-5): " choice
        
        case $choice in
            1) user_wallet "Alice" ;;
            2) user_wallet "Bob" ;;
            3) show_system_balance ;;
            4) show_transaction_history ;;
            5) exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
        esac
    done
}

# User wallet menu
user_wallet() {
    local user=$1
    
    while true; do
        show_header
        echo -e "${YELLOW}=== $user's Wallet ===${NC}"
        echo
        
        # Get user's saved address
        USER_ADDR=$(get_user_wallet "$user")
        
        if [ -z "$USER_ADDR" ]; then
            echo -e "${RED}No wallet address found for $user${NC}"
            echo
        else
            echo -e "Wallet Address (first 30 chars): ${BLUE}${USER_ADDR:0:30}...${NC}"
            echo
        fi
        
        # Show balance
        BALANCE=$(check_balance)
        echo -e "Total USDT Balance: ${GREEN}$BALANCE${NC}"
        echo
        
        echo "1. Create/Update Receiving Address"
        echo "2. Send USDT"
        echo "3. Show Full Address"
        echo "4. Back to Main Menu"
        echo
        read -p "Select option (1-4): " wallet_choice
        
        case $wallet_choice in
            1) create_user_address "$user" ;;
            2) send_from_wallet "$user" ;;
            3) show_full_address "$user" ;;
            4) break ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
        esac
    done
}

# Create receiving address for user
create_user_address() {
    local user=$1
    
    echo
    read -p "Enter amount of USDT to receive: " amount
    
    if ! [[ "$amount" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid amount. Please enter a number.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${YELLOW}Creating address for $amount USDT...${NC}"
    NEW_ADDR=$(create_address "$amount")
    
    if [ "$NEW_ADDR" = "ERROR" ]; then
        echo -e "${RED}Failed to create address${NC}"
        sleep 3
    else
        save_wallet_info "$user" "$NEW_ADDR"
        echo -e "${GREEN}✅ New address created successfully!${NC}"
        echo
        echo "Address (for receiving $amount USDT):"
        echo -e "${BLUE}$NEW_ADDR${NC}"
        echo
        echo "This address has been saved as $user's wallet address."
        echo
        read -p "Press Enter to continue..."
    fi
}

# Send tokens from wallet
send_from_wallet() {
    local from_user=$1
    
    echo
    echo "Send USDT to:"
    echo "1. Alice"
    echo "2. Bob"
    echo "3. Custom Address"
    echo
    read -p "Select recipient (1-3): " recipient_choice
    
    local to_address=""
    case $recipient_choice in
        1)
            if [ "$from_user" = "Alice" ]; then
                echo -e "${RED}Cannot send to yourself${NC}"
                sleep 2
                return
            fi
            to_address=$(get_user_wallet "Alice")
            ;;
        2)
            if [ "$from_user" = "Bob" ]; then
                echo -e "${RED}Cannot send to yourself${NC}"
                sleep 2
                return
            fi
            to_address=$(get_user_wallet "Bob")
            ;;
        3)
            read -p "Enter recipient address: " to_address
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            sleep 2
            return
            ;;
    esac
    
    if [ -z "$to_address" ]; then
        echo -e "${RED}Recipient has no wallet address. They need to create one first.${NC}"
        sleep 3
        return
    fi
    
    echo
    echo -e "Sending to: ${BLUE}${to_address:0:50}...${NC}"
    echo
    read -p "Confirm send? (y/n): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        send_tokens "$to_address"
        read -p "Press Enter to continue..."
    fi
}

# Show full address
show_full_address() {
    local user=$1
    local addr=$(get_user_wallet "$user")
    
    if [ -z "$addr" ]; then
        echo -e "${RED}No address found for $user${NC}"
    else
        echo
        echo -e "${YELLOW}$user's Full Address:${NC}"
        echo -e "${BLUE}$addr${NC}"
    fi
    echo
    read -p "Press Enter to continue..."
}

# Show system balance
show_system_balance() {
    show_header
    echo -e "${YELLOW}=== System Balance ===${NC}"
    echo
    
    # Get total balance
    TOTAL_BALANCE=$(tapcli --network=regtest assets balance --asset_id "$ASSET_ID" 2>/dev/null | jq -r '.asset_balances."'$ASSET_ID'".balance // "0"')
    
    echo -e "Total USDT in System: ${GREEN}$TOTAL_BALANCE${NC}"
    echo
    echo "Asset Details:"
    echo -e "  Name: ${BLUE}USDT${NC}"
    echo -e "  Asset ID: ${BLUE}${ASSET_ID:0:20}...${NC}"
    echo
    
    # Show all addresses with balance
    echo "Recent Addresses:"
    tapcli --network=regtest addrs list | jq -r '.addrs[:5] | .[] | "  Amount: \(.amount) USDT"' 2>/dev/null || echo "  No addresses found"
    
    echo
    read -p "Press Enter to continue..."
}

# Show transaction history
show_transaction_history() {
    show_header
    echo -e "${YELLOW}=== Recent Transactions ===${NC}"
    echo
    
    # Get recent transfers
    TRANSFERS=$(tapcli --network=regtest assets transfers 2>/dev/null)
    
    if [ -z "$TRANSFERS" ] || [ "$TRANSFERS" = "null" ]; then
        echo "No transactions found"
    else
        echo "$TRANSFERS" | jq -r '.transfers[:10] | .[] | 
            "TX: \(.txid[:20])... | Amount: \(.amount) | Height: \(.height_hint)"' 2>/dev/null || echo "No recent transactions"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Start the application
main_menu