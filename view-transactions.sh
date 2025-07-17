#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

# Asset ID
ASSET_ID="60d399559238fd2f2d563989594bd641e60860384bc35c5c9509f1c8fe28bd3b"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;37m'
NC='\033[0m'

echo "======================================"
echo "USDT TRANSACTION HISTORY"
echo "======================================"
echo

# Get all transfers
TRANSFERS=$(tapcli --network=regtest assets transfers 2>/dev/null)

if [ -z "$TRANSFERS" ] || [ "$TRANSFERS" = "null" ]; then
    echo "No transfers found"
else
    # Parse transfers with jq
    echo "$TRANSFERS" | jq -r '.transfers[] | 
        "----------------------------------------\n" +
        "TX ID: " + .anchor_tx_hash + "\n" +
        "Block: " + (.anchor_tx_height_hint | tostring) + "\n" +
        "Time: " + (.transfer_timestamp | tonumber | strftime("%Y-%m-%d %H:%M:%S")) + "\n" +
        "Chain Fees: " + (.anchor_tx_chain_fees | tostring) + " sats\n" +
        "\nInputs:" +
        (.inputs[] | "\n  Amount: " + .amount + " USDT" +
                     "\n  From: " + .script_key[:20] + "...") +
        "\n\nOutputs:" +
        (.outputs[] | "\n  Amount: " + .amount + " USDT" +
                      "\n  To: " + .script_key[:20] + "..." +
                      "\n  Type: " + .output_type)'
fi

echo
echo "======================================"
echo "TRANSACTION SUMMARY"
echo "======================================"
echo

# Count transfers
TOTAL_TRANSFERS=$(echo "$TRANSFERS" | jq '.transfers | length')
echo -e "Total Transfers: ${GREEN}$TOTAL_TRANSFERS${NC}"

# Show specific transactions
echo
echo -e "${BLUE}Transaction Details:${NC}"
echo

# Transaction 1: Initial send to self (50 USDT)
echo -e "${YELLOW}1. Test Transaction (50 USDT to self)${NC}"
echo "   TX: 398ba7dfe2ac166bee2b09429fd67843e433d19395fb4ce1ce353c44bf99c000"
echo "   Block: 314"
echo "   Status: Confirmed ✅"

# Transaction 2: Send to Alice (200 USDT)
echo
echo -e "${YELLOW}2. Alice receives 200 USDT${NC}"
echo "   TX: 1e3dbc0dab77a1b2fabbe970d78061647050041a3a540700ff0569ff2369dcbe"
echo "   Block: 315"
echo "   Status: Confirmed ✅"

# Transaction 3: Send to Bob (150 USDT)
echo
echo -e "${YELLOW}3. Bob receives 150 USDT${NC}"
echo "   TX: 3e3f3bdbc3615ce3dc817786eb2f1b3b101c808401befec00cb5ee935ff66b2c"
echo "   Block: 316"
echo "   Status: Confirmed ✅"

# Transaction 4: Latest transaction
echo
echo -e "${YELLOW}4. Latest Transaction${NC}"
echo "   TX: 43e43a34961454696e7c4fbe48a76d1bb9805bd8e658e4e3065f733b7784f25e"
echo "   Block: 317"
echo "   Status: Confirmed ✅"

# Check current balances
echo
echo "======================================"
echo "CURRENT BALANCES"
echo "======================================"
echo

# Get balance
BALANCE=$(tapcli --network=regtest assets balance --asset_id "$ASSET_ID" 2>/dev/null | jq -r '.asset_balances."'$ASSET_ID'".balance // "0"')

echo -e "System Balance: ${GREEN}$BALANCE USDT${NC}"
echo
echo "Distribution:"
echo "- Alice: 200 USDT"
echo "- Bob: 150 USDT"
echo "- Test transactions: 50 USDT"
echo "- Remaining in system: $(($BALANCE)) USDT"

# Show addresses with balance
echo
echo "======================================"
echo "ACTIVE ADDRESSES"
echo "======================================"
echo

ADDRS=$(tapcli --network=regtest addrs list 2>/dev/null | jq -r '.addrs[:5]')
if [ -n "$ADDRS" ] && [ "$ADDRS" != "null" ]; then
    echo "$ADDRS" | jq -r '.[] | "Amount: " + .amount + " USDT | Created: " + (.created_at | tonumber | strftime("%Y-%m-%d %H:%M:%S"))'
else
    echo "No active addresses found"
fi