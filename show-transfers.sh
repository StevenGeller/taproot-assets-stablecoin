#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================"
echo "USDT TRANSFER HISTORY"
echo "======================================"
echo

# Get transfers
TRANSFERS=$(tapcli --network=regtest assets transfers 2>/dev/null)

if [ -z "$TRANSFERS" ] || [ "$TRANSFERS" = "null" ]; then
    echo "No transfers found"
    exit 1
fi

# Count transfers
TOTAL=$(echo "$TRANSFERS" | jq '.transfers | length')
echo -e "Total Transfers: ${GREEN}$TOTAL${NC}"
echo

# Show each transfer
echo "$TRANSFERS" | jq -r '.transfers[] | 
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" +
    "TX: \(.anchor_tx_hash)\n" +
    "Block: \(.anchor_tx_height_hint)\n" +
    "Time: \(.transfer_timestamp | tonumber | strftime("%Y-%m-%d %H:%M:%S"))\n" +
    "Fee: \(.anchor_tx_chain_fees) sats\n" +
    "\nOutputs:\n" +
    (.outputs[] | "  • \(.amount) USDT (\(.output_type))") +
    "\n"'

echo "======================================"
echo "SUMMARY"
echo "======================================"
echo

# Get unique blocks
BLOCKS=$(echo "$TRANSFERS" | jq -r '.transfers[].anchor_tx_height_hint' | sort -u)
echo "Transactions across blocks: $BLOCKS"

# Calculate total USDT moved
TOTAL_MOVED=$(echo "$TRANSFERS" | jq '[.transfers[].outputs[] | select(.output_type == "OUTPUT_TYPE_SIMPLE") | .amount | tonumber] | add')
echo -e "Total USDT moved: ${GREEN}$TOTAL_MOVED${NC}"

# Show latest balance
echo
echo "Current System Balance:"
tapcli --network=regtest assets balance --asset_id 60d399559238fd2f2d563989594bd641e60860384bc35c5c9509f1c8fe28bd3b | jq -r '.asset_balances."60d399559238fd2f2d563989594bd641e60860384bc35c5c9509f1c8fe28bd3b".balance' || echo "N/A"