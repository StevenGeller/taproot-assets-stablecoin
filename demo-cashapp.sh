#!/bin/bash

export PATH=$PATH:~/go/bin:~/bin

echo "======================================"
echo "CASH APP STYLE WALLET DEMO"
echo "======================================"
echo
echo "This demo shows a Cash App-style interface for USDT transactions."
echo
echo "Current Status:"
echo "- Total USDT: 1,000,000"
echo "- Alice received: 200 USDT"
echo "- Bob received: 150 USDT"
echo
echo "To run the Cash App-style wallet:"
echo "  ./cashapp-style-wallet.sh"
echo
echo "Features:"
echo "✓ Send money between Alice and Bob"
echo "✓ Request money with QR-style addresses"
echo "✓ View transaction history"
echo "✓ Real-time balance updates"
echo
echo "Press Enter to launch the wallet..."
read

# Launch the wallet
/home/steven/taproot-assets-stablecoin/cashapp-style-wallet.sh