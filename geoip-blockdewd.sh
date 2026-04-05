#!/usr/bin/env bash


#Set variables
RAW_IP="raw.ipls"               # ip lists downloaded information
SORTED_IP="sorted.ipls"         # ip list sorted and duplicates removed
IMPORT="import.ipls"            # ips to be added to block list
CIDRLIST="cidr.ipls"            # cidrs to be blocked
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

# Loop through the URL list and fetch
for url in "${URL_LIST1[@]}"; do
    fetch "$url"
done

for url in "${URL_LIST2[@]}"; do
    fetch2 "$url"
done

#Sorting IPs only 
echo "-----> Removing Duplicates & Sorting"
sort -u "$RAW_IP" | grep -v '^\s*$' | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' > "$SORTED_IP"
sort -u "$RAW_IP" | grep -v '^\s*$' | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$' > "$CIDRLIST"

#Run lookup to only get ips in the whitelist that we want to block
echo "-----> Removing Unecessary IPs"
geoip-shell lookup -F "$SORTED_IP" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' > "$IMPORT"

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
