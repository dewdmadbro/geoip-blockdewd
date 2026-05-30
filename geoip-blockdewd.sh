#!/usr/bin/env bash

set -euo pipefail

# needed for cron
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

# Helpers
die()  { echo "❌  $*" >&2; exit 1; }
info() { echo "ℹ️   $*"; }
ok()   { echo "✅  $*"; }

# Cleanup function to remove temp files on exit (success, error, or interrupt)
cleanup() {
    rm -f *.ipls
    echo "Temporary files cleaned up."
}
trap cleanup EXIT

#Set variables
RAW_IP="raw.ipls"               # ip lists downloaded information
SORTED_IP="sorted.ipls"         # ip list sorted and duplicates removed
IMPORT="import.ipls"            # ips to be added to block list
BLOCKED="blocked.ipls"          # ips blocked by blocklist mode
GSIP="gsip.ipls"                # ips not blocked bt geoip-shell
ALLOWLIST=$(yq -r '.allowlist' config.yaml)
MODE=$(yq -r '.blocking_mode' config.yaml)
BLOCKLIST="/var/lib/geoip-shell/local_iplists/local_block_ipv4.net"
readarray -t URL_LIST1 < <(yq -r '.fetch_urls1[]' config.yaml)

# reserved ranges safety net
cat > reserved.ipls << 'EOF'
0.0.0.0/8
224.0.0.0/3
EOF

RESERVED="reserved.ipls"

# reserved ranges safety net
cat > reserved.ipls << 'EOF'
0.0.0.0/8
224.0.0.0/3
EOF

RESERVED="reserved.ipls"

ok "-----> Working"
echo "--------------------------------------------------"
touch "$BLOCKLIST"

############### FUNCTIONS
# download IP's from url list
fetch() {
    local url=$1
    curl -s "$url" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?' >> "$RAW_IP"
    count1
}

count1() {
    COUNT=$(wc -l < "$RAW_IP")
    echo "      $COUNT Entries To Process"
}

geoip_mode() {
    # only valid options
    local option_a="whitelist"
    local option_b="blacklist"

    # Check that the variable is not empty
    if [[ -z "$MODE" ]]; then
        die "[ ERROR ] No blocking mode set. Please set the variable and run again."
    fi

    #check options and run correct way to compare
    if [[ "$MODE" == "$option_a" ]]; then
        info "-----> Checking To Whitelist Mode"
        whitelist_mode
    elif [[ "$MODE" == "$option_b" ]]; then
        info "-----> Checking To Blocklist Mode"
        blacklist_mode
    else
        die "[ ERROR ] Blocking mode incorrectly set please fix and run again."
    fi
}

whitelist_mode() {
    info "-----> Removing Unecessary IPs"
    #find ips in the whitelist that we want to block
    geoip-shell lookup -F "$SORTED_IP" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' > "$GSIP"
}

blacklist_mode() {
    info "-----> Removing Unecessary IPs"
    #get the ips matching in the blacklist
    geoip-shell lookup -F "$SORTED_IP" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' > "$BLOCKED"
    #remove matching ips
    grep -xvFf "$BLOCKED" "$SORTED_IP" > "$GSIP"
}

import_list() {
    if [[ ! -f "$ALLOWLIST" ]]; then
        echo "      Allowlist Not Found"
        echo "     Creating Import File"
        iprange "$GSIP" --except "$RESERVED" > "$IMPORT"
    else
        echo "      Allowlist Found"
        echo "      Creating Import File"
        iprange "$GSIP" --except "$RESERVED" "$ALLOWLIST" > "$IMPORT"
    fi
}

############### WORK
# Loop through the URL list and fetch
info "-----> Fetching"
for url in "${URL_LIST1[@]}"; do
    fetch "$url"
done

#Separate into single IP list so we can check IPs to blocking rules 
info "-----> Removing Duplicates & Sorting"
iprange --print-single-ips / -1 "$RAW_IP" > "$SORTED_IP"
#check to geiop-shell mode and ipsets
geoip_mode

#check for allowlist then combine and reduce
ok "-----> Processing Import"
import_list

#run import
geoip-shell import -B "$IMPORT" > /dev/null 2>&1

#counts for stats
TOTAL=$(wc -l < "$SORTED_IP")
IMPORTCOUNT=$(wc -l < "$IMPORT")
GEOBLOCK=$(( TOTAL - IMPORTCOUNT ))
BLOCKCOUNT=$(wc -l < "$BLOCKLIST")

echo "--------------------------------------------------"
echo ""
echo ""

############### SUMMARY
ok "-----> Summary"
echo "--------------------------------------------------"
echo "  IPs fetched for input          : $TOTAL"
echo "  IPs already blocked by geoip   : $GEOBLOCK"
echo "  IPs final count to import      : $IMPORTCOUNT"
echo "  IPs final count in blocklist   : $BLOCKCOUNT"
echo "--------------------------------------------------"
ok "-----> Complete"
ok "-----> Bye "
sleep 1
