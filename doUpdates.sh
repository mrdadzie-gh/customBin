#!/bin/bash

# Help function
Help()
{
    echo ""
    echo "doUpdates.sh"
    echo ""
    echo "Applies all available system updates from official repositories."
    echo "Triggers a reboot if the following critical packages are updated:"
    echo ""
    echo "1. kernel"
    echo "2. glibc"
    echo "3. systemd"
    echo ""
    echo "Usage: doUpdates.sh [-c | -h | -l | -r]"
    echo ""
    echo "Options:"
    echo "  -c    Check for available updates and exit."
    echo "  -h    Display this help message and exit."
    echo "  -l    Print the MIT license notification."
    echo "  -r    Reboot automatically if any trigger package is updated."
    echo ""
}

# MIT license notification
mit()
{
	echo ""
	echo "MIT License"
	echo ""
	echo "Copyright (c) 2025 Benjamin Dadzie"
	echo ""
	echo "Permission is hereby granted, free of charge, to any person obtaining a copy"
	echo "of this software and associated documentation files (the "Software"), to deal"
	echo "in the Software without restriction, including without limitation the rights"
	echo "to use, copy, modify, merge, publish, distribute, sublicense, and/or sell"
	echo "copies of the Software, and to permit persons to whom the Software is"
	echo "furnished to do so, subject to the following conditions:"
        echo ""	
	echo "The above copyright notice and this permission notice shall be included in all"
	echo "copies or substantial portions of the Software."
        echo ""
	echo "THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR"
	echo "IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,"
	echo "FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE"
	echo "AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER"
	echo "LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,"
	echo "OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE"
	echo "SOFTWARE."
	echo ""
}

# Initialize variables
check=0
doReboot=0
needsReboot=0
status=0
updatesFile="/tmp/updates.list"

# Ensure only root or user with elevated privileges can run this script
if [[ $EUID -ne 0 ]]
then
	echo "You must be root or have sudo privileges to run this program"
	exit
fi

# Process the input options
while getopts ":chlr" option; do
	case $option in
		c) # Check option
		     check=1;;
		h) # Help function
		     Help
		     exit;;
		l) # Display MIT license
                     mit
		     exit;;
		r) # Reboot option
		     doReboot=1;;
	       \?) # incorrect option
		     echo "Error: Invalid option"
		     exit;;
        esac
done

# Main body of script
dnf check-update > $updatesFile 2>&1
status=$?

case "$status" in
    0)
        echo "Updates are NOT available for host $HOSTNAME at this time."
        ;;
    100)
        echo "Updates ARE available for host $HOSTNAME"
        ;;
    *)
        echo "Error: unexpected exit code ($status) returned by dnf check-update on $HOSTNAME"
        ;;
esac

if [[ $check -eq 1 ]] 
then
	echo "Exiting after update check as requested with -c."
	echo
	exit 0
fi

# Does the update include a new kernel?
if grep ^kernel $updatesFile > /dev/null
then
	needsReboot=1
	echo "Kernel update for $HOSTNAME."
fi

# Alternatively, is there a new glibc?
if grep ^glibc $updatesFile > /dev/null
then
        needsReboot=1
        echo "glibc update for $HOSTNAME."
fi

# Or is there a new systemd update available?
if grep ^systemd $updatesFile > /dev/null
then
        needsReboot=1
        echo "systemd update for $HOSTNAME."
fi

if [[ $needsReboot -eq 1 ]]
then
	echo "A reboot is required for host $HOSTNAME."
fi

# Perform the update
dnf -y update

# Remove cached metadata and packages to save disk space
echo
echo "Removing cached metadata and packages to save disk space."
dnf clean all

# Remove packages that were installed as dependencies but are no longer needed
echo
echo "Removing packages that were installed as dependencies but are no longer required."
dnf -y autoremove

# Rebuild the package metadata cache for faster future operations
echo
echo "Rebuilding the package metadata for faster future operations."
dnf makecache

# Update the man database
echo
echo "Updating the man database."
mandb

# Reboot if neccessary and cleanup
rm -f $updatesFile

if [[ $needsReboot -eq 0 ]]
then
	echo
	echo "No reboot required on host $HOSTNAME."
	echo
elif [[ $doReboot -eq 1 ]] && [[ $needsReboot -eq 1 ]]
then
	echo
	echo "Rebooting host $HOSTNAME."
	reboot
elif [[ $doReboot -eq 0 ]] && [[ $needsReboot -eq 1 ]]
then
	echo
	echo "Reboot required on host $HOSTNAME."
	echo "Please schedule a reboot at your earliest convenience."
	echo
else
	echo
	echo "Unable to determine reboot status on host $HOSTNAME."
	echo "Manual review is recommended."
	echo
fi
