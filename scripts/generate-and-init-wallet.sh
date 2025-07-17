#\!/bin/bash

# First, get a new seed from LND
echo "Generating seed phrase..."

RESPONSE=$(curl -k -X GET https://localhost:8080/v1/genseed 2>/dev/null)

if [ $? -eq 0 ] && echo "$RESPONSE"  < /dev/null |  jq -e '.cipher_seed_mnemonic' >/dev/null 2>&1; then
  echo "✅ Seed generated successfully"
  
  # Extract seed words
  SEED_WORDS=$(echo "$RESPONSE" | jq -r '.cipher_seed_mnemonic | join(" ")')
  echo "$SEED_WORDS" > ~/taproot-assets-stablecoin/wallet-seed-words.txt
  
  # Now create wallet with this seed
  PASSWORD="MySuperSecurePassword123\!"
  PASSWORD_B64=$(echo -n "$PASSWORD" | base64)
  
  # Build seed array for JSON
  SEED_JSON=$(echo "$RESPONSE" | jq '.cipher_seed_mnemonic')
  
  # Create init request with seed
  cat > /tmp/init-request.json << JSON
{
  "wallet_password": "$PASSWORD_B64",
  "cipher_seed_mnemonic": $SEED_JSON,
  "aezeed_passphrase": "",
  "recovery_window": 0,
  "stateless_init": false
}
JSON

  echo "Creating wallet with generated seed..."
  
  INIT_RESPONSE=$(curl -k -X POST https://localhost:8080/v1/initwallet \
    -H "Content-Type: application/json" \
    -d @/tmp/init-request.json 2>/dev/null)
  
  if [ $? -eq 0 ]; then
    echo "✅ Wallet initialized\!"
    echo ""
    echo "════════════════════════════════════════════════════"
    echo "WALLET SEED PHRASE (SAVE THIS\!):"
    echo "════════════════════════════════════════════════════"
    cat ~/taproot-assets-stablecoin/wallet-seed-words.txt
    echo "════════════════════════════════════════════════════"
    echo ""
    echo "Password: $PASSWORD"
    echo "Seed saved to: ~/taproot-assets-stablecoin/wallet-seed-words.txt"
  else
    echo "❌ Failed to initialize wallet"
    echo "$INIT_RESPONSE"
  fi
else
  echo "❌ Failed to generate seed"
  echo "$RESPONSE"
fi

rm -f /tmp/init-request.json
