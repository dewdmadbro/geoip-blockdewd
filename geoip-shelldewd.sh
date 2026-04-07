#!/usr/bin/env bash


usage() {
    echo "Usage: $0 [install|remove|run|removelog|logdrop|update]"
    exit 1
}


install() {
    # check for yq and install if needed
    if command -v yq &> /dev/null; then
        echo "yq is already installed: $(yq --version)"
    else
        echo "yq not found, installing..."
        if command -v apt &> /dev/null; then
            echo "Using apt..."
            apt install -y yq
        elif command -v dnf &> /dev/null; then
            echo "Using dnf..."
            dnf install -y yq
        elif command -v yum &> /dev/null; then
            echo "Using yum..."
            yum install -y yq
        else
            echo "No package manager found, falling back to direct download..."
            wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
            chmod +x /usr/local/bin/yq
        fi
        echo "yq installed: $(yq --version)"
    fi

    # Load variables from config.yaml
    TIMER=$(yq -r '.systemd_timer' config.yaml)

    # check for grepcidr and install if needed
    if command -v grepcidr &> /dev/null; then
        echo "grepcidr is already installed: $(grepcidr 2>&1 | head -1)"
    else
        echo "grepcidr not found, installing..."
        if command -v apt &> /dev/null; then
            echo "Using apt..."
            apt install -y grepcidr
        elif command -v dnf &> /dev/null; then
            echo "Using dnf..."
            dnf install -y grepcidr
        elif command -v yum &> /dev/null; then
            echo "Using yum..."
            yum install -y grepcidr
        else
            echo "No supported package manager found. Please install grepcidr manually." >&2
            exit 1
        fi
    fi

    chmod +x $PWD/geoip-blockdewd.sh

    # make systemd service file
    cat > /etc/systemd/system/geoip-blockdewd.service << EOF
[Unit]
Description=pull lists and run geoip-shell blockist imports every $TIMER hours
[Service]
Type=oneshot
WorkingDirectory=$PWD
ExecStart=$PWD/geoip-shelldewd.sh run
StandardOutput=file:$PWD/geoip-blockdewd.log
[Install]
WantedBy=multi-user.target
EOF
    echo "Service File Created"

    # make systemd timer file
    cat > /etc/systemd/system/geoip-blockdewd.timer << EOF
[Unit]
Description=Timer to run csblock every $TIMER hours
[Timer]
OnUnitActiveSec=$TIMER
Persistent=true
AccuracySec=1us
Unit=geoip-blockdewd.service
[Install]
WantedBy=timers.target
EOF
    echo "Timer File Created"

    # start timer and first run of service
    systemctl daemon-reload
    systemctl enable geoip-blockdewd.timer
    systemctl start geoip-blockdewd.timer
    echo "Service Timer Enabled And Started"
    sleep 1
    echo "Running Service"
    systemctl start geoip-blockdewd
    echo "First run completed. You can check the status with:"
    echo "sudo systemctl status geoip-blockdewd"
    echo "You can view timers and runs with:"
    echo "sudo systemctl list-timers"
    sleep 2
    echo "Install Complete, Bye"
    sleep 1
}


remove() {
    # stop and disable timer and service
    echo "Stopping and disabling geoip-blockdewd timer and service..."
    systemctl stop geoip-blockdewd.timer
    systemctl disable geoip-blockdewd.timer
    systemctl stop geoip-blockdewd.service

    # remove systemd files
    echo "Removing systemd files..."
    rm -f /etc/systemd/system/geoip-blockdewd.service
    rm -f /etc/systemd/system/geoip-blockdewd.timer

    # reload systemd
    systemctl daemon-reload
    systemctl reset-failed

    echo "geoip-blockdewd service and timer removed"
    sleep 1
    
    # optionally remove yq
    read -p "Remove yq? (y/n): " answer
    if [[ "$answer" == "y" ]]; then
        if command -v apt &> /dev/null; then
            apt remove -y yq
        elif command -v dnf &> /dev/null; then
            dnf remove -y yq
        elif command -v yum &> /dev/null; then
            yum remove -y yq
        else
            rm -f /usr/local/bin/yq
        fi
        echo "yq removed"
    else
        echo "yq kept"
    fi

    # optionally remove grepcidr
    read -p "Remove grepcidr? (y/n): " answer
    if [[ "$answer" == "y" ]]; then
        if command -v apt &> /dev/null; then
            apt remove -y grepcidr
        elif command -v dnf &> /dev/null; then
            dnf remove -y grepcidr
        elif command -v yum &> /dev/null; then
            yum remove -y grepcidr
        else
            echo "No supported package manager found. Please remove grepcidr manually." >&2
        fi
        echo "grepcidr removed"
    else
        echo "grepcidr kept"
    fi
    sleep 3
}

removelog() {
    #revert changes to original files
    echo "Restoring original files"
    rm "/usr/lib/geoip-shell/geoip-shell-lib-ipt.sh" 
    rm "/usr/lib/geoip-shell/geoip-shell-lib-common.sh"
    mv "/usr/lib/geoip-shell/geoip-shell-lib-ipt.orig" "/usr/lib/geoip-shell/geoip-shell-lib-ipt.sh"
    mv "/usr/lib/geoip-shell/geoip-shell-lib-common.orig" "/usr/lib/geoip-shell/geoip-shell-lib-common.sh"
    echo "File restoration complete"
    
    #remove mangle changes
    echo "Reverting mangle rules"
    sleep 1
    iptables -t mangle -R GEOIP-SHELL_IN 5 -m set --match-set geoip-shell_local_block_4 src -m comment --comment geoip-shell_local_block_ipv4 -j DROP
    iptables -t mangle -R GEOIP-SHELL_IN 7 -m comment --comment geoip-shell_whitelist_block -j DROP
    ip6tables -t mangle -R GEOIP-SHELL_IN 6 -m comment --comment geoip-shell_whitelist_block -j DROP
    
    #remove GEOIP-DROP chains
    echo "Removing GEOIP-DROP chain"
    iptables -t mangle -F GEOIP-DROP
    iptables -t mangle -X GEOIP-DROP
    ip6tables -t mangle -F GEOIP-DROP
    ip6tables -t mangle -X GEOIP-DROP
}

run() {
    bash "$PWD/geoip-blockdewd.sh"
}

logdrop() {
    #function replaces DROP with GEOIP-DROP so we can log drops
    echo "Backing up files"
    cp "/usr/lib/geoip-shell/geoip-shell-lib-ipt.sh" "/usr/lib/geoip-shell/geoip-shell-lib-ipt.orig"
    cp "/usr/lib/geoip-shell/geoip-shell-lib-common.sh" "/usr/lib/geoip-shell/geoip-shell-lib-common.orig"

    lib-ipt() {
        file="/usr/lib/geoip-shell/geoip-shell-lib-ipt.sh"
        [ -f "$file" ] || { echo "Error: file '$file' not found"; return 1; }
        sed -i 's/-j DROP/-j GEOIP-DROP/g
            s/local_fw_target=DROP/local_fw_target=GEOIP-DROP/g
            s/${blanks}DROP"/${blanks}GEOIP-DROP"/g' "$file"
        echo "Done: replaced DROP with GEOIP-DROP in '$file'"
    }
    
    lib-common() {
        file="/usr/lib/geoip-shell/geoip-shell-lib-common.sh"
        [ -f "$file" ] || { echo "Error: file '$file' not found"; return 1; }
        sed -i 's/ipt_target=DROP/ipt_target=GEOIP-DROP/g; s/nft_verdict=drop/nft_verdict=geoip-drop/g' "$file"
        echo "Done: replaced DROP with GEOIP-DROP in '$file'"
    }

    echo "Updating Files"
    lib-ipt
    lib-common
    
    #add new chain in ipv4 and ipv6
    echo "Updating mangle rules"
    iptables -t mangle -N GEOIP-DROP
    ip6tables -t mangle -N GEOIP-DROP

    #add log and drop rules for both
    iptables -t mangle -A GEOIP-DROP -j LOG --log-prefix "[GEOIP4 DROP] "
    iptables -t mangle -A GEOIP-DROP -j DROP
    ip6tables -t mangle -A GEOIP-DROP -j LOG --log-prefix "[GEOIP6 DROP] "
    ip6tables -t mangle -A GEOIP-DROP -j DROP

    #Replace existing rules to send to GEOIP-DROP Chain
    read -p "Do you already use a blocklist with geoip-shell (y/n): " answer
    if [[ "$answer" == "y" ]]; then
        iptables -t mangle -R GEOIP-SHELL_IN 5 -m set --match-set geoip-shell_local_block_4 src -m comment --comment geoip-shell_local_block_ipv4 -j GEOIP-DROP
    else
        iptables -t mangle -I GEOIP-SHELL_IN 5 -m set --match-set geoip-shell_local_block_4 src -m comment --comment geoip-shell_local_block_ipv4 -j GEOIP-DROP
    fi

    iptables -t mangle -R GEOIP-SHELL_IN 7 -m comment --comment geoip-shell_whitelist_block -j GEOIP-DROP
    ip6tables -t mangle -R GEOIP-SHELL_IN 6 -m comment --comment geoip-shell_whitelist_block -j GEOIP-DROP
}

update() {
    echo "updating....."
    #curl lastest package    
    LOCATION=$(curl -s https://api.github.com/repos/dewdmadbro/geoip-blockdewd/releases/latest \
    | grep "tarball_url" \
    | awk '{ print $2 }' \
    | sed 's/,$//'       \
    | sed 's/"//g' )     \
    ; curl -L -o geoip-blockdewd.tar.gz $LOCATION
    sleep 1

    #extract files overwriting files excluding config
    tar -xvzf geoip-blockdewd.tar.gz --strip-components=1 --exclude="config.yaml"
    rm geoip-blockdewd.tar.gz

    #makes files excutable
    chmod +x geoip-shelldewd.sh
    chmod +x geoip-blockdewd.sh
    echo "complete....."
    sleep 1
}

case "$1" in
    install)     install ;;
    remove)      remove  ;;
    removelog) removelog ;;
    run)         run     ;;
    logdrop)     logdrop ;;
    update)      update  ;;
    *)           usage   ;;
esac