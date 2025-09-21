#!/bin/bash

# Configuration
hostList="/usr/local/etc/doit.conf"
identityFile="/home/athena/.ssh/id_rsa"
remoteUser="athena"
remoteUpdateScript="/usr/local/bin/doUpdates.sh"
logFile="/var/log/doRemoteUpdates.log"

# Logging function
logMsg() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%F %T')"
    echo "[$timestamp] [$level] $message" >> "$logFile"
}

# Header for this run
logMsg "INFO" "===== Starting remote update run ====="

# Loop through each host
exec 3< "$hostList"
while IFS= read -r -u 3 host || [[ -n "$host" ]]; do
    logMsg "INFO" "Connecting to $host..."
    
    ssh -i "$identityFile" \
	-o BatchMode=yes \
	-o ConnectTimeout=15 \
	-o ServerAliveInterval=15 \
	-o ServerAliveCountMax=2 \
	-o StrictHostKeyChecking=no \
	"$remoteUser@$host" \
	"if [[ -x $remoteUpdateScript ]]; then \
	     sudo /bin/bash -l -c '$remoteUpdateScript'; \
	 else \
	     echo 'Missing script'; exit 127; \
	 fi"
	    
    status=$?
    
    if [[ $status -eq 0 ]]; then
        logMsg "SUCCESS" "Updates applied successfully on $host"
    elif [[ $status -eq 127 ]]; then
        logMsg "ERROR" "Update script not found on $host"
    else
        logMsg "ERROR" "Failed to run update script on $host (exit code: $status)"
    fi

done

logMsg "INFO" "===== Update run complete ====="
