# **GEOIP-BlockDewd**

 Easy and automated blocklist pulling and importing for geoip-shell aimed at reducing entries in ipsets and minimal impact on hardware. Designed to run as a systemd service for a set and forget approach once configured.\
 Or can be used just to add logging to geoip-shell rules. 

 **Disclaimer**
       I only have a Linux mint machine to test on and this is what works for me. I would guess Ubuntu will handle this. I spent a few weeks wokring on this and learning as I go. It may not be the best solution but for my use it has been adequate.

## **Main Features**

 Easy configuration via a simple yaml file\
 Automated blocklist pulling and import every 24 hours(user configurable) if wanted\
 Filters out duplicate entries from pulled lists\
 Checks IP's against geopip-shell's geo blocking lists\
 Can add log & drop rules to existing installs if wanted\

### **Requirements and installation**

 Requires geoip-shell go get it if you dont have it and give this guy some stars -> [GEOIP-SHELL](https://github.com/friendly-bits/geoip-shell?tab=readme-ov-file)
 I couldn't have done this if he didn't already make something awesome and super user friendly.\
 Requires yq & grepcidr which both will be installed if needed during installation\
 Systemd for scheduling and automation\
 Only used with iptables and ipset
 
 To install download via command line

        LOCATION=$(curl -s https://api.github.com/repos/dewdmadbro/geoip-blockdewd/releases/latest \
        | grep "tarball_url" \
        | awk '{ print $2 }' \
        | sed 's/,$//'       \
        | sed 's/"//g' )     \
        ; curl -L -o geoip-blockdewd.tar.gz $LOCATION

 Then extract the files

        tar -xvzf geoip-blockdewd.tar.gz --one-top-level --strip-components=1
        rm geoip-blockdewd.tar.gz

 Read and edit config.yaml replace nano with your editor. You can change the sytemd timer or add more urls

        cd geoip-blockdewd
        nano config.yaml

 Once done with config you will need to make geoip-blockdewd.sh executable and then run install (If you only want to add logging then skip this step)

        chmod +x geoip-shelldewd.sh
        sudo ./geoip-shelldewd.sh install

 During installation it will check for yq & grepcidr and install if needed\
 Also the systemd service and timer will be generated\
 It will map the service to run geoip-blockdewd.sh and generate a log in the extracted folder
 The final thing it will do is run the service for the first time\  

 If you want to add logging then run the following

        sudo ./geoip-shelldewd.sh logdrop

 This will backup and then modify geoip-shell-lib-common & geoip-shell-lib-ipt. After that it will add a new mangle chain GEOIP-DROP for logging and dropping.
 Lastly it will modify the existing rules in GEOIP-SHELL_IN to send traffic we want to drop to GEOIP-DRO. It will log to the kernel log, to watch in realtime run the following

       sudo tail -f /var/log/kern.log

### **Removal and updating**

 **To remove blocklist and timer**
 
        cd geoip-blockdewd
        sudo ./geoip-shelldewd.sh remove

 This will disble the geoip-blockdewd.service and geoip-blockdewd.timer\
 Then it will remove the files and reload the systemd daemon\
 It will also ask if you want to remove yq and grepcidr\

 **To remove logging**

        cd geoip-blockdewd
        sudo ./geoip-shelldewd.sh removelog
 
 This will remove the customisations to geoip-shell-lib-common & geoip-shell-lib-ipt via removal and restoring original files\
 Then it will revert the GEOIP-SHELL_IN rules to the original, flushing GEOIP-DROP chain and lasttly removing GEOIP-DROP chain


 **To update**
 
         cd geoip-blockdewd
        sudo ./geoip-shelldewd.sh update


