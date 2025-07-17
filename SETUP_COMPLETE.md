# Taproot Assets Stablecoin Setup Status

## ✅ Installation Complete!

All components have been successfully installed and configured:

### 1. **Prerequisites Installed**
- ✅ Go 1.21.5
- ✅ Bitcoin Core v25.0.0
- ✅ LND v0.18.0-beta
- ✅ Taproot Assets v0.5.0-alpha

### 2. **Services Running**
- ✅ Bitcoin Core: Running on testnet (syncing: 99k/4.5M blocks)
- ✅ LND: Running (waiting for wallet creation)
- ⏸️ Taproot Assets: Ready to start after LND wallet creation

### 3. **Configuration Files Created**
- ✅ `~/.bitcoin/bitcoin.conf`
- ✅ `~/.lnd/lnd.conf`
- ✅ `~/.tapd/tapd.conf`

## 🚀 Next Steps

### Step 1: Create LND Wallet (MANUAL STEP REQUIRED)
```bash
export PATH=$PATH:~/go/bin:~/bin
lncli --network=testnet create
```
- Password: `MySuperSecurePassword123!`
- When asked for existing seed: type `n`
- Skip passphrase (press Enter twice)
- **SAVE THE 24-WORD SEED PHRASE!**

### Step 2: Wait for Bitcoin Sync
Monitor sync progress:
```bash
cd ~/taproot-assets-stablecoin
./scripts/check-sync.sh
```

This will take several hours. Bitcoin needs to sync before LND can operate.

### Step 3: Start Taproot Assets
Once Bitcoin and LND are synced:
```bash
export PATH=$PATH:~/go/bin:~/bin
tapd
```

### Step 4: Mint Your Stablecoin
```bash
cd ~/taproot-assets-stablecoin/scripts
./mint-stablecoin.sh
```

### Step 5: Create Lightning Channels
```bash
./create-channels.sh --setup
```

## 📁 Important Files

- **Password**: `~/taproot-assets-stablecoin/wallet-password.txt`
- **Configuration**: `~/taproot-assets-stablecoin/configs/stablecoin-config.json`
- **Scripts**: `~/taproot-assets-stablecoin/scripts/`
  - `check-sync.sh` - Monitor sync status
  - `mint-stablecoin.sh` - Mint your stablecoin
  - `issue-tokens.sh` - Manage token issuance
  - `create-channels.sh` - Lightning channel management
  - `monitor-system.sh` - System monitoring

## 🛠️ Helper Commands

Add to PATH permanently:
```bash
echo 'export PATH=$PATH:~/go/bin:~/bin' >> ~/.bashrc
source ~/.bashrc
```

Check service status:
```bash
ps aux | grep -E "bitcoind|lnd|tapd"
```

View logs:
```bash
tail -f ~/.lnd/lnd.log
tail -f ~/.bitcoin/testnet3/debug.log
```

## ⚠️ Important Notes

1. **Testnet Mode**: Everything is configured for testnet. For mainnet, update network settings in all config files.

2. **Security**: 
   - Change the default password in production
   - Backup your wallet seed phrase
   - Keep your macaroon files secure

3. **Sync Time**: Bitcoin testnet sync can take 6-12 hours depending on your connection.

4. **Ports**:
   - Bitcoin RPC: 18332
   - LND RPC: 10009
   - LND REST: 8080
   - Taproot Assets RPC: 10029
   - Taproot Assets REST: 8089

## 📚 Documentation

- [Taproot Assets Docs](https://docs.lightning.engineering/the-lightning-network/taproot-assets)
- [LND Docs](https://docs.lightning.engineering/)
- [API Reference](https://lightning.engineering/api-docs/api/taproot-assets/)

---

**Status**: Ready for manual wallet creation step!