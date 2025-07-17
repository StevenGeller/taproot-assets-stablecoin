#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

# Real Asset ID from our minted USDT
ASSET_ID="60d399559238fd2f2d563989594bd641e60860384bc35c5c9509f1c8fe28bd3b"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================"
echo "TWO-PERSON USDT TRANSACTION DEMO"
echo "======================================"
echo

# First, let's check current balance
echo "1. Checking current USDT balance..."
CURRENT_BALANCE=$(tapcli --network=regtest assets balance --asset_id "$ASSET_ID" 2>/dev/null | jq -r '.asset_balances."'$ASSET_ID'".balance // "0"')
echo -e "   Current Balance: ${GREEN}$CURRENT_BALANCE USDT${NC}"
echo

# Create Alice's receiving address (for 200 USDT)
echo "2. Creating Alice's address to receive 200 USDT..."
ALICE_ADDR_RESPONSE=$(tapcli --network=regtest addrs new --asset_id "$ASSET_ID" --amt 200)
ALICE_ADDR=$(echo "$ALICE_ADDR_RESPONSE" | jq -r '.encoded')
echo -e "   Alice's address: ${BLUE}${ALICE_ADDR:0:60}...${NC}"
echo

# Send 200 USDT to Alice
echo "3. Sending 200 USDT to Alice..."
SEND_TO_ALICE=$(tapcli --network=regtest assets send --addr "$ALICE_ADDR" 2>&1)

if echo "$SEND_TO_ALICE" | grep -q "anchor_tx_hash"; then
    ALICE_TXID=$(echo "$SEND_TO_ALICE" | jq -r '.transfer.anchor_tx_hash')
    echo -e "   ${GREEN}✅ Sent successfully!${NC}"
    echo "   Transaction ID: $ALICE_TXID"
    
    # Mine block to confirm
    echo "   Mining block to confirm..."
    bitcoin-cli -regtest generatetoaddress 1 $(bitcoin-cli -regtest getnewaddress) >/dev/null
    sleep 2
    echo -e "   ${GREEN}✅ Transaction confirmed!${NC}"
else
    echo "   Error sending to Alice: $SEND_TO_ALICE"
fi
echo

# Check balance after sending to Alice
echo "4. Checking balance after Alice's transaction..."
BALANCE_AFTER_ALICE=$(tapcli --network=regtest assets balance --asset_id "$ASSET_ID" 2>/dev/null | jq -r '.asset_balances."'$ASSET_ID'".balance // "0"')
echo -e "   Remaining Balance: ${GREEN}$BALANCE_AFTER_ALICE USDT${NC}"
echo

# Create Bob's receiving address (for 150 USDT)
echo "5. Creating Bob's address to receive 150 USDT..."
BOB_ADDR_RESPONSE=$(tapcli --network=regtest addrs new --asset_id "$ASSET_ID" --amt 150)
BOB_ADDR=$(echo "$BOB_ADDR_RESPONSE" | jq -r '.encoded')
echo -e "   Bob's address: ${BLUE}${BOB_ADDR:0:60}...${NC}"
echo

# Send 150 USDT to Bob
echo "6. Sending 150 USDT to Bob..."
SEND_TO_BOB=$(tapcli --network=regtest assets send --addr "$BOB_ADDR" 2>&1)

if echo "$SEND_TO_BOB" | grep -q "anchor_tx_hash"; then
    BOB_TXID=$(echo "$SEND_TO_BOB" | jq -r '.transfer.anchor_tx_hash')
    echo -e "   ${GREEN}✅ Sent successfully!${NC}"
    echo "   Transaction ID: $BOB_TXID"
    
    # Mine block to confirm
    echo "   Mining block to confirm..."
    bitcoin-cli -regtest generatetoaddress 1 $(bitcoin-cli -regtest getnewaddress) >/dev/null
    sleep 2
    echo -e "   ${GREEN}✅ Transaction confirmed!${NC}"
else
    echo "   Error sending to Bob: $SEND_TO_BOB"
fi
echo

# Check final balance
echo "7. Checking final balance..."
FINAL_BALANCE=$(tapcli --network=regtest assets balance --asset_id "$ASSET_ID" 2>/dev/null | jq -r '.asset_balances."'$ASSET_ID'".balance // "0"')
echo -e "   Final Balance: ${GREEN}$FINAL_BALANCE USDT${NC}"
echo

# Show transaction summary
echo "======================================"
echo "TRANSACTION SUMMARY"
echo "======================================"
echo "Initial Balance: $CURRENT_BALANCE USDT"
echo "Sent to Alice: 200 USDT"
echo "Sent to Bob: 150 USDT"
echo "Final Balance: $FINAL_BALANCE USDT"
echo
echo "Alice's Address: $ALICE_ADDR"
echo "Bob's Address: $BOB_ADDR"
echo

# Show recent transfers
echo "Recent Transfers:"
TRANSFERS=$(tapcli --network=regtest assets transfers 2>/dev/null)
if [ -n "$TRANSFERS" ] && [ "$TRANSFERS" != "null" ]; then
    echo "$TRANSFERS" | jq -r '.transfers[:5] | .[] | 
        "- TX: " + .anchor_tx_hash[0:20] + "..." +
        "\n  Block: " + (.anchor_tx_height_hint | tostring) +
        "\n  Outputs: " + (.outputs | map(.amount) | join(", ")) + " USDT\n"'
else
    echo "No transfers found"
fi

# Save addresses for future use
cat > ~/taproot-assets-stablecoin/demo-addresses.txt << EOF
TWO-PERSON DEMO ADDRESSES
========================
Generated: $(date)

Alice's Address (200 USDT):
$ALICE_ADDR

Bob's Address (150 USDT):
$BOB_ADDR

Transaction IDs:
- To Alice: $ALICE_TXID
- To Bob: $BOB_TXID

Asset ID: $ASSET_ID
EOF

echo
echo "Addresses saved to: demo-addresses.txt"