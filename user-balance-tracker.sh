#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

# Asset ID
ASSET_ID="60d399559238fd2f2d563989594bd641e60860384bc35c5c9509f1c8fe28bd3b"
BALANCE_FILE="$HOME/taproot-assets-stablecoin/wallets/user_balances.json"

# Initialize balance file if it doesn't exist
if [ ! -f "$BALANCE_FILE" ]; then
    echo '{"alice": 0, "bob": 0, "system": 1000000}' > "$BALANCE_FILE"
fi

# Function to update user balance
update_balance() {
    local user=$1
    local amount=$2
    local operation=$3  # "add" or "subtract"
    
    local current=$(jq -r ".${user} // 0" "$BALANCE_FILE")
    local new_balance
    
    if [ "$operation" = "add" ]; then
        new_balance=$((current + amount))
    else
        new_balance=$((current - amount))
    fi
    
    # Update the balance
    jq ".${user} = $new_balance" "$BALANCE_FILE" > "${BALANCE_FILE}.tmp" && mv "${BALANCE_FILE}.tmp" "$BALANCE_FILE"
}

# Function to get user balance
get_user_balance() {
    local user=$1
    jq -r ".${user} // 0" "$BALANCE_FILE"
}

# Function to transfer between users
transfer_balance() {
    local from=$1
    local to=$2
    local amount=$3
    
    update_balance "$from" "$amount" "subtract"
    update_balance "$to" "$amount" "add"
}

# Export functions for use in other scripts
export -f update_balance
export -f get_user_balance
export -f transfer_balance

# If called directly, show balances
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "User Balances:"
    echo "=============="
    echo "Alice: $(get_user_balance alice) USDT"
    echo "Bob: $(get_user_balance bob) USDT"
    echo "System: $(get_user_balance system) USDT"
    echo
    echo "Total: $(($(get_user_balance alice) + $(get_user_balance bob) + $(get_user_balance system))) USDT"
fi