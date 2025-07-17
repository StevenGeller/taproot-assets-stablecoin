# 🪙 Taproot Assets USD Stablecoin

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bitcoin](https://img.shields.io/badge/Bitcoin-Taproot-orange.svg)](https://github.com/bitcoin/bitcoin)
[![Lightning](https://img.shields.io/badge/Lightning-Network-blue.svg)](https://lightning.network/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

A complete implementation of a USD stablecoin on Bitcoin using the Taproot Assets Protocol, featuring a user-friendly wallet interface for easy peer-to-peer transactions.

## 🚀 Features

- **Full Stablecoin Implementation**: 1,000,000 XYZUSD minted on Bitcoin's Taproot Assets Protocol
- **User-Friendly Wallet**: Modern interface for sending and receiving XYZUSD
- **Lightning Network Ready**: Built on LND for future Lightning channel integration
- **Individual User Balances**: Track balances for multiple users (Alice, Bob, etc.)
- **Complete Transaction History**: View all transfers with blockchain confirmations
- **Bitcoin Native**: All transactions settle on the Bitcoin blockchain

## 📋 Prerequisites

- Ubuntu/Debian Linux (tested on Ubuntu 22.04)
- 4GB+ RAM
- 50GB+ free disk space
- Basic command line knowledge

## 🛠️ Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/taproot-assets-stablecoin.git
cd taproot-assets-stablecoin
```

### 2. Run Setup
```bash
./bin/setup
```
This will install and configure:
- Bitcoin Core (regtest mode)
- LND (Lightning Network Daemon)
- Taproot Assets Daemon

### 3. Launch the Wallet
```bash
./bin/usdt-wallet
```

### 4. Run the Demo
```bash
./bin/demo
```

## 📖 Documentation

### Project Structure
```
taproot-assets-stablecoin/
├── bin/                    # Main executables
│   ├── xyzusd-wallet      # User-friendly wallet
│   ├── setup              # Setup script
│   └── demo               # Interactive demo
├── src/                    # Source code
│   ├── setup/             # Installation scripts
│   ├── wallet/            # Wallet implementations
│   ├── demo/              # Demo scripts
│   └── utils/             # Utility functions
├── docs/                   # Documentation
│   ├── guides/            # User guides
│   └── api/               # API documentation
├── tests/                  # Test suite
├── examples/               # Example implementations
└── docker/                 # Docker configuration
```

### Core Components

#### 1. **XYZUSD Stablecoin**
- Asset ID: `60d399559238fd2f2d563989594bd641e60860384bc35c5c9509f1c8fe28bd3b`
- Total Supply: 1,000,000 XYZUSD
- Type: Grouped Asset (supports additional minting)
- Decimal Places: 2

#### 2. **User-Friendly Wallet**
- User-friendly interface with balance tracking
- Send/receive XYZUSD between users
- Transaction history with blockchain confirmations
- Multiple user support (Alice, Bob, etc.)

#### 3. **Blockchain Integration**
- Runs on Bitcoin regtest for development
- Can be configured for testnet/mainnet
- All transactions are on-chain and verifiable

## 🔧 Advanced Usage

### View All Transfers
```bash
./src/utils/show-transfers.sh
```

### Check User Balances
```bash
./src/wallet/balance-tracker.sh
```

### Mint Additional XYZUSD
```bash
./src/utils/mint-asset.sh --amount 100000
```

### Manual Asset Operations
```bash
# List all assets
tapcli --network=regtest assets list

# Check specific balance
tapcli --network=regtest assets balance --asset_id <ASSET_ID>

# Create new address
tapcli --network=regtest addrs new --asset_id <ASSET_ID> --amt 100

# Send assets
tapcli --network=regtest assets send --addr <TAPROOT_ADDRESS>
```

## 🐳 Docker Support

Run the entire stack with Docker:
```bash
docker-compose up -d
```

See [docker/README.md](docker/README.md) for details.

## 🧪 Testing

Run the test suite:
```bash
./tests/run-all-tests.sh
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📊 Transaction Examples

The system has processed multiple real transactions:

| Block | Amount | Type | Status |
|-------|--------|------|--------|
| 314 | 200 XYZUSD | Transfer to Alice | ✅ Confirmed |
| 315 | 150 XYZUSD | Transfer to Bob | ✅ Confirmed |
| 316-321 | Various | Test transactions | ✅ Confirmed |

Total: 1,350 XYZUSD transferred across 9 on-chain transactions

## 🔐 Security Considerations

- **Development Only**: Current configuration is for development/testing
- **Private Keys**: Stored locally in `~/.lnd` and `~/.tapd`
- **Backup**: Always backup seed phrases and channel states
- **Production**: Additional security measures required for production use

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Lightning Labs](https://lightning.engineering/) for Taproot Assets Protocol
- [Bitcoin Core](https://bitcoin.org/) developers
- [LND](https://github.com/lightningnetwork/lnd) team

## 🚧 Roadmap

- [ ] Lightning Network channel integration
- [ ] Web interface
- [ ] Mobile app
- [ ] Multi-signature support
- [ ] Automated market making
- [ ] Cross-chain bridges
- [ ] Regulatory compliance features

---

<p align="center">
Built with ❤️ on Bitcoin
</p>