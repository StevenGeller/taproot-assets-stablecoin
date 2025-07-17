# 🐳 Docker Setup for Taproot Assets Stablecoin

This directory contains Docker configuration files for running the complete Taproot Assets stablecoin stack in containers.

## 🚀 Quick Start

### Prerequisites
- Docker Engine 20.10+
- Docker Compose 2.0+
- 4GB+ RAM
- 20GB+ free disk space

### Launch the Stack
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Check status
docker-compose ps
```

### First Time Setup
```bash
# Wait for services to be healthy
docker-compose ps

# Create LND wallet (run once)
docker-compose exec lnd lncli --network=regtest create

# Fund the wallet
docker-compose exec bitcoin bitcoin-cli -regtest generatetoaddress 101 $(docker-compose exec bitcoin bitcoin-cli -regtest getnewaddress)

# Mint USDT (run once)
docker-compose exec tapd tapcli --network=regtest assets mint --type normal --name "USDT" --supply 1000000 --new_grouped_asset
```

### Access Services
- **Bitcoin Core RPC**: `http://localhost:18443`
- **LND gRPC**: `localhost:10009`
- **LND REST**: `http://localhost:8080`
- **Taproot Assets REST**: `http://localhost:8089`
- **Wallet Web Interface**: `http://localhost:3000`

## 🏗️ Architecture

### Services Overview
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Wallet Web    │    │   Taproot       │    │      LND        │
│   Interface     │◄──►│   Assets        │◄──►│   Lightning     │
│   (Port 3000)   │    │   (Port 8089)   │    │   (Port 10009)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                 │                        │
                                 │                        │
                                 ▼                        ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   Bitcoin Core  │    │   ZMQ Messages  │
                       │   (Port 18443)  │◄──►│   (Port 28332+) │
                       └─────────────────┘    └─────────────────┘
```

### Container Details

#### Bitcoin Core (`bitcoin`)
- **Image**: `bitcoin/bitcoin:25.0`
- **Network**: regtest
- **Ports**: 18443 (RPC), 18444 (P2P)
- **Volume**: `bitcoin_data`
- **Features**: ZMQ notifications, RPC server

#### LND (`lnd`)
- **Image**: `lightninglabs/lnd:v0.18.4-beta`
- **Network**: regtest
- **Ports**: 10009 (gRPC), 8080 (REST), 9735 (P2P)
- **Volume**: `lnd_data`
- **Features**: Lightning channels, Taproot support

#### Taproot Assets (`tapd`)
- **Image**: Built from source (v0.6.1)
- **Network**: regtest
- **Ports**: 8089 (REST)
- **Volume**: `tapd_data`
- **Features**: Asset minting, transfers

#### Wallet Interface (`wallet`)
- **Image**: Built from Node.js
- **Network**: regtest
- **Ports**: 3000 (Web)
- **Volume**: `wallet_data`
- **Features**: Cash App-style UI

## 🛠️ Configuration

### Environment Variables

Create `.env` file:
```env
# Bitcoin
BITCOIN_NETWORK=regtest
BITCOIN_RPC_USER=bitcoin
BITCOIN_RPC_PASSWORD=bitcoinrpc123

# LND
LND_NETWORK=regtest
LND_ALIAS=taproot-lnd-node

# Taproot Assets
ASSET_ID=60d399559238fd2f2d563989594bd641e60860384bc35c5c9509f1c8fe28bd3b

# Wallet
NODE_ENV=production
WALLET_PORT=3000
```

### Volume Management
```bash
# List volumes
docker volume ls

# Backup volumes
docker run --rm -v taproot-assets-stablecoin_bitcoin_data:/data -v $(pwd):/backup alpine tar czf /backup/bitcoin_backup.tar.gz /data

# Restore volumes
docker run --rm -v taproot-assets-stablecoin_bitcoin_data:/data -v $(pwd):/backup alpine tar xzf /backup/bitcoin_backup.tar.gz -C /

# Remove all volumes (DANGER!)
docker-compose down -v
```

## 🔧 Development

### Building Images
```bash
# Build all images
docker-compose build

# Build specific service
docker-compose build tapd

# Build without cache
docker-compose build --no-cache
```

### Debugging
```bash
# Access container shell
docker-compose exec bitcoin bash
docker-compose exec lnd bash
docker-compose exec tapd sh

# View specific logs
docker-compose logs bitcoin
docker-compose logs lnd
docker-compose logs tapd

# Follow logs
docker-compose logs -f --tail=100 tapd
```

### Testing
```bash
# Run health checks
docker-compose exec bitcoin bitcoin-cli -regtest getblockchaininfo
docker-compose exec lnd lncli --network=regtest getinfo
docker-compose exec tapd tapcli --network=regtest getinfo

# Test wallet functionality
curl http://localhost:3000/health
```

## 🐛 Troubleshooting

### Common Issues

#### Services Not Starting
```bash
# Check logs
docker-compose logs

# Check system resources
docker system df
docker system prune

# Restart services
docker-compose restart
```

#### Permission Issues
```bash
# Fix volume permissions
docker-compose down
docker volume rm taproot-assets-stablecoin_bitcoin_data
docker-compose up -d
```

#### Network Issues
```bash
# Check network connectivity
docker-compose exec bitcoin ping taproot-lnd
docker-compose exec lnd ping taproot-bitcoin

# Recreate network
docker-compose down
docker network prune
docker-compose up -d
```

#### Wallet Issues
```bash
# Reset LND wallet
docker-compose down
docker volume rm taproot-assets-stablecoin_lnd_data
docker-compose up -d lnd
docker-compose exec lnd lncli --network=regtest create
```

### Health Checks
```bash
# Check all services
docker-compose ps

# Manual health check
docker-compose exec bitcoin bitcoin-cli -regtest getblockchaininfo
docker-compose exec lnd lncli --network=regtest getinfo
docker-compose exec tapd tapcli --network=regtest assets list
```

## 📊 Monitoring

### Service Status
```bash
# Service overview
docker-compose ps

# Resource usage
docker stats

# Logs monitoring
docker-compose logs -f --tail=50
```

### Metrics Collection
```bash
# Container metrics
docker-compose exec bitcoin bitcoin-cli -regtest getblockchaininfo | jq '.blocks'
docker-compose exec lnd lncli --network=regtest getinfo | jq '.block_height'
docker-compose exec tapd tapcli --network=regtest assets list | jq '.assets | length'
```

## 🚀 Production Deployment

### Security Considerations
- Change default passwords
- Enable TLS/SSL
- Configure firewall rules
- Use secrets management
- Regular backups

### Scaling
```bash
# Scale wallet service
docker-compose up -d --scale wallet=3

# Load balancer configuration
# Add nginx or traefik configuration
```

### Maintenance
```bash
# Update images
docker-compose pull
docker-compose up -d

# Cleanup
docker system prune -a
docker volume prune
```

## 📝 Scripts

### Useful Commands
```bash
# Complete reset
./docker/scripts/reset-all.sh

# Backup data
./docker/scripts/backup.sh

# Restore data
./docker/scripts/restore.sh backup-20240101.tar.gz

# Health check
./docker/scripts/health-check.sh
```

### Custom Scripts
Create `docker/scripts/` directory for custom maintenance scripts.

## 🔗 Related Documentation

- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Bitcoin Core Docker](https://hub.docker.com/r/bitcoin/bitcoin)
- [LND Docker](https://hub.docker.com/r/lightninglabs/lnd)
- [Taproot Assets Documentation](https://docs.lightning.engineering/the-lightning-network/taproot-assets)