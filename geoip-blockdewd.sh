#!/usr/bin/env bash


#Set variables
RAW_IP="raw.ipls"               # ip lists downloaded information
SORTED_IP="sorted.ipls"         # ip list sorted and duplicates removed
IMPORT="import.ipls"            # ips to be added to block list
CIDRLIST="cidr.ipls"            # cidrs to be blocked
BLOCKED="blocked.ipls"          # ips blocked by blocklist mode
MODE=$(yq -r '.blocking_mode' config.yaml)
BLOCKLIST="/var/lib/geoip-shell/local_iplists/local_block_ipv4.net"
readarray -t URL_LIST1 < <(yq -r '.fetch_urls1[]' config.yaml)
readarray -t URL_LIST2 < <(yq -r '.fetch_urls2[]' config.yaml)

echo "-----> Working"
echo "--------------------------------------------------"

# download IP's from url list
fetch() {
    local url=$1
    echo "-----> Fetching "
    curl -s "$url" | grep -v '^#' >> "$RAW_IP"
    count1

}

# download IP's from url list
fetch2() {
    local url=$1
    echo "-----> Fetching "
    curl -s "$url" | awk '!/^#/ {print $1}' >> "$RAW_IP"
    count1

}

count1() {
    COUNT=$(wc -l < "$RAW_IP")
    echo "       $COUNT Entries To Process"
}

geoip_mode() {
    # only valid options
    local option_a="whitelist"
    local option_b="blacklist"

    # Check that the variable is not empty
    if [[ -z "$MODE" ]]; then
        echo "[ ERROR ] No blocking mode set. Please set the variable and run again."
        return 1
    fi

    #check options and run correct way to compare
    if [[ "$MODE" == "$option_a" ]]; then
        echo "-----> Checking To Whitelist Mode"
        whitelist_mode
    elif [[ "$MODE" == "$option_b" ]]; then
        echo "-----> Checking To Blocklist Mode"
        blacklist_mode
    else
        echo "[ ERROR ] Blocking mode incorrectly set please fix and run again."
        return 1
    fi
}

whitelist_mode() {
    echo "-----> Removing Unecessary IPs"
    #find ips in the whitelist that we want to block
    geoip-shell lookup -F "$SORTED_IP" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' > "$IMPORT"
}

blacklist_mode() {
    echo "-----> Removing Unecessary IPs"
    #get the ips matching in the blacklist
    geoip-shell lookup -F "$SORTED_IP" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' | > "$BLOCKED"
    #remove matching ips
    grep -xvFf "$BLOCKED" "$SORTED_IP" > "$IMPORT"
}

# Loop through the URL list and fetch
for url in "${URL_LIST1[@]}"; do
    fetch "$url"
done

for url in "${URL_LIST2[@]}"; do
    fetch2 "$url"
done

#Separate IPs and CIDRs so we can check IPs to blocking rules 
echo "-----> Removing Duplicates & Sorting"
sort -u "$RAW_IP" | grep -v '^\s*$' | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' > "$SORTED_IP"
sort -u "$RAW_IP" | grep -v '^\s*$' | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$' > "$CIDRLIST"

#check to geiop-shell mode and ipsets
geoip_mode


cat "$CIDRLIST" >> "$IMPORT"

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

# --- Summary ---
echo ""
echo "-----> Summary"
echo "--------------------------------------------------"
echo "  IPs fetched for input          : $TOTAL"
echo "  IPs already blocked by geoip   : $GEOBLOCK"
echo "  IPs final count to import      : $IMPORTCOUNT"
echo "  IPs final count in blocklist   : $BLOCKCOUNT"
echo "--------------------------------------------------"
echo "-----> Complete"
sleep 3
rm *.ipls
echo "-----> Bye "
sleep 1
