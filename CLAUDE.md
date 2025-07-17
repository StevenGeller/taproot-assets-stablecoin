# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Taproot Assets USD stablecoin implementation on Bitcoin, featuring a Cash App-style wallet interface. The project uses shell scripts to manage Bitcoin Core, LND (Lightning Network Daemon), and Taproot Assets Daemon, creating a complete stablecoin ecosystem.

## Key Commands

### Initial Setup
```bash
# Complete prerequisite setup (Bitcoin Core, LND, Go)
./setup-prerequisites.sh

# Install Taproot Assets daemon
./install-taproot-assets.sh

# Full working setup (automated)
./FINAL-WORKING-SETUP.sh
```

### Core Operations
```bash
# Complete automated setup and start all services
./FINAL-WORKING-SETUP.sh

# Launch Cash App-style wallet
./cashapp-style-wallet.sh

# Run complete demo
./DEMO-COMPLETE.sh

# Clean restart all services
./FIX-AND-START-ALL.sh

# Clean complete restart
./CLEAN-START-ALL.sh
```

### Development & Testing
```bash
# View all transfers
./show-transfers.sh

# Check user balances
./user-balance-tracker.sh

# Reconcile balances
./reconcile-balances.sh

# Test system activity
./test-activity.sh
```

### Taproot Assets CLI Commands
```bash
# List all assets
tapcli --network=regtest assets list

# Check asset balance
tapcli --network=regtest assets balance --asset_id <ASSET_ID>

# Create new address
tapcli --network=regtest addrs new --asset_id <ASSET_ID> --amt <AMOUNT>

# Send assets
tapcli --network=regtest assets send --addr <ADDRESS>

# View transfers
tapcli --network=regtest assets transfers
```

## Architecture

### Core Components Stack
1. **Bitcoin Core** - Base blockchain layer (regtest mode)
2. **LND** - Lightning Network implementation
3. **Taproot Assets Daemon** - Asset protocol layer
4. **Cash App Wallet** - User interface layer

### Key Files and Configurations
- `configs/stablecoin-config.json` - Main stablecoin configuration
- `configs/asset_id.txt` - Generated asset ID after minting
- `wallets/` - User balance tracking and transaction history
- `scripts/` - Core operational scripts
- `~/.bitcoin/bitcoin.conf` - Bitcoin Core configuration
- `~/.lnd/lnd.conf` - LND configuration
- `~/.tapd/tapd.conf` - Taproot Assets configuration

### Asset Details
- **Asset Name**: USD-Stablecoin  
- **Ticker**: XYZUSD
- **Total Supply**: 1,000,000 XYZUSD
- **Max Supply**: 100,000,000 XYZUSD (configurable)
- **Type**: Grouped Asset (supports additional minting)
- **Decimal Places**: 2
- **Backing**: 1:1 USD reserves (per config)

## Important Implementation Details

### Script Structure
All scripts follow Google Shell Style Guide patterns:
- Use `set -e` for error handling
- Include proper function definitions
- Use `readonly` for constants
- Handle script directories with `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`

### Data Flow
```
User Input → Cash App Wallet → Taproot Assets → LND → Bitcoin Core → Blockchain
```

### Transaction Processing
1. Create receiving address with `tapcli addrs new`
2. Send assets with `tapcli assets send`
3. Mine block with `bitcoin-cli generatetoaddress` (regtest)
4. Update transaction history in `wallets/transaction_history.json`

### User Management
- Alice and Bob are pre-configured test users with tracked balances
- Balance tracking via JSON files in `wallets/user_balances.json`
- Transaction history stored in `wallets/transaction_history.json`
- Current balances: Alice (600 XYZUSD), Bob (450 XYZUSD), System (998,750 XYZUSD)
- Custom addresses supported for external transfers

## Development Notes

### Environment Requirements
- Ubuntu/Debian Linux
- Go 1.19+ 
- Bitcoin Core
- LND v0.18.0-beta
- Taproot Assets (latest from Lightning Labs)

### Network Configuration
- Uses regtest mode for development
- Can be configured for testnet/mainnet
- ZMQ connections for real-time updates
- Universe syncing with Lightning Labs testnet

### Common Issues
- Ensure all services are running before operations
- Check macaroon permissions for LND connections
- Verify blockchain sync status before minting
- Mine blocks manually in regtest mode after transactions

## Testing and Validation

Test system functionality with:
```bash
# Test system activity and transactions
./test-activity.sh

# Run two-person demo (Alice & Bob)
./two-person-demo.sh

# Simple transfer demonstration
./simple-transfer-demo.sh

# Full system demo walkthrough
./demo-walkthrough.sh
```

Validation and monitoring:
```bash
# Monitor system status and services  
./scripts/monitor-system.sh

# Reconcile and validate balances
./reconcile-balances.sh

# Track user balances and transactions
./user-balance-tracker.sh
```