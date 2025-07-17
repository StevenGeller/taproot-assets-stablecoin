#!/bin/bash

# Organize Taproot Assets Stablecoin Project

echo "Organizing project structure..."

# Create new directory structure
mkdir -p bin
mkdir -p src/{setup,wallet,demo,utils}
mkdir -p docs/{guides,api}
mkdir -p tests
mkdir -p docker
mkdir -p examples

# Move setup scripts
echo "Moving setup scripts..."
mv -f setup-prerequisites.sh src/setup/install-dependencies.sh 2>/dev/null
mv -f install-taproot-assets.sh src/setup/install-taproot-assets.sh 2>/dev/null
mv -f CLEAN-START-ALL.sh src/setup/start-all-services.sh 2>/dev/null
mv -f FIX-AND-START-ALL.sh src/setup/restart-services.sh 2>/dev/null

# Move wallet implementations
echo "Moving wallet scripts..."
mv -f cashapp-v2.sh src/wallet/cashapp-wallet.sh 2>/dev/null
mv -f user-balance-tracker.sh src/wallet/balance-tracker.sh 2>/dev/null
mv -f simple-wallet.sh src/wallet/simple-wallet.sh 2>/dev/null
mv -f cashapp-style-wallet.sh examples/legacy-cashapp-wallet.sh 2>/dev/null

# Move demo scripts
echo "Moving demo scripts..."
mv -f two-person-demo.sh src/demo/two-person-transfer.sh 2>/dev/null
mv -f simple-transfer-demo.sh src/demo/simple-transfer.sh 2>/dev/null
mv -f demo-walkthrough.sh src/demo/interactive-demo.sh 2>/dev/null
mv -f DEMO-COMPLETE.sh examples/complete-demo.sh 2>/dev/null

# Move utility scripts
echo "Moving utility scripts..."
mv -f show-transfers.sh src/utils/show-transfers.sh 2>/dev/null
mv -f view-transactions.sh src/utils/view-transactions.sh 2>/dev/null
mv -f reconcile-balances.sh src/utils/reconcile-balances.sh 2>/dev/null
mv -f test-activity.sh tests/test-activity-display.sh 2>/dev/null

# Move mint scripts
mv -f mint-usdt.sh src/utils/mint-asset.sh 2>/dev/null
mv -f mint-usdt-fixed.sh examples/mint-example.sh 2>/dev/null

# Create main executable scripts
echo "Creating main executables..."

# Create main wallet executable
cat > bin/usdt-wallet << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/../src/wallet/cashapp-wallet.sh" "$@"
EOF

# Create setup executable
cat > bin/setup << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/../src/setup/start-all-services.sh" "$@"
EOF

# Create demo executable
cat > bin/demo << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/../src/demo/interactive-demo.sh" "$@"
EOF

# Make executables
chmod +x bin/*
chmod +x src/**/*.sh

# Clean up old scripts that were consolidated
rm -f CONTINUE-SETUP.sh FIX-LND-MACAROONS.sh FINAL-WORKING-SETUP.sh demo-cashapp.sh 2>/dev/null

echo "✅ Project organized successfully!"
echo
echo "New structure:"
echo "  bin/          - Main executables"
echo "  src/          - Source code"
echo "    setup/      - Setup and installation scripts"
echo "    wallet/     - Wallet implementations"
echo "    demo/       - Demo scripts"
echo "    utils/      - Utility scripts"
echo "  docs/         - Documentation"
echo "  tests/        - Test scripts"
echo "  examples/     - Example code"
echo "  docker/       - Docker configuration"