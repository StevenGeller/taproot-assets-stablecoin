#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

# Test the activity display
echo "Testing Activity Display..."
echo

# Get transfers and show them
transfers=$(tapcli --network=regtest assets transfers 2>/dev/null)

if [ -n "$transfers" ] && [ "$transfers" != "null" ]; then
    echo "Found transfers. Displaying activity:"
    echo
    
    # Show transfers in Cash App style
    echo "$transfers" | jq -r '.transfers[:10] | reverse | .[] | 
        "\u001b[37mBlock " + (.anchor_tx_height_hint | tostring) + "\u001b[0m\n" +
        (.outputs[] | 
            select(.output_type == "OUTPUT_TYPE_SIMPLE") | 
            "\u001b[32m" + .amount + " USDT\u001b[0m transferred\n"
        ) + 
        "\u001b[90mTX: " + .anchor_tx_hash[0:20] + "...\u001b[0m\n"'
else
    echo "No transfers found"
fi