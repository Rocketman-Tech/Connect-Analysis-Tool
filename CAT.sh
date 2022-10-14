#!/bin/bash

: HEADER = <<'EOL'

██████╗  ██████╗  ██████╗██╗  ██╗███████╗████████╗███╗   ███╗ █████╗ ███╗   ██╗
██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝╚══██╔══╝████╗ ████║██╔══██╗████╗  ██║
██████╔╝██║   ██║██║     █████╔╝ █████╗     ██║   ██╔████╔██║███████║██╔██╗ ██║
██╔══██╗██║   ██║██║     ██╔═██╗ ██╔══╝     ██║   ██║╚██╔╝██║██╔══██║██║╚██╗██║
██║  ██║╚██████╔╝╚██████╗██║  ██╗███████╗   ██║   ██║ ╚═╝ ██║██║  ██║██║ ╚████║
╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝

      Name: Connect Analysis Tool
 Description: Collects local information about Jamf Connect and Uploads summarized information to Jamf Pro
  Parameters: $1-$3 - Reserved by Jamf (Mount Point, Computer Name, Username)
                 $4 - Base64 encoded API credentials

  Created By: Zac Hirschman
     Version: 2.0
     License: Copyright (c) 2022, Rocketman Management LLC. All rights reserved. Distributed under MIT License.
   More Info: For Documentation, Instructions and Latest Version, visit https://www.rocketman.tech/jamf-toolkit

EOL

##
## Parameters and Variables
##

APIHASH=$4 ## Base64 encoded form of "APIUSER:PASSWORD"

##
## System Variables
##

JAMFURL=$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url)
hostName=$( scutil --get LocalHostName )
timeStamp=$( date '+%Y-%m-%d-%H-%M-%S' )
OSMAJOR=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}')
CURRENTUSER=$( /usr/bin/stat -f "%Su" /dev/console )
SERIAL=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
if [[ "$OSMAJOR" -ge 11 ]]; then
  xPathOpt='-e'
fi
jamfProID=$( curl -sk -H "Authorization: Basic ${APIHASH}" -H "Accept: text/xml" ${JAMFURL}/JSSResource/computers/serialnumber/${SERIAL}/subset/general | xpath ${xPathOpt} "//computer/general/id/text()" 2>/dev/null )
LOGMEOW="/var/log/CAT-$SERIAL-$timeStamp.log" ; touch $LOGMEOW

##
## INPUT SECTION
##

# Input Mac information
MacOS_version=$(sw_vers -productVersion)

## Input plists

## Login
if [ -e /Library/Managed\ Preferences/com.jamf.connect.login.plist ]; then
  Login_plist=$(defaults read "/Library/Managed Preferences/com.jamf.connect.login.plist" | sed 's/ =     {/:/' | tr -d "};")
else
  Login_plist="Login plist not found"
fi

## Menubar
if [ -e /Library/Managed\ Preferences/com.jamf.connect.plist ]; then
  Menubar_plist=$(defaults read "/Library/Managed Preferences/com.jamf.connect.plist" | sed 's/ =     {/:/' | tr -d "};")
else
  Menubar_plist="Menubar plist not found"
fi

## Actions
if [ -e /Library/Managed\ Preferences/com.jamf.connect.actions.plist ]; then
  Actions_plist=$(defaults read "/Library/Managed Preferences/com.jamf.connect.actions.plist" | sed 's/ =     {/:/' | tr -d "};")
else
  Actions_plist="No deployed Actions plist"
fi

## Shares
if [ -e /Library/Managed\ Preferences/com.jamf.connect.shares.plist ]; then
  Shares_plist=$(defaults read "/Library/Managed Preferences/com.jamf.connect.shares.plist" | sed 's/ =     {/:/' | tr -d "};")
else
  Shares_plist="No deployed Shares plist"
fi

## State plist
State_plist=$(su "$CURRENTUSER" -c "defaults read com.jamf.connect.state" 2>/dev/null)
if [[ "$State_plist" == "" ]]; then
  State_plist="No user is currently logged in to Menubar"
fi

## Authchanger plist
if [ -e /Library/Managed\ Preferences/com.jamf.connect.authchanger.plist ]; then
  Auth_plist=$(defaults read "/Library/Managed Preferences/com.jamf.connect.authchanger.plist" | sed 's/ =     {/:/' | tr -d "};")
else
  Auth_plist="No deployed Authchanger plist"
fi

## LaunchAgent
if [ -e /Library/LaunchAgents/com.jamf.connect.plist ]; then
  Launch_Agent=$(defaults read /Library/LaunchAgents/com.jamf.connect.plist | sed 's/ =     {/:/' | tr -d "};")
else
  Launch_Agent="No LaunchAgent Detected"
fi

## Input logs
Login_log=$(cat /private/tmp/jamf_login.log /dev/null 2>&1)
Menubar_log=$(log show --style compact --predicate 'subsystem == "com.jamf.connect"' --debug --last 30m)

# Input authchanger
loginwindow_check=$(/usr/local/bin/authchanger -print | grep -c 'loginwindow:login')
echo "$loginwindow_check"

# Input curb rose
kerblist=$(su "$CURRENTUSER" -c "klist 2>&1")
if [[ "$kerblist" == "" ]];then
  kerblist="No tickets"
fi

# Input versions
jamfConnectLoginLocation="/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle"
jamfConnectLoginVersion=$(defaults read "$jamfConnectLoginLocation"/Contents/Info.plist "CFBundleShortVersionString" 2>/dev/null)
jamfConnectLocation="/Applications/Jamf Connect.app"
jamfConnectVersion=$(defaults read "${jamfConnectLocation}/Contents/Info.plist" "CFBundleShortVersionString" 2>/dev/null)

# License Input Section - credit Casey Utke

# Input encoded license files
LicensefromLogin=$(defaults read /Library/Managed\ Preferences/com.jamf.connect.login.plist LicenseFile 2>/dev/null)
LicensefromMenubar=$(defaults read /Library/Managed\ Preferences/com.jamf.connect.plist LicenseFile 2>/dev/null)
if [[ "$LicensefromLogin" == "PD94"* ]]; then
  file=$(echo "$LicensefromLogin" | base64 -d)
elif [[ "$LicensefromMenubar" == "PD94"* ]]; then
  file=$(echo "$LicensefromMenubar" | base64 -d)
else
  file=""
fi

# Grabs and formats data from input file
dat=$(echo "$file" | awk '/ExpirationDate/ {getline;print;exit}' | tr -d '<string>' | tr -d '</string>')
name=$(echo "$file" | awk '/Name/ {getline;print;exit}' | tr -d '<string>' | tr -d '</string>')
num=$(echo "$file" | awk '/NumberOfClients/ {getline;print;exit}' | tr -d '<integer>' | tr -d '</integer>')


###
### OUTPUT SECTION#
###

## Human readable header
echo "=============Begin CAT============================" >> $LOGMEOW

# Versions
echo "MacOS version:                $MacOS_version" >> $LOGMEOW

if [ ! -e $jamfConnectLoginLocation ]; then
  echo "Jamf Connect Login not found" >> $LOGMEOW
else
  echo "Jamf Connect Login version:   $jamfConnectLoginVersion" >> $LOGMEOW
fi

if [ ! -e "$jamfConnectLocation" ]; then
  echo "Jamf Connect Menubar not found" >> $LOGMEOW
else
  echo "Jamf Connect Menubar version: $jamfConnectVersion" >> $LOGMEOW
fi

# Authchanger
if [[ "$loginwindow_check" -eq 0 ]]; then
  echo "authchanger is presenting the Jamf Connect Login Window" >> $LOGMEOW
else
  echo "authchanger is presenting the MacOS Login Window" >> $LOGMEOW
fi

# Outputs account name, expiration date, and number of Jamf Connect licenses if found
echo "====================================================" >> $LOGMEOW
echo "License Information:" >> $LOGMEOW
if [ "$file" != "" ]; then
  echo "        Account:" "$name" >> $LOGMEOW
  echo "Expiration Date:" "$dat" >> $LOGMEOW
  echo "Number of Seats:" "$num" >> $LOGMEOW
else
  echo "License in encoded data block or not found" >> $LOGMEOW
fi

# Output plists
echo "====================================================" >> $LOGMEOW
echo "Full Property Lists:" >> $LOGMEOW
echo "-------------" >> $LOGMEOW
echo "Login Plist" >> $LOGMEOW
echo "$Login_plist" >> $LOGMEOW
echo "-------------" >> $LOGMEOW
echo "Menubar Plist" >> $LOGMEOW
echo "$Menubar_plist" >> $LOGMEOW
echo "-------------" >> $LOGMEOW
echo "State Plist" >> $LOGMEOW
echo "$State_plist" >> $LOGMEOW
echo "-------------" >> $LOGMEOW
echo "Actions Plist" >> $LOGMEOW
echo "$Actions_plist" >> $LOGMEOW
echo "-------------" >> $LOGMEOW
echo "Shares Plist" >> $LOGMEOW
echo "$Shares_plist" >> $LOGMEOW
echo "-------------" >> $LOGMEOW
echo "Authchanger Plist" >> $LOGMEOW
echo "$Auth_plist" >> $LOGMEOW
echo "-------------" >> $LOGMEOW
echo "LaunchAgent:" >> $LOGMEOW
echo "$Launch_Agent" >> $LOGMEOW

# Output klist and krb5.conf files:
echo "Kerberos:" >> $LOGMEOW
echo " $kerblist" >> $LOGMEOW
if [ -e /etc/krb5.conf ]; then
  echo "krb5.conf file in place" >> $LOGMEOW
else
  echo "no krb5.conf file in place" >> $LOGMEOW
fi

# Output logs
echo "====================================================" >> $LOGMEOW
if [ $loginwindow_check!="" ]; then
  echo "Login log from last login:" >> $LOGMEOW
  echo "$login_log" >> $LOGMEOW
fi
echo "-------------" >> $LOGMEOW
echo "Menubar Log (last 30 minutes):" >> $LOGMEOW
echo "$Menubar_log" >> $LOGMEOW
echo "=============CAT complete==========================" >> $LOGMEOW

# Upload LOGMEOW to Jamf Pro
curl -sk -H "Authorization: Basic ${APIHASH}" $JAMFURL/JSSResource/fileuploads/computers/id/$jamfProID -F name=@$LOGMEOW -X POST
