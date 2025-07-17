#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

# Real Asset ID from our minted USDT
ASSET_ID="60d399559238fd2f2d563989594bd641e60860384bc35c5c9509f1c8fe28bd3b"
WALLET_DIR="$HOME/taproot-assets-stablecoin/wallets"
HISTORY_FILE="$WALLET_DIR/transaction_history.json"

# Initialize directories
mkdir -p "$WALLET_DIR"

# Cash App style colors
GREEN='\033[0;32m'      # Cash App green
DARK_GREEN='\033[0;90m'  # Dark green
WHITE='\033[1;37m'       # Bright white
GRAY='\033[0;37m'        # Gray
DARK_GRAY='\033[1;30m'   # Dark gray
NC='\033[0m'             # No Color
BOLD='\033[1m'

# Initialize transaction history
if [ ! -f "$HISTORY_FILE" ]; then
    echo '{"transactions": []}' > "$HISTORY_FILE"
fi

# Clear screen with style
clear_screen() {
    clear
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Show Cash App style header
show_header() {
    clear_screen
    echo -e "${WHITE}${BOLD}💵 USDT Wallet${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Format amount with $ sign
format_amount() {
    local amount=$1
    echo "\$$amount"
}

# Get current balance
get_balance() {
    local balance=$(tapcli --network=regtest assets balance --asset_id "$ASSET_ID" 2>/dev/null | jq -r '.asset_balances."'$ASSET_ID'".balance // "0"')
    echo "$balance"
}

# Save transaction to history
save_transaction() {
    local type=$1
    local amount=$2
    local user=$3
    local txid=$4
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    jq --arg type "$type" --arg amount "$amount" --arg user "$user" --arg txid "$txid" --arg timestamp "$timestamp" \
        '.transactions += [{"type": $type, "amount": $amount, "user": $user, "txid": $txid, "timestamp": $timestamp}]' \
        "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
}

# Main screen
main_screen() {
    local current_user=$1
    
    while true; do
        show_header
        
        # Get balance
        local balance=$(get_balance)
        
        # Display balance Cash App style
        echo
        echo -e "${GRAY}Balance${NC}"
        echo -e "${WHITE}${BOLD}$(format_amount $balance)${NC}"
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
            a) activity_screen ;;
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
    echo -e "${GRAY}To${NC}"
    echo
    echo -e "  ${GREEN}1${WHITE} Alice${NC}"
    echo -e "  ${GREEN}2${WHITE} Bob${NC}"
    echo -e "  ${GREEN}3${WHITE} Custom Address${NC}"
    echo
    echo -e "  ${DARK_GRAY}[B] Back${NC}"
    echo
    echo -n -e "${GRAY}Choose recipient: ${NC}"
    
    read -n 1 recipient_choice
    echo
    
    local to_user=""
    local to_address=""
    
    case $recipient_choice in
        1)
            if [ "$from_user" = "Alice" ]; then
                echo -e "\n${GRAY}Cannot send to yourself${NC}"
                sleep 2
                return
            fi
            to_user="Alice"
            ;;
        2)
            if [ "$from_user" = "Bob" ]; then
                echo -e "\n${GRAY}Cannot send to yourself${NC}"
                sleep 2
                return
            fi
            to_user="Bob"
            ;;
        3)
            echo
            echo -n -e "${GRAY}Enter address: ${NC}"
            read to_address
            to_user="Custom"
            ;;
        b|B) return ;;
        *) return ;;
    esac
    
    # Amount input screen
    show_header
    echo -e "${WHITE}${BOLD}Send Money${NC}"
    echo
    echo -e "${GRAY}To: ${WHITE}$to_user${NC}"
    echo
    echo -e "${GREEN}$${NC}"
    echo -n -e "${WHITE}${BOLD}"
    read amount
    echo -e "${NC}"
    
    if ! [[ "$amount" =~ ^[0-9]+$ ]]; then
        echo -e "${GRAY}Invalid amount${NC}"
        sleep 2
        return
    fi
    
    # Confirmation screen
    show_header
    echo -e "${WHITE}${BOLD}Confirm Payment${NC}"
    echo
    echo -e "${GRAY}Sending${NC}"
    echo -e "${WHITE}${BOLD}$(format_amount $amount)${NC}"
    echo
    echo -e "${GRAY}To${NC}"
    echo -e "${WHITE}$to_user${NC}"
    echo
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -n -e "${GREEN}[✓] Confirm${NC}  ${DARK_GRAY}[X] Cancel${NC} "
    
    read -n 1 confirm
    echo
    
    if [ "${confirm,,}" != "y" ] && [ "$confirm" != $'\n' ]; then
        return
    fi
    
    # Process payment
    show_header
    echo -e "${WHITE}${BOLD}Processing...${NC}"
    echo
    
    # Create receiving address if needed
    if [ -z "$to_address" ]; then
        echo -e "${GRAY}Creating address for $to_user...${NC}"
        ADDR_RESPONSE=$(tapcli --network=regtest addrs new --asset_id "$ASSET_ID" --amt "$amount" 2>&1)
        to_address=$(echo "$ADDR_RESPONSE" | jq -r '.encoded' 2>/dev/null)
        
        if [ -z "$to_address" ] || [ "$to_address" = "null" ]; then
            echo -e "\n${GRAY}Failed to create address${NC}"
            sleep 3
            return
        fi
    fi
    
    # Send payment
    echo -e "${GRAY}Sending payment...${NC}"
    SEND_RESPONSE=$(tapcli --network=regtest assets send --addr "$to_address" 2>&1)
    
    if echo "$SEND_RESPONSE" | grep -q "anchor_tx_hash"; then
        TXID=$(echo "$SEND_RESPONSE" | jq -r '.transfer.anchor_tx_hash')
        
        # Mine block
        bitcoin-cli -regtest generatetoaddress 1 $(bitcoin-cli -regtest getnewaddress) >/dev/null 2>&1
        
        # Save transaction
        save_transaction "sent" "$amount" "$to_user" "$TXID"
        
        # Success screen
        show_header
        echo
        echo -e "${GREEN}${BOLD}     ✓${NC}"
        echo
        echo -e "${WHITE}${BOLD}Payment Sent${NC}"
        echo
        echo -e "${GRAY}$(format_amount $amount) to $to_user${NC}"
        echo
        echo -e "${DARK_GRAY}Transaction: ${TXID:0:20}...${NC}"
        echo
        sleep 3
    else
        echo -e "\n${GRAY}Payment failed${NC}"
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
        echo -e "${GRAY}Invalid amount${NC}"
        sleep 2
        return
    fi
    
    # Create receiving address
    show_header
    echo -e "${WHITE}${BOLD}Creating Request...${NC}"
    echo
    
    ADDR_RESPONSE=$(tapcli --network=regtest addrs new --asset_id "$ASSET_ID" --amt "$amount" 2>&1)
    ADDRESS=$(echo "$ADDR_RESPONSE" | jq -r '.encoded' 2>/dev/null)
    
    if [ -z "$ADDRESS" ] || [ "$ADDRESS" = "null" ]; then
        echo -e "${GRAY}Failed to create request${NC}"
        sleep 3
        return
    fi
    
    # Display request
    show_header
    echo -e "${WHITE}${BOLD}Request $(format_amount $amount)${NC}"
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
}

# Activity screen
activity_screen() {
    show_header
    echo -e "${WHITE}${BOLD}Activity${NC}"
    echo
    
    # Get recent transfers from tapd
    local transfers=$(tapcli --network=regtest assets transfers 2>/dev/null | jq -r '.transfers[:10]' 2>/dev/null)
    
    if [ -z "$transfers" ] || [ "$transfers" = "null" ] || [ "$transfers" = "[]" ]; then
        echo -e "${GRAY}No recent activity${NC}"
    else
        # Get transaction history
        local history=$(cat "$HISTORY_FILE" 2>/dev/null | jq -r '.transactions | reverse | .[:10]' 2>/dev/null)
        
        if [ -n "$history" ] && [ "$history" != "null" ] && [ "$history" != "[]" ]; then
            echo "$history" | jq -r '.[] | 
                if .type == "sent" then
                    "\u001b[37m" + .timestamp + "\u001b[0m\n\u001b[31m-$" + .amount + "\u001b[0m to " + .user + "\n"
                else
                    "\u001b[37m" + .timestamp + "\u001b[0m\n\u001b[32m+$" + .amount + "\u001b[0m from " + .user + "\n"
                end'
        else
            # Show raw transfers if no history - fixed to show actual transfer data
            echo "$transfers" | jq -r '.[] | 
                "\u001b[37mBlock " + (.anchor_tx_height_hint | tostring) + "\u001b[0m\n" +
                (.outputs[] | 
                    select(.output_type == "OUTPUT_TYPE_SIMPLE") | 
                    "\u001b[32m" + .amount + " USDT\u001b[0m transferred\n"
                ) + 
                "\u001b[90mTX: " + .anchor_tx_hash[0:20] + "...\u001b[0m\n"'
        fi
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
        echo -e "  ${GREEN}1${WHITE} Alice${NC}"
        echo -e "  ${GREEN}2${WHITE} Bob${NC}"
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