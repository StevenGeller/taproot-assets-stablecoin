#!/usr/bin/env python3
import subprocess
import time
import os

os.environ['PATH'] = os.environ.get('PATH', '') + ':' + os.path.expanduser('~/go/bin') + ':' + os.path.expanduser('~/bin')

# Create wallet using gRPC/REST API instead of CLI
print("Creating LND wallet via API...")

# First, let's generate the wallet initialization request
wallet_password = "MySuperSecurePassword123!"

# Create initialization request
import json
import base64

# Convert password to base64
wallet_password_b64 = base64.b64encode(wallet_password.encode()).decode()

# Create the request
init_request = {
    "wallet_password": wallet_password_b64,
    "cipher_seed_mnemonic": [],
    "aezeed_passphrase": "",
    "recovery_window": 0,
    "channel_backups": None,
    "stateless_init": False
}

# Make the REST API call to create wallet
import urllib.request
import urllib.error
import ssl

# Disable SSL verification for local connection
ssl_context = ssl.create_default_context()
ssl_context.check_hostname = False
ssl_context.verify_mode = ssl.CERT_NONE

try:
    # Try to initialize wallet via REST API
    url = "https://localhost:8080/v1/initwallet"
    data = json.dumps(init_request).encode('utf-8')
    headers = {'Content-Type': 'application/json'}
    
    req = urllib.request.Request(url, data=data, headers=headers)
    
    print("Attempting to create wallet...")
    response = urllib.request.urlopen(req, context=ssl_context)
    result = json.loads(response.read().decode())
    
    print("✅ Wallet created successfully!")
    print("\n⚠️  IMPORTANT: Save this seed phrase securely!")
    print("=" * 50)
    if 'cipher_seed_mnemonic' in result:
        for i, word in enumerate(result['cipher_seed_mnemonic'], 1):
            print(f"{i:2d}. {word}")
    print("=" * 50)
    
    # Save seed to file
    with open('/home/steven/taproot-assets-stablecoin/wallet-seed-backup.txt', 'w') as f:
        f.write("LND WALLET SEED PHRASE\n")
        f.write("=" * 50 + "\n")
        f.write("Generated: " + time.strftime("%Y-%m-%d %H:%M:%S") + "\n")
        f.write("Network: testnet\n")
        f.write("=" * 50 + "\n\n")
        if 'cipher_seed_mnemonic' in result:
            for i, word in enumerate(result['cipher_seed_mnemonic'], 1):
                f.write(f"{i:2d}. {word}\n")
        f.write("\n" + "=" * 50 + "\n")
        f.write("KEEP THIS SAFE! This is your wallet backup.\n")
    
    print(f"\n✅ Seed phrase backed up to: ~/taproot-assets-stablecoin/wallet-seed-backup.txt")
    
except urllib.error.HTTPError as e:
    error_body = e.read().decode()
    print(f"HTTP Error {e.code}: {error_body}")
    print("\nTrying alternative method...")
    
    # Alternative: Use lncli with subprocess
    import pexpect
    
    try:
        print("Using interactive wallet creation...")
        
        # Start the wallet creation process
        child = pexpect.spawn('lncli --network=testnet create', encoding='utf-8')
        child.logfile = open('/home/steven/taproot-assets-stablecoin/wallet-creation.log', 'w')
        
        # Wait for password prompt
        child.expect('Input wallet password:', timeout=10)
        child.sendline(wallet_password)
        
        # Confirm password
        child.expect('Confirm password:', timeout=10)
        child.sendline(wallet_password)
        
        # No existing seed
        child.expect('Do you have an existing cipher seed', timeout=10)
        child.sendline('n')
        
        # No passphrase
        child.expect('Input your passphrase', timeout=10)
        child.sendline('')
        
        # Confirm no passphrase
        child.expect('Confirm passphrase:', timeout=10)
        child.sendline('')
        
        # Capture the output
        child.expect(pexpect.EOF, timeout=30)
        output = child.before
        
        print("✅ Wallet created successfully!")
        print(output)
        
        # Save output
        with open('/home/steven/taproot-assets-stablecoin/wallet-seed-backup.txt', 'w') as f:
            f.write(output)
            
    except Exception as e:
        print(f"Alternative method failed: {e}")
        print("\nPlease create wallet manually with:")
        print("lncli --network=testnet create")
        
except Exception as e:
    print(f"Error: {e}")
    print("\nPlease create wallet manually with:")
    print("lncli --network=testnet create")