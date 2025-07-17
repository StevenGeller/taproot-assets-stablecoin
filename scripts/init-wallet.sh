#\!/bin/bash

# Initialize LND wallet using REST API

PASSWORD="MySuperSecurePassword123\!"
PASSWORD_B64=$(echo -n "$PASSWORD"  < /dev/null |  base64)

# Create init request
cat > /tmp/init-request.json << JSON
{
  "wallet_password": "$PASSWORD_B64",
  "cipher_seed_mnemonic": [],
  "aezeed_passphrase": "",
  "recovery_window": 0,
  "stateless_init": false
}
JSON

echo "Creating LND wallet..."

# Try to initialize wallet
RESPONSE=$(curl -k -X POST https://localhost:8080/v1/initwallet \
  -H "Content-Type: application/json" \
  -d @/tmp/init-request.json 2>/dev/null)

if [ $? -eq 0 ]; then
  echo "✅ Wallet creation response:"
  echo "$RESPONSE" | jq '.'
  
  # Extract and save seed
  echo "$RESPONSE" | jq -r '.cipher_seed_mnemonic[]' > ~/taproot-assets-stablecoin/wallet-seed.txt
  
  echo ""
  echo "⚠️  WALLET SEED SAVED TO: ~/taproot-assets-stablecoin/wallet-seed.txt"
  echo "KEEP THIS SAFE\!"
else
  echo "❌ Failed to create wallet via REST API"
fi

rm -f /tmp/init-request.json
