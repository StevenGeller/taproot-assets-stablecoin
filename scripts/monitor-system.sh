#!/bin/bash

CONFIG_FILE="../configs/stablecoin-config.json"
ASSET_ID_FILE="../configs/asset_id.txt"

# Load configuration
ASSET_TICKER=$(jq -r '.asset.ticker' "$CONFIG_FILE")

if [ -f "$ASSET_ID_FILE" ]; then
    ASSET_ID=$(cat "$ASSET_ID_FILE")
fi

# Function to check service status
check_services() {
    echo "=== Service Status ==="
    echo
    
    # Bitcoin Core
    if systemctl is-active --quiet bitcoind; then
        echo "✅ Bitcoin Core: Running"
        BLOCKS=$(bitcoin-cli getblockcount 2>/dev/null || echo "N/A")
        echo "   Block height: $BLOCKS"
    else
        echo "❌ Bitcoin Core: Not running"
    fi
    
    # LND
    if systemctl is-active --quiet lnd; then
        echo "✅ LND: Running"
        if lncli getinfo &> /dev/null; then
            SYNCED=$(lncli getinfo | jq -r '.synced_to_chain')
            echo "   Synced: $SYNCED"
        fi
    else
        echo "❌ LND: Not running"
    fi
    
    # Taproot Assets
    if systemctl is-active --quiet tapd; then
        echo "✅ Taproot Assets: Running"
    else
        echo "❌ Taproot Assets: Not running"
    fi
}

# Function to show asset statistics
show_asset_stats() {
    if [ -z "$ASSET_ID" ]; then
        return
    fi
    
    echo
    echo "=== Asset Statistics ==="
    echo "Asset: $ASSET_TICKER"
    echo "ID: $ASSET_ID"
    echo
    
    # Get balance
    if tapcli assets balance --asset_id "$ASSET_ID" &> /dev/null; then
        BALANCE=$(tapcli assets balance --asset_id "$ASSET_ID" | jq -r '.asset_balances[0].balance')
        echo "Total balance: $BALANCE $ASSET_TICKER"
    fi
    
    # Count transfers
    TRANSFER_COUNT=$(tapcli assets transfers | jq '.transfers | length' 2>/dev/null || echo "0")
    echo "Total transfers: $TRANSFER_COUNT"
}

# Function to show channel statistics
show_channel_stats() {
    echo
    echo "=== Channel Statistics ==="
    
    # Regular Lightning channels
    if lncli listchannels &> /dev/null; then
        LN_CHANNELS=$(lncli listchannels | jq '.channels | length')
        ACTIVE_CHANNELS=$(lncli listchannels | jq '[.channels[] | select(.active == true)] | length')
        echo "Lightning channels: $LN_CHANNELS (Active: $ACTIVE_CHANNELS)"
    fi
    
    # Asset channels
    if tapcli channels list &> /dev/null; then
        ASSET_CHANNELS=$(tapcli channels list | jq '.channels | length' 2>/dev/null || echo "0")
        echo "Asset channels: $ASSET_CHANNELS"
    fi
}

# Function to show recent activity
show_recent_activity() {
    echo
    echo "=== Recent Activity ==="
    
    # Recent transfers
    if [ -f "../backups/transfers_$(date +%Y%m%d).json" ]; then
        echo
        echo "Today's transfers:"
        tail -5 "../backups/transfers_$(date +%Y%m%d).json" | jq '.'
    fi
}

# Function to check disk usage
check_disk_usage() {
    echo
    echo "=== Disk Usage ==="
    
    # Bitcoin Core
    if [ -d ~/.bitcoin ]; then
        BITCOIN_SIZE=$(du -sh ~/.bitcoin 2>/dev/null | cut -f1)
        echo "Bitcoin Core: $BITCOIN_SIZE"
    fi
    
    # LND
    if [ -d ~/.lnd ]; then
        LND_SIZE=$(du -sh ~/.lnd 2>/dev/null | cut -f1)
        echo "LND: $LND_SIZE"
    fi
    
    # Taproot Assets
    if [ -d ~/.tapd ]; then
        TAPD_SIZE=$(du -sh ~/.tapd 2>/dev/null | cut -f1)
        echo "Taproot Assets: $TAPD_SIZE"
    fi
}

# Function to export monitoring data
export_monitoring_data() {
    OUTPUT_FILE="../backups/monitoring_$(date +%Y%m%d_%H%M%S).json"
    
    {
        echo "{"
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"services\": {"
        echo "    \"bitcoind\": $(systemctl is-active --quiet bitcoind && echo "true" || echo "false"),"
        echo "    \"lnd\": $(systemctl is-active --quiet lnd && echo "true" || echo "false"),"
        echo "    \"tapd\": $(systemctl is-active --quiet tapd && echo "true" || echo "false")"
        echo "  },"
        
        if [ -n "$ASSET_ID" ] && tapcli assets balance --asset_id "$ASSET_ID" &> /dev/null; then
            echo "  \"asset\": {"
            echo "    \"id\": \"$ASSET_ID\","
            echo "    \"ticker\": \"$ASSET_TICKER\","
            echo "    \"balance\": $(tapcli assets balance --asset_id "$ASSET_ID" | jq -r '.asset_balances[0].balance')"
            echo "  },"
        fi
        
        echo "  \"channels\": {"
        if lncli listchannels &> /dev/null; then
            echo "    \"lightning\": $(lncli listchannels | jq '.channels | length'),"
        fi
        if tapcli channels list &> /dev/null; then
            echo "    \"assets\": $(tapcli channels list | jq '.channels | length' 2>/dev/null || echo "0")"
        else
            echo "    \"assets\": 0"
        fi
        echo "  }"
        echo "}"
    } > "$OUTPUT_FILE"
    
    echo
    echo "✅ Monitoring data exported to: $OUTPUT_FILE"
}

# Main monitoring loop
main() {
    if [ "$1" == "--watch" ]; then
        # Continuous monitoring
        while true; do
            clear
            echo "=== Taproot Assets Stablecoin Monitor ==="
            echo "$(date)"
            echo
            
            check_services
            show_asset_stats
            show_channel_stats
            check_disk_usage
            
            echo
            echo "Press Ctrl+C to exit..."
            sleep 30
        done
    else
        # Single run
        echo "=== Taproot Assets Stablecoin Monitor ==="
        echo "$(date)"
        echo
        
        check_services
        show_asset_stats
        show_channel_stats
        show_recent_activity
        check_disk_usage
        
        # Ask if user wants to export data
        echo
        read -p "Export monitoring data? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            export_monitoring_data
        fi
    fi
}

# Show usage if --help
if [ "$1" == "--help" ]; then
    echo "Usage: $0 [--watch]"
    echo
    echo "Options:"
    echo "  --watch    Continuous monitoring mode (updates every 30 seconds)"
    echo "  --help     Show this help message"
    exit 0
fi

main "$@"