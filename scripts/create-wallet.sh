#!/usr/bin/expect -f

set timeout 30

spawn lncli --network=testnet create

expect "Input wallet password:"
send "MySuperSecurePassword123!\r"

expect "Confirm password:"
send "MySuperSecurePassword123!\r"

expect "Do you have an existing cipher seed mnemonic*"
send "n\r"

expect "Input your passphrase*"
send "\r"

expect "Confirm passphrase:"
send "\r"

expect eof