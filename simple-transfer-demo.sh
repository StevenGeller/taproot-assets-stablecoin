#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

# Asset ID
ASSET_ID="60d399559238fd2f2d563989594bd641e60860384bc35c5c9509f1c8fe28bd3b"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo "======================================"
echo "SIMPLE USDT TRANSFER DEMO"
echo "======================================"
echo

echo "This demo shows how to transfer USDT between two people using Taproot Assets."
echo

# Step 1: Check current balance
echo -e "${YELLOW}Step 1: Check Current Balance${NC}"
BALANCE=$(tapcli --network=regtest assets balance --asset_id "$ASSET_ID" | jq -r '.asset_balances."'$ASSET_ID'".balance')
echo -e "Current Balance: ${GREEN}$BALANCE USDT${NC}"
echo

# Step 2: Create Alice's address
echo -e "${YELLOW}Step 2: Create Alice's Address (to receive 100 USDT)${NC}"
ALICE_ADDR=$(tapcli --network=regtest addrs new --asset_id "$ASSET_ID" --amt 100 | jq -r '.encoded')
echo "Alice's address created:"
echo -e "${BLUE}${ALICE_ADDR:0:60}...${NC}"
echo

# Step 3: Send to Alice
echo -e "${YELLOW}Step 3: Send 100 USDT to Alice${NC}"
echo "Sending..."
SEND_RESULT=$(tapcli --network=regtest assets send --addr "$ALICE_ADDR" 2>&1)

if echo "$SEND_RESULT" | grep -q "anchor_tx_hash"; then
    TX_HASH=$(echo "$SEND_RESULT" | jq -r '.transfer.anchor_tx_hash')
    echo -e "${GREEN}✅ Success!${NC}"
    echo "Transaction ID: $TX_HASH"
    
    # Mine block
    echo "Mining block to confirm..."
    bitcoin-cli -regtest generatetoaddress 1 $(bitcoin-cli -regtest getnewaddress) >/dev/null
    echo -e "${GREEN}✅ Transaction confirmed!${NC}"
else
    echo -e "${RED}Transfer failed${NC}"
fi

echo
echo -e "${YELLOW}Step 4: View Transfer History${NC}"
echo "Recent transfers:"
echo

# Show simplified transfer list
tapcli --network=regtest assets transfers | jq -r '.transfers[-3:] | reverse | .[] | 
    "• Block " + (.anchor_tx_height_hint | tostring) + ": " + 
    (.outputs[] | select(.output_type == "OUTPUT_TYPE_SIMPLE") | .amount + " USDT transferred") + 
    " (TX: " + .anchor_tx_hash[0:20] + "...)"'

echo
echo "======================================"
echo -e "${GREEN}Transfer Complete!${NC}"
echo "======================================"
echo
echo "Key Points:"
echo "• USDT can be sent to any Taproot address"
echo "• Transactions are confirmed on Bitcoin blockchain"
echo "• The total supply remains 1,000,000 USDT (UTXO model)"
echo "• Each transfer splits the UTXO into recipient amount + change"
echo
echo "To see all transfers: ./show-transfers.sh"