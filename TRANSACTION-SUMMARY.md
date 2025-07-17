# USDT Stablecoin Transaction Summary

## System Overview
- **Total USDT Supply**: 1,000,000
- **Asset ID**: `60d399559238fd2f2d563989594bd641e60860384bc35c5c9509f1c8fe28bd3b`
- **Network**: Bitcoin regtest
- **Current Block Height**: 322

## Confirmed Transactions

### Block 313
- **Amount**: 50 USDT (test transaction)
- **TX**: `398ba7dfe2ac166bee2b09429fd67843e433d19395fb4ce1ce353c44bf99c000`

### Block 314
- **Amount**: 200 USDT to Alice
- **TX**: `1e3dbc0dab77a1b2fabbe970d78061647050041a3a540700ff0569ff2369dcbe`

### Block 315
- **Amount**: 150 USDT to Bob
- **TX**: `3e3f3bdbc3615ce3dc817786eb2f1b3b101c808401befec00cb5ee935ff66b2c`

### Block 316
- **Amount**: 50 USDT (test)
- **TX**: `43e43a34961454696e7c4fbe48a76d1bb9805bd8e658e4e3065f733b7784f25e`

### Block 317
- **Amount**: 200 USDT to Alice
- **TX**: `86c95413b0b797594efcd86a04ff722a935da1acb6a80fbc05de803a8587994c`

### Block 318
- **Amount**: 150 USDT to Bob
- **TX**: `db82a05d4ffb021b03411d4adcbe84818ed72abe68e219626ffe87f3f6e11d40`

### Block 319
- **Amount**: 200 USDT to Alice
- **TX**: `fa53e836ab9e39ed129814a382a2353024e9736c50568219469d38a9959f324e`

### Block 320
- **Amount**: 150 USDT to Bob
- **TX**: `670416985f75ab98e51997b8998c6133e5eecac2ea7d89f2bb9c0f487a2c115d`

### Block 321
- **Amount**: 100 USDT (demo)
- **TX**: `b6e9efb31bb24dad39bf39ad4db21bb3efe9`

## Summary Statistics
- **Total Transfers**: 9
- **Total USDT Moved**: 1,350 USDT
- **Alice Total Received**: 600 USDT
- **Bob Total Received**: 450 USDT
- **Test Transactions**: 250 USDT

## How to Use

### View All Transactions
```bash
./show-transfers.sh
```

### Cash App Interface
```bash
./cashapp-style-wallet.sh
```

### Create New Transfer
```bash
./simple-transfer-demo.sh
```

## Technical Notes
- All transactions use Taproot Assets protocol
- Each transfer creates two outputs: recipient amount + change (UTXO model)
- Total supply remains constant at 1,000,000 USDT
- All transactions are confirmed on Bitcoin blockchain