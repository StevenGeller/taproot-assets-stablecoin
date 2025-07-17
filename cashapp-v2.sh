#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

# Asset ID and directories
ASSET_ID="60d399559238fd2f2d563989594bd641e60860384bc35c5c9509f1c8fe28bd3b"
WALLET_DIR="$HOME/taproot-assets-stablecoin/wallets"
BALANCE_FILE="$WALLET_DIR/user_balances.json"
TRANSACTION_LOG="$WALLET_DIR/transaction_log.json"

# Initialize directories and files
mkdir -p "$WALLET_DIR"

# Initialize balance file with actual transferred amounts
if [ ! -f "$BALANCE_FILE" ]; then
    # Based on our transaction history:
    # Alice received: 200 + 200 + 200 = 600 USDT
    # Bob received: 150 + 150 + 150 = 450 USDT
    # Remaining in system: 1000000 - 600 - 450 - test transactions
    echo '{
        "alice": 600,
        "bob": 450,
        "system": 998950,
        "last_updated": "'$(date)'"
    }' > "$BALANCE_FILE"
fi

# Initialize transaction log
if [ ! -f "$TRANSACTION_LOG" ]; then
    echo '{"transactions": []}' > "$TRANSACTION_LOG"
fi

# Cash App style colors
GREEN='\033[0;32m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
DARK_GRAY='\033[1;30m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

# Clear screen with style
clear_screen() {
    clear
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Show header
show_header() {
    clear_screen
    echo -e "${WHITE}${BOLD}💵 USDT Wallet${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Get user balance
get_user_balance() {
    local user=$1
    jq -r ".${user,,} // 0" "$BALANCE_FILE"
}

# Update user balance
update_balance() {
    local user=$1
    local amount=$2
    local operation=$3  # "add" or "subtract"
    
    local current=$(get_user_balance "$user")
    local new_balance
    
    if [ "$operation" = "add" ]; then
        new_balance=$((current + amount))
    else
        new_balance=$((current - amount))
    fi
    
    # Update the balance and timestamp
    jq ".${user,,} = $new_balance | .last_updated = \"$(date)\"" "$BALANCE_FILE" > "${BALANCE_FILE}.tmp" && mv "${BALANCE_FILE}.tmp" "$BALANCE_FILE"
}

# Log transaction
log_transaction() {
    local from=$1
    local to=$2
    local amount=$3
    local tx_id=$4
    
    jq --arg from "$from" --arg to "$to" --arg amount "$amount" --arg tx "$tx_id" --arg time "$(date)" \
        '.transactions += [{"from": $from, "to": $to, "amount": $amount, "tx_id": $tx, "timestamp": $time}]' \
        "$TRANSACTION_LOG" > "${TRANSACTION_LOG}.tmp" && mv "${TRANSACTION_LOG}.tmp" "$TRANSACTION_LOG"
}

# Main screen for user
main_screen() {
    local current_user=$1
    
    while true; do
        show_header
        
        # Get user balance
        local balance=$(get_user_balance "$current_user")
        
        # User indicator
        echo -e "${GRAY}Logged in as: ${WHITE}$current_user${NC}"
        echo
        
        # Display balance
        echo -e "${GRAY}Balance${NC}"
        echo -e "${WHITE}${BOLD}\$$balance${NC}"
        echo
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo
        
        # Action buttons
        echo -e "  ${GREEN}[P]${WHITE} Pay${NC}          ${GREEN}[R]${WHITE} Request${NC}"
        echo
        echo -e "  ${GREEN}[A]${WHITE} Activity${NC}     ${GREEN}[S]${WHITE} Switch User${NC}"
        echo
        echo -e "  ${GREEN}[Q]${WHITE} Quit${NC}"
        echo
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo
        echo -n -e "${GRAY}Choose an option: ${NC}"
        
        read -n 1 choice
        echo
        
        case ${choice,,} in
            p) pay_screen "$current_user" ;;
            r) request_screen "$current_user" ;;
            a) activity_screen "$current_user" ;;
            s) return ;;
            q) exit 0 ;;
        esac
    done
}

# Pay screen
pay_screen() {
    local from_user=$1
    
    show_header
    echo -e "${WHITE}${BOLD}Send Money${NC}"
    echo
    
    # Show sender balance
    local balance=$(get_user_balance "$from_user")
    echo -e "${GRAY}Your balance: ${WHITE}\$$balance${NC}"
    echo
    
    echo -e "${GRAY}To${NC}"
    echo
    
    # Determine recipient options
    if [ "${from_user,,}" = "alice" ]; then
        echo -e "  ${GREEN}1${WHITE} Bob${NC}"
        echo -e "  ${GREEN}2${WHITE} System${NC}"
    else
        echo -e "  ${GREEN}1${WHITE} Alice${NC}"
        echo -e "  ${GREEN}2${WHITE} System${NC}"
    fi
    echo
    echo -e "  ${DARK_GRAY}[B] Back${NC}"
    echo
    echo -n -e "${GRAY}Choose recipient: ${NC}"
    
    read -n 1 recipient_choice
    echo
    
    local to_user=""
    case $recipient_choice in
        1)
            if [ "${from_user,,}" = "alice" ]; then
                to_user="Bob"
            else
                to_user="Alice"
            fi
            ;;
        2) to_user="System" ;;
        b|B) return ;;
        *) return ;;
    esac
    
    # Amount input
    show_header
    echo -e "${WHITE}${BOLD}Send Money${NC}"
    echo
    echo -e "${GRAY}From: ${WHITE}$from_user${NC}"
    echo -e "${GRAY}To: ${WHITE}$to_user${NC}"
    echo -e "${GRAY}Your balance: ${WHITE}\$$balance${NC}"
    echo
    echo -e "${GREEN}$${NC}"
    echo -n -e "${WHITE}${BOLD}"
    read amount
    echo -e "${NC}"
    
    if ! [[ "$amount" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid amount${NC}"
        sleep 2
        return
    fi
    
    if [ "$amount" -gt "$balance" ]; then
        echo -e "${RED}Insufficient balance${NC}"
        sleep 2
        return
    fi
    
    # Confirmation
    show_header
    echo -e "${WHITE}${BOLD}Confirm Payment${NC}"
    echo
    echo -e "${GRAY}Sending${NC}"
    echo -e "${WHITE}${BOLD}\$$amount${NC}"
    echo
    echo -e "${GRAY}From${NC}"
    echo -e "${WHITE}$from_user${NC}"
    echo
    echo -e "${GRAY}To${NC}"
    echo -e "${WHITE}$to_user${NC}"
    echo
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -n -e "${GREEN}[Y] Confirm${NC}  ${DARK_GRAY}[N] Cancel${NC} "
    
    read -n 1 confirm
    echo
    
    if [ "${confirm,,}" != "y" ]; then
        return
    fi
    
    # Process payment
    show_header
    echo -e "${WHITE}${BOLD}Processing...${NC}"
    echo
    
    # Create Taproot address and send
    echo -e "${GRAY}Creating blockchain transaction...${NC}"
    ADDR_RESPONSE=$(tapcli --network=regtest addrs new --asset_id "$ASSET_ID" --amt "$amount" 2>&1)
    
    if echo "$ADDR_RESPONSE" | grep -q "encoded"; then
        ADDR=$(echo "$ADDR_RESPONSE" | jq -r '.encoded')
        
        # Send the transaction
        SEND_RESPONSE=$(tapcli --network=regtest assets send --addr "$ADDR" 2>&1)
        
        if echo "$SEND_RESPONSE" | grep -q "anchor_tx_hash"; then
            TX_ID=$(echo "$SEND_RESPONSE" | jq -r '.transfer.anchor_tx_hash')
            
            # Update balances
            update_balance "$from_user" "$amount" "subtract"
            update_balance "${to_user,,}" "$amount" "add"
            
            # Log transaction
            log_transaction "$from_user" "$to_user" "$amount" "$TX_ID"
            
            # Mine block
            bitcoin-cli -regtest generatetoaddress 1 $(bitcoin-cli -regtest getnewaddress) >/dev/null 2>&1
            
            # Success screen
            show_header
            echo
            echo -e "${GREEN}${BOLD}     ✓${NC}"
            echo
            echo -e "${WHITE}${BOLD}Payment Sent${NC}"
            echo
            echo -e "${GRAY}\$$amount to $to_user${NC}"
            echo
            echo -e "${DARK_GRAY}TX: ${TX_ID:0:20}...${NC}"
            echo
            sleep 3
        else
            echo -e "${RED}Transaction failed${NC}"
            sleep 3
        fi
    else
        echo -e "${RED}Failed to create address${NC}"
        sleep 3
    fi
}

# Request screen
request_screen() {
    local user=$1
    
    show_header
    echo -e "${WHITE}${BOLD}Request Money${NC}"
    echo
    echo -e "${GREEN}$${NC}"
    echo -n -e "${WHITE}${BOLD}"
    read amount
    echo -e "${NC}"
    
    if ! [[ "$amount" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid amount${NC}"
        sleep 2
        return
    fi
    
    # Create receiving address
    show_header
    echo -e "${WHITE}${BOLD}Creating Request...${NC}"
    echo
    
    ADDR_RESPONSE=$(tapcli --network=regtest addrs new --asset_id "$ASSET_ID" --amt "$amount" 2>&1)
    
    if echo "$ADDR_RESPONSE" | grep -q "encoded"; then
        ADDRESS=$(echo "$ADDR_RESPONSE" | jq -r '.encoded')
        
        # Display request
        show_header
        echo -e "${WHITE}${BOLD}Request \$$amount${NC}"
        echo
        echo -e "${GRAY}Share this address to receive payment:${NC}"
        echo
        echo -e "${DARK_GRAY}${ADDRESS:0:50}${NC}"
        echo -e "${DARK_GRAY}${ADDRESS:50:50}${NC}"
        echo -e "${DARK_GRAY}${ADDRESS:100}${NC}"
        echo
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo
        echo -e "${GRAY}Press any key to continue${NC}"
        read -n 1
    else
        echo -e "${RED}Failed to create request${NC}"
        sleep 3
    fi
}

# Activity screen
activity_screen() {
    local user=$1
    
    show_header
    echo -e "${WHITE}${BOLD}Activity${NC}"
    echo
    
    # Show user's transactions from log
    local transactions=$(jq -r --arg user "$user" '.transactions | reverse | .[] | 
        select(.from == $user or .to == $user) | 
        if .from == $user then
            "\u001b[37m" + .timestamp + "\u001b[0m\n\u001b[31m-$" + .amount + "\u001b[0m to " + .to + "\n"
        else
            "\u001b[37m" + .timestamp + "\u001b[0m\n\u001b[32m+$" + .amount + "\u001b[0m from " + .from + "\n"
        end' "$TRANSACTION_LOG" 2>/dev/null)
    
    if [ -z "$transactions" ]; then
        echo -e "${GRAY}No transactions yet${NC}"
    else
        echo "$transactions"
    fi
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${GRAY}Press any key to continue${NC}"
    read -n 1
}

# User selection screen
user_selection() {
    while true; do
        show_header
        echo -e "${WHITE}${BOLD}Select User${NC}"
        echo
        
        # Show balances
        local alice_balance=$(get_user_balance "alice")
        local bob_balance=$(get_user_balance "bob")
        
        echo -e "  ${GREEN}1${WHITE} Alice${NC} ${GRAY}(\$$alice_balance)${NC}"
        echo -e "  ${GREEN}2${WHITE} Bob${NC} ${GRAY}(\$$bob_balance)${NC}"
        echo
        echo -e "  ${DARK_GRAY}[Q] Quit${NC}"
        echo
        echo -n -e "${GRAY}Choose user: ${NC}"
        
        read -n 1 choice
        echo
        
        case $choice in
            1) main_screen "Alice" ;;
            2) main_screen "Bob" ;;
            q|Q) exit 0 ;;
        esac
    done
}

# Start the app
user_selection