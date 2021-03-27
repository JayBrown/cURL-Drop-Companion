#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2001
# shellcheck disable=SC2002
# shellcheck disable=SC2009
# shellcheck disable=SC2162

# cURL Drop Companion (cdc)
# v1.0
# macOS
#
# Copyright (c) 2021 Joss Brown (pseud.)
# License: MIT / place of jurisdiction: Berlin, Germany / German laws apply
#
# Companion script to curldrop (Platypus application)
#
# Requisites:
# curldrop: https://github.com/kennell/curldrop (install with pip3)
# detox: http://detox.sourceforge.net/ (install e.g. with Homebrew)
# imagemagick: https://www.imagemagick.org/ (install e.g. with Homebrew)
# miniupnpc: https://miniupnp.tuxfamily.org/ (install e.g. with Homebrew)
# python3 (install e.g. with Xcode or Homebrew etc.)
# qrencode: https://fukuchi.org/works/qrencode/index.html.en (install e.g. with Homebrew)
#
# Optional dependencies:
# sendEmail: https://github.com/mogaal/sendemail (install e.g. with Homebrew)
# terminal-share: https://github.com/mattt/terminal-share (install with gem)

export LANG=en_US.UTF-8
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/local/bin:/opt/homebrew/bin:/opt/sw/bin
export SYSTEM_VERSION_COMPAT=0

process="cdc"
uiprocess="cURL Drop Companion"
procid="local.lcars.cURLDropCompanion"
skid="D1CC1414E11480527EECC3D3C944F8BFB1931574"
version="1.0"
logloc="/tmp/$procid.log"
histloc="/var/tmp/$procid.hist" # use system's persistent temp location for history file

# logging
currentdate=$(date)
if ! [[ -f $logloc ]] ; then
	echo "++++++++ $currentdate ++++++++" > "$logloc"
else
	echo -e "\n++++++++ $currentdate ++++++++" >> "$logloc"
fi
exec > >(tee -a "$logloc") 2>&1
echo -e "$uiprocess ($procid)\n$process v$version"

# function: system error beep
_sysbeep () {
	osascript -e 'beep' -e 'delay 0.5' &>/dev/null
}

# user stuff
accountnames=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/{print $3}')
if ! [[ $accountnames ]] ; then
	accountname="$LOGNAME"
	if ! [[ $accountname ]] ; then
		accountname="$USER"
		if [[ $accountname ]] ; then
			HOMEDIR=$(dscl . read /Users/"$accountname" NFSHomeDirectory 2>/dev/null | awk -F": " '{print $2}')
			if ! [[ $HOMEDIR ]] || ! [[ -d "$HOMEDIR" ]] ; then
				if [[ -d "/Users/$accountname" ]] ; then
					HOMEDIR="/Users/$accountname"
				else
					HOMEDIR=$(eval echo "~$accountname" 2>/dev/null)
				fi
			fi
		fi
	fi
else
	while read -r accountname
	do
		! [[ $accountname ]] && continue
		HOMEDIR=$(dscl . read /Users/"$accountname" NFSHomeDirectory 2>/dev/null | awk -F": " '{print $2}')
		if [[ $HOMEDIR ]] && [[ -d "$HOMEDIR" ]] ; then
			break
		else
			if [[ -d "/Users/$accountname" ]] ; then
				HOMEDIR="/Users/$accountname"
				break
			else
				HOMEDIR=$(eval echo "~$accountname" 2>/dev/null)
				if [[ $HOMEDIR ]] && [[ -d "$HOMEDIR" ]] ; then
					break
				fi
			fi
		fi
	done < <(echo "$accountnames")
fi
if ! [[ $accountname ]] ; then
	accountname=$(id -un 2>/dev/null)
fi
auser=$(id -u "$accountname" 2>/dev/null)
if ! [[ $HOMEDIR ]] || ! [[ -d "$HOMEDIR" ]] ; then
	if [[ $accountname ]] && [[ -d "/Users/$accountname" ]] ; then
		HOMEDIR="/Users/$accountname"
	else 
		HOMEDIR=~
		if ! [[ -d "$HOMEDIR" ]] ; then
			HOMEDIR="$HOME"
			if ! [[ -d "$HOMEDIR" ]] ; then
				echo "ERROR[01]: $uiprocess ($process) could not detect a proper home directory for the currently logged-in user! Exiting..."
				_sysbeep &
				osascript &>/dev/null << EOT
tell application "cURL Drop Companion"
	display alert "Internal error [01]: missing home directory" message "$uiprocess ($process) could not detect a proper home directory for the currently logged-in user." as informational buttons {"Quit"} default button "Quit" giving up after 180
end tell
EOT
				printf "QUITAPP\n"
				exit
			fi
		fi
	fi
fi
euser=$(id -un)
account=$(id -u)

# extended path
export PATH=$PATH:"$HOMEDIR"/.local/bin:"$HOMEDIR"/bin:"$HOMEDIR"/local/bin

# check Platypus locations
mypath="$0" # should be */cURL Drop Companion.app/Contents/Resources/script
mypath_short="${mypath/#$HOMEDIR/~}"
resources=$(dirname "$mypath") # Resources (in Contents)
resbase=$(basename "$resources")
icon_loc="$resources/cdc.png"
contents=$(dirname "$resources") # Contents
helpers="$contents/Helpers" # Helpers (in Contents)
tn_loc="$helpers/cURL Drop Companion Notifier.app"
exeloc="$contents/MacOS/cURL Drop Companion"
approot=$(dirname "$contents") # path to cURL Drop Companion.app
appname=$(basename "$approot") # cURL Drop Companion.app

# Platypus command to quit GUI app
_quit-app () {
	quitapp=$(osascript 2>/dev/null << EOI
tell application "cURL Drop Companion"
	set theButton to button returned of (display alert ¬
		"Please do not stop the server before the shared files have been downloaded from your Mac." ¬
		buttons {"OK"} ¬
		as warning ¬
		message "You can stop the curldrop sharing server by launching cURL Drop Companion without input and selecting 'Clear Server' from the startup options.")
end tell
EOI
	)
	! [[ $quitapp ]] && quitapp="timeout"
	echo "Quit: $quitapp"
	printf "QUITAPP\n"
	exit
}

_quit-direct () {
	echo "Quit: direct"
	printf "QUITAPP\n"
	exit
}

# function: other beep
_beep () {
	afplay "$resources/beep.aif" &>/dev/null
}

# function: success sound
_success () {
	afplay "$resources/success.aif" &>/dev/null
}

# warning dialog function
_syswarning () {
	_sysbeep &
	if ! [[ $3 ]] ; then
		osascript &>/dev/null << EOT
tell application "cURL Drop Companion"
	display alert "$1" message "$2" as critical buttons {"Quit"} default button "Quit" giving up after 180
end tell
EOT
	else
		launchctl asuser "$auser" osascript &>/dev/null << EOR
display alert "$1" message "$2" as critical buttons {"Quit"} default button "Quit" giving up after 180
EOR
	fi
	_quit-direct
}

# check macOS version
prodv=$(sw_vers -productVersion)
prodv_major=$(echo "$prodv" | awk -F. '{print $1}')
prodv_minor=$(echo "$prodv" | awk -F. '{print $2}')
if [[ $prodv_major == 10 ]] && [[ $prodv_minor -ge 16 ]] ; then
	prodv_major=11
	prodv_minor=$(echo "$prodv_minor - 16" | bc)
fi

# check runtime/GUI/bundle context
if [[ $resbase != "Resources" ]] ; then
	echo "ERROR[02]: $uiprocess ($process) is not running from its regular location! Exiting..."
	_sysbeep &
	_syswarning \
		"Internal error [02]: not nested in a Resources directory" \
		"$uiprocess ($process) is not running from its regular location and will exit."
else
	unsupported=false
	if [[ $prodv_major -eq 10 ]] && [[ $prodv_minor -le 10 ]] ; then # macOS 10.10 or earlier
		if [[ $prodv_minor -lt 10 ]] ; then # macOS 10.9 or earlier
			unsupported=true
		else # macOS 10.10
			prodv_fix=$(echo "$prodv" | awk -F. '{print $3}')
			[[ $prodv_fix -lt 5 ]] && unsupported=true # macOS 10.10.4 or earlier
		fi
	fi
	if $unsupported	; then
		echo "ERROR[03]: $uiprocess ($process) needs at least OS X 10.10.5 (Yosemite)! Exiting..."
		_syswarning \
			"Internal error [03]: unsupported OS" \
			"$uiprocess ($process) needs at least OS X 10.10.5 (Yosemite) for Notification Center support."
	fi
fi
if [[ $euser == "root" ]] ; then
	if [[ $accountname != "root" ]] ; then
		echo "ERROR[04]: please do not execute $uiprocess ($process) as root! Exiting..."
		_syswarning "Internal error [04]: code execution" "Please do not execute $uiprocess ($process) as root!" "root"
	fi
fi
echo "Execution path: $mypath_short"
if echo "$mypath" | grep -q "/AppTranslocation/" &>/dev/null ; then
	echo "ERROR[05]: application $uiprocess ($process) has been translocated"
	_syswarning "Internal error [05]: AppTranslocation" "Please quit $uiprocess ($process), dequarantine the app, and try again!"
fi
if [[ $appname != "cURL Drop Companion.app" ]] || ! [[ -f "$exeloc" ]] || ! [[ -f "$icon_loc" ]] || ! [[ -d "$tn_loc" ]] ; then
	echo "ERROR[06]: $uiprocess ($process) is running from a modified bundle! Exiting..."
		_syswarning \
			"Internal error [06]: bundle" \
			"$uiprocess ($process) is running from a modified bundle and will exit."
fi

if ! codesign --verify --deep --verbose=1 "$approot" 2>&1 | grep -q "valid on disk$" &>/dev/null ; then
	echo "ERROR[07]: $uiprocess ($process) is running from a modified bundle! Please re-install the app! Exiting..."
		_syswarning \
			"Internal error [07]: bundle signature" \
			"$uiprocess ($process) is running from a modified bundle and will exit. Please re-install the app!"
fi
crtsdir="/tmp/cdc_crts"
rm -rf "$crtsdir" 2>/dev/null
mkdir "$crtsdir" 2>/dev/null
WORKDIR="$PWD"
cd "$crtsdir" || return
codesign -dv --extract-certificates "$approot" &>/dev/null
cskid=$(openssl x509 -in "$crtsdir/codesign0" -inform DER -noout -text -fingerprint 2>/dev/null | grep -A1 "Subject Key Identifier" | tail -1 | xargs | sed 's/://g')
cd "$WORKDIR" || return
rm -rf "$crtsdir" 2>/dev/null
if [[ $cskid != "$skid" ]] ; then
	echo "ERROR[08]: $uiprocess ($process) is running from a modified bundle! Please re-install the app! Exiting..."
		_syswarning \
			"Internal error [08]: bundle signature" \
			"$uiprocess ($process) is running from a modified bundle and will exit. Please re-install the app!"
fi
if ! ps aux | grep "cURL Drop Companion.app/Contents/MacOS/cURL Drop Companion" | grep -v "grep" &>/dev/null ; then
	echo "ERROR[09]: $uiprocess ($process) is not running as a GUI process! Exiting..."
	_syswarning \
		"Internal error [09]: runtime" \
		"$uiprocess ($process) is not running as a GUI process and will exit."
fi

# notify function
_notify () {
	"$tn_loc/Contents/MacOS/cURL Drop Companion Notifier" \
		-title "$process [$account]" \
		-subtitle "$1" \
		-message "$2" \
		-appIcon "$icon_loc" \
		>/dev/null
}

# check requisites
read -d '' requisites <<'EOR'
convert
curldrop
detox
external-ip
python3
qrencode
upnpc
EOR
reqerror=false
missinglist=""
while read -r requisite
do
	if ! command -v "$requisite" &>/dev/null ; then
		echo "MISSING: $requisite"
		reqerror=true
		missinglist="$missinglist\n$requisite"
	else
		echo "OK: $requisite"
	fi
done < <(echo "$requisites")
if $reqerror ; then
	missinglist=$(echo -e "$missinglist" | grep -v "^$")
	echo "ERROR[10]: $uiprocess ($process) is missing requisites. Exiting..."
	_sysbeep &
	osascript << EOW
tell application "cURL Drop Companion"
	display alert "Internal error [11]: requisites missing" as warning message "Please install the following requisites first:" & return & return & "$missinglist" buttons {"Quit"} default button "Quit" giving up after 180
end tell
EOW
	_quit-direct
	
	
	_syswarning \
		"" \
		""
fi

# search for optional dependency: sendEmail
if ! command -v sendEmail &>/dev/null ; then
	echo "NOTE: sendEmail not found"
	smail=false
else
	echo "OK: sendEmail"
	smail=true
fi

# search for optional dependency: terminal-share
if ! command -v terminal-share &>/dev/null ; then
	tshare=false
	echo "NOTE: terminal-share not found"
else
	tshare=true
	echo "OK: terminal-share"
fi

# math function: round file size
_round () {
	echo $(printf %.$2f $(echo "scale=$2;(((10^$2)*$1)+0.5)/(10^$2)" | bc))
}

# sub-function: configure CDC (port, share folder etc.)
_cdc-setup () {	
	# local sharing port (default: 8000)
	currentport=$(defaults read "$procid" localSharingPort 2>/dev/null)
	if ! [[ $currentport ]] ; then
		currentport="8000"
		defaults write "$procid" localSharingPort -integer "$currentport" 2>/dev/null
	fi
	while true
	do
		port=$(osascript 2>/dev/null << EOM
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theWANPort to text returned of (display dialog "Please enter the LAN port for local network access to files shared with $uiprocess on your Mac." ¬
		default answer "$currentport" ¬
		buttons {"Cancel", "Enter"} ¬
		default button 2 ¬
		cancel button "Cancel" ¬
		with title "$uiprocess" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOM
		)
		if ! [[ $port ]] || [[ $port == "false" ]] ; then
			port="8000"
			break
		fi
		if [[ $(echo "$port" | sed 's/[0-9]*//g') ]] ; then
			_sysbeep &
			_notify "⚠️ Input error" "Please use integers only"
		else
			break
		fi
	done
	if [[ $port != "$currentport" ]] ; then
		defaults write "$procid" localSharingPort -integer "$port" 2>/dev/null
	fi
	
	# remote sharing port (default: 4747)
	currentwport=$(defaults read "$procid" remoteSharingPort 2>/dev/null)
	if ! [[ $currentwport ]] ; then
		currentwport="4747"
		defaults write "$procid" remoteSharingPort -integer "$currentwport" 2>/dev/null
	fi
	while true
	do
		wport=$(osascript 2>/dev/null << EOM
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theWANPort to text returned of (display dialog "Please enter the WAN port for remote access to files shared with $uiprocess on your Mac." ¬
		default answer "$currentwport" ¬
		buttons {"Cancel", "Enter"} ¬
		default button 2 ¬
		cancel button "Cancel" ¬
		with title "$uiprocess" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOM
		)
		if ! [[ $wport ]] || [[ $wport == "false" ]] ; then
			wport="4747"
			break
		fi
		if [[ $(echo "$wport" | sed 's/[0-9]*//g') ]] ; then
			_sysbeep &
			_notify "⚠️ Input error" "Please use integers only"
		else
			break
		fi
	done
	if [[ $wport != "$currentwport" ]] ; then
		defaults write "$procid" remoteSharingPort -integer "$wport" 2>/dev/null
	fi
	
	# select curldrop sharing directory
	selectsharedir=$(defaults read "$procid" curldropDirectory 2>/dev/null)
	if ! [[ $selectsharedir ]] ; then
		if [[ -d "$SHOME/Sites" ]] ; then
			selectsharedir="$HOMEDIR/Sites"
		else
			selectsharedir="$HOMEDIR"
		fi
		defaults write "$procid" curldropDirectory "$selectsharedir" 2>/dev/null
	fi
	cdsdir=$(osascript 2>/dev/null << EOS
tell application "System Events"
	activate
	set theDefaultPath to "$selectsharedir" as string
	set theShareFolder to POSIX path of (choose folder with prompt ¬
		"Please select the folder to use as cURL Drop's default sharing location…" ¬
		default location theDefaultPath)
end tell
EOS
	)
	if ! [[ $cdsdir ]] || [[ $cdsdir == "false" ]] ; then
		cdsdir="$HOMEDIR/Sites/curldrop"
	fi
	! [[ -d $cdsdir ]] && mkdir -p "$cdsdir" 2>/dev/null
	if [[ $cdsdir != "$selectsharedir" ]] ; then
		defaults write "$procid" curldropDirectory "$cdsdir" 2>/dev/null
	fi
	
	# dynamic DNS domain (optional)
	currentddns_domain=$(defaults read "$procid" dynamicDNSDomain 2>/dev/null)
	ddns_domain=$(osascript 2>/dev/null << EOM
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theDDNSDomain to text returned of (display dialog "Please enter the dynamic or static domain name of your Mac or your AP/router. Leave blank if you do not have one." ¬
		default answer "$currentddns_domain" ¬
		buttons {"Cancel", "Enter"} ¬
		default button 2 ¬
		cancel button "Cancel" ¬
		with title "$uiprocess" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOM
	)
	if ! [[ $ddns_domain ]] || [[ $ddns_domain == "false" ]] ; then
		defaults write "$procid" dynamicDNSDomain "" 2>/dev/null
		return
	else
		if ! echo "$ddns_domain" | grep -q -e "^http://" -e "^https://" &>/dev/null ; then
			ddns_domain="http://$ddns_domain"
		else
			ddns_domain=$(echo "$ddns_domain" | sed "s-^https://-http://-")
		fi
		if [[ $ddns_domain != "$currentddns_domain" ]] ; then
			defaults write "$procid" dynamicDNSDomain "$ddns_domain" 2>/dev/null
		fi
	fi
	
	# ask for MAC restriction (home network etc.)
	if ! [[ $arp_raw ]] ; then
		if [[ $apip ]] ; then
			arp_raw=$(arp "$apip" 2>/dev/null)
		else
			arp_raw=$(arp -a 2>/dev/null | head -1)
		fi
	fi
	macaddr=$(echo "$arp_raw" | awk -F")" '{print $NF}' | sed -e "s/^ at //" -e "s/ on .*//" | xargs)
	if ! [[ $macaddr ]] ; then
		defaults write "$procid" APMAC "" 2>/dev/null
		return
	fi
	routestat=$(route get 0.0.0.0 2>&1)
	gateway=$(echo "$routestat" | awk '/gateway:/ {print $2}')
	if ! [[ $gateway ]] ; then
		gateway=$(echo "$arp_raw" | awk -F"[)(]" '{print $1}' | xargs)
		! [[ $gateway ]] && gateway="-"
	fi
	if [[ $apip ]] ; then
		apip=$(echo "$arp_raw" | awk -F"[)(]" '{print $2}')
	fi
	if ! [[ $apip ]] ; then
		apip="-"
		netbios="-"
	else
		netbios=$(smbutil status -e "$apip" 2>/dev/null | awk -F": " '/^Server:/{print $2}')
		! [[ $netbios ]] && netbios="-"
	fi
	homechoice=$(osascript 2>/dev/null << EOH
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theHomeSetup to button returned of (display dialog "Dynamic DNS domains are usually restricted to a single network router/AP. Do you you want to restrict '$ddns_domain' to the router/AP you are currently connected to? This is recommended." & return & return & "MAC: $macaddr" & return & "Gateway: $gateway ($apip)" & return & "NetBIOS name: $netbios" ¬
		buttons {"No", "Yes"} ¬
		default button 2 ¬
		cancel button "No" ¬
		with title "$uiprocess" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOH
	)
	if ! [[ $homechoice ]] || [[ $homechoice == "false" ]] ; then
		defaults write "$procid" APMAC "" 2>/dev/null
	else
		defaults write "$procid" APMAC "$macaddr" 2>/dev/null
	fi
}

# sub-function: configure auxiliary e-mail settings (server, port etc.)
_smail-setup () {	
	# sendEmail: general
	if $init ; then
		smailsetupchoice=$(osascript 2>/dev/null << EOC
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theSESetupChoice to button returned of (display dialog "$uiprocess has detected an installation of the sendEmail command-line program. Do you want to continue and configure it for use with $uiprocess in addition to the Apple Mail application?" ¬
		buttons {"Cancel", "Continue"} ¬
		default button 2 ¬
		cancel button "Cancel" ¬
		with title "$uiprocess" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOC
		)
	else
		smailsetupchoice=$(osascript 2>/dev/null << EOC
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theSESetupChoice to button returned of (display dialog "$uiprocess has detected an installation of the sendEmail command-line program. Do you want to re-configure or keep the current setup?" ¬
		buttons {"Cancel", "Re-Configure", "Keep"} ¬
		default button 3 ¬
		cancel button "Cancel" ¬
		with title "$uiprocess" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOC
		)
	fi
	if ! [[ $smailsetupchoice ]] || [[ $smailsetupchoice == "false" ]] ; then
		echo -n "canceled"
		return
	fi
	if [[ $smailsetupchoice == "Keep" ]] ; then
		echo -n "keep"
		return
	fi
	
	# e-mail sender address
	currentsender=$(defaults read "$procid" seSender 2>/dev/null)
	while true
	do
		sender=$(osascript 2>/dev/null << EOM
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theMailSender to text returned of (display dialog "Please enter the e-mail address that $uiprocess will use to send file sharing information to the recipients." & return & return & "Format: name@domain.tld" ¬
		default answer "$currentsender" ¬
		buttons {"Cancel", "Enter"} ¬
		default button 2 ¬
		cancel button "Cancel" ¬
		with title "$uiprocess" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOM
		)
		if ! [[ $sender ]] || [[ $sender == "false" ]] ; then
			echo -n "canceled"
			return
		else
			if ! echo "$sender" | grep -q "^.*\@.*\.[a-z]*$" &>/dev/null ; then
				_sysbeep &
				_notify "⚠️ Error: e-mail address" "Not a valid format"
			else
				break
			fi
		fi
	done
	if [[ $sender != "$currentsender" ]] ; then
		defaults write "$procid" seSender "$sender" 2>/dev/null
	fi
	
	# server URL
	currentserver=$(defaults read "$procid" seServer 2>/dev/null)
	server=$(osascript 2>/dev/null << EOM
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theMailSender to text returned of (display dialog "Please enter the URL of the e-mail server that $uiprocess will use to send file sharing information to the recipients." & return & return & "Usual format: subdomain.domain.tld" ¬
		default answer "$currentserver" ¬
		buttons {"Cancel", "Enter"} ¬
		default button 2 ¬
		cancel button "Cancel" ¬
		with title "$uiprocess" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOM
	)
	if ! [[ $server ]] || [[ $server == "false" ]] ; then
		echo -n "canceled"
		return
	fi
	if [[ $server != "$currentserver" ]] ; then
		defaults write "$procid" seServer "$server" 2>/dev/null
	fi
	
	# connection (TLS & port)
	connection=$(osascript 2>/dev/null << EOC
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theConnectionMethod to button returned of (display dialog "Do you want $uiprocess to connect to your e-mail server using standard settings with TLS on port 587?" ¬
		buttons {"Cancel", "No", "Yes"} ¬
		default button 3 ¬
		cancel button "Cancel" ¬
		with title "$uiprocess" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOC
	)
	if ! [[ $connection ]] || [[ $connection == "false" ]] ; then
		echo -n "canceled"
		return
	fi
	if [[ $connection == "Yes" ]] ; then
		defaults write "$procid" seTLS -bool true 2>/dev/null
		defaults write "$procid" sePort -integer 587 2>/dev/null
		return
	fi
	defaults write "$procid" seTLS -bool false 2>/dev/null
	
	# choose ports
	mailportchoice=$(osascript 2>/dev/null <<EOC
tell application "System Events"
	activate
	set thePortList to {"25 (AUTH)", "456 (SSL)", "587 (AUTH)", "587 (TLS)", "2525 (AUTH)", "Other"}
	set thePortChoice to choose from list thePortList with title "$uiprocess" with prompt "Please select the SMTP port." default items {"587 (TLS)"}
end tell
EOC
	)
	if ! [[ $mailportchoice ]] || [[ $mailportchoice == "false" ]] ; then
		echo -n "canceled"
		return
	fi
	if [[ $mailportchoice != "Other" ]] ; then
		if [[ $mailportchoice == "587 (TLS)" ]] ; then
			defaults write "$procid" seTLS -bool true 2>/dev/null
			defaults write "$procid" sePort -integer 587 2>/dev/null
			return
		else
			defaults write "$procid" seTLS -bool false 2>/dev/null
			mailport=$(echo "$mailportchoice" | awk -F" " '{print $1}')
			defaults write "$procid" sePort -integer "$mailport" 2>/dev/null
			return
		fi
	else
		defaults write "$procid" seTLS -bool false 2>/dev/null
		currentmailport=$(defaults read "$procid" sePort 2>/dev/null)
		while true
		do
			mailport=$(osascript 2>/dev/null << EOM
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theMailSender to text returned of (display dialog "Please enter the SMTP port number manually." ¬
		default answer "$currentserver" ¬
		buttons {"Cancel", "Enter"} ¬
		default button 2 ¬
		cancel button "Cancel" ¬
		with title "$uiprocess" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOM
			)
			if ! [[ $mailport ]] || [[ $mailport == "false" ]] ; then
				echo -n "canceled"
				return
			fi
			if [[ $(echo "$mailport" | sed 's/[0-9]*//g') ]] ; then
				_sysbeep &
				_notify "⚠️ Input error" "Please use integers only"
			else
				break
			fi
		done
		if [[ $mailport != "$currentmailport" ]] ; then
			defaults write "$procid" sePort -integer "$mailport" 2>/dev/null
		fi
	fi
}

# sub-function: configure email credentials & store in keychain
_keychain () {	
	# enter credentials: general
	credcont=$(osascript 2>/dev/null << EOC
tell application "cURL Drop Companion"
	set theButton to button returned of (display alert ¬
		"In the next step $uiprocess will ask your for your e-mail credentials, specifically the username and password of your e-mail account. Do you want to continue?" ¬
		buttons {"Cancel", "Continue"} ¬
		as informational ¬
		message "This data will be stored safely in your macOS login keychain, and you will need to enter your macOS administrator password to create the new keychain entry." ¬
		cancel button 1 ¬
		default button 2 ¬
		giving up after 180)
end tell
EOC
	)
	if ! [[ $credcont ]] || [[ $credcont == "false" ]] ; then
		echo -n "canceled"
		return
	fi
	
	# mail account name
	currentmailuser=$(defaults read "$procid" seUser 2>/dev/null)
	while true
	do
		mailuser=$(osascript 2>/dev/null << EOM
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theMailUser to text returned of (display dialog "Please enter the account name connected to your e-mail address." ¬
		default answer "$currentmailuser" ¬
		buttons {"Cancel", "Enter"} ¬
		default button 2 ¬
		cancel button "Cancel" ¬
		with title "$uiprocess" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOM
		)
		if ! [[ $mailuser ]] || [[ $mailuser == "false" ]] ; then
			mailuser=""
			break
		fi
		mailuser_test=$(osascript 2>/dev/null << EOT
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theMailRecipient to text returned of (display dialog "Please re-enter the account name to confirm." ¬
		default answer "" ¬
		buttons {"Cancel", "Confirm"} ¬
		default button 2 ¬
		cancel button "Cancel" ¬
		with title "$uiprocess" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOT
		)
		if ! [[ $mailuser_test ]] || [[ $mailuser_test == "false" ]] ; then
			mailuser=""
			break
		fi
		if [[ $mailuser_test == "$mailuser" ]] ; then
			break
		else
			_sysbeep &
			_notify "⚠️ Input does not match"
		fi
	done
	if ! [[ $mailuser ]] ; then
		echo -n "canceled"
		return
	fi
	if [[ $mailuser != "$currentmailuser" ]] ; then
		defaults write "$procid" seUser "$mailuser" 2>/dev/null
	fi
	
	# password
	while true
	do
		password=$(osascript 2>/dev/null << EOM
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theMailPassword to text returned of (display dialog "Please enter the access password for your e-mail account." ¬
		with hidden answer ¬
		default answer "" ¬
		buttons {"Cancel", "Enter"} ¬
		default button 2 ¬
		cancel button "Cancel" ¬
		with title "$uiprocess" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOM
		)
		if ! [[ $password ]] || [[ $password == "false" ]] ; then
			password=""
			break
		fi
		password_test=$(osascript 2>/dev/null << EOT
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theMailPassword to text returned of (display dialog "Please re-enter the password to confirm." ¬
		with hidden answer ¬
		default answer "" ¬
		buttons {"Cancel", "Confirm"} ¬
		default button 2 ¬
		cancel button "Cancel" ¬
		with title "$uiprocess" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOT
		)
		if ! [[ $password_test ]] || [[ $password_test == "false" ]] ; then
			password=""
			break
		fi
		if [[ $password_test == "$password" ]] ; then
			break
		else
			_sysbeep &
			_notify "⚠️ Input does not match"
		fi
	done
	if ! [[ $password ]] ; then
		echo -n "canceled"
		return
	fi
	# add password to keychain
	security add-generic-password -U -D "application password" -s "$mailuser" -l "cURL Drop Companion (sendEmail password)" -a "$LOGNAME" -T "" -w "$password"
}

# main setup/config function
_main-setup () {
	lastnav=$(/usr/libexec/PlistBuddy -c "Print:lastNavigation" "$prefsloc" 2>/dev/null)
	if ! [[ $lastnav ]] || [[ $lastnav == "." ]] ; then
		lastnav="$HOMEDIR"
		defaults write "$procid" lastNavigation "$lastnav" 2>/dev/null
	fi
	_cdc-setup
	if ! $smail ; then
		echo "No sendEmail support: skipping setup"
		sender=""
		server=""
		mailport=""
		itls="yes"
		mailuser=""
		password=""
	else
		smailsel=$(_smail-setup)
		if [[ $smailsel == "canceled" ]] ; then
			echo "User canceled sendEmail setup"
			defaults write "$procid" seStatus -bool false &>/dev/null
			smail=false
		elif [[ $smailsel == "keep" ]] ; then
			echo "User chose to keep current sendEmail setup"
		else
			keychainsel=$(_keychain)
			if [[ $keychainsel == "canceled" ]] ; then
				defaults write "$procid" seStatus -bool false &>/dev/null
				smail=false
			else
				defaults write "$procid" seStatus -bool true &>/dev/null
			fi
		fi
	fi
	_success &
	setupend=$(osascript 2>/dev/null << EOI
tell application "cURL Drop Companion"
	set theButton to button returned of (display alert ¬
		"Setup complete." ¬
		buttons {"OK"} ¬
		as informational ¬
		message "You can now use cURL Drop Companion to give other computers access to selected files over the local network or the internet with curldrop." ¬
		default button 1 ¬
		giving up after 60)
end tell
EOI
	)
	echo "Setup: $setupend"
}

# initial network settings
netstat_raw=$(netstat -nr | grep "UG" | grep "^default" | grep -v -e "tun" -e "tap" | head -1)
apip=$(echo "$netstat_raw" | awk '{print $2}')
if ! [[ $apip ]] ; then
	echo "AP/router IP: -"
	arp_raw=$(arp -a 2>/dev/null | head -1)
else
	ping -c 1 "$apip" &>/dev/null
	echo "AP/router IP: $apip"
	sleep .5
	arp_raw=$(arp "$apip" 2>/dev/null)
fi

# preferences
init=false
prefsloc="$HOMEDIR/Library/Preferences/$procid.plist"
if ! [[ -f "$prefsloc" ]] ; then
	echo "No preferences file detected"
	lastnavinit="$HOMEDIR"
	defaults write "$procid" lastNavigation "$lastnavinit" 2>/dev/null
	init=true
fi
if $init ; then # start init proces
	echo "Starting initial setup..."
	_main-setup
else # main process
	apmac=false
	if $smail ; then
		if [[ $(/usr/libexec/PlistBuddy -c "Print:seStatus" "$prefsloc" 2>/dev/null) == "false" ]] ; then
			smail=false
		else # sendEmail is configured: read settings
			if [[ $(/usr/libexec/PlistBuddy -c "Print:seTLS" "$prefsloc" 2>/dev/null) == "true" ]] ; then
				itls="yes"
			else
				itls="auto"
			fi
			echo "TLS: $itls"
			sender=$(/usr/libexec/PlistBuddy -c "Print:seSender" "$prefsloc" 2>/dev/null)
			if ! [[ $sender ]] ; then
				echo "ERROR: no sender e-mail address"
				smail=false
			else
				echo "Sender: $sender"
				server=$(/usr/libexec/PlistBuddy -c "Print:seServer" "$prefsloc" 2>/dev/null)
				if ! [[ $server ]] ; then
					echo "ERROR: no e-mail server"
					smail=false
				else
					echo "Mail server: $server"
					mailport=$(/usr/libexec/PlistBuddy -c "Print:sePort" "$prefsloc" 2>/dev/null)
					if ! [[ $mailport ]] ; then
						echo "ERROR: no SMTP port"
						smail=false
					else
						echo "SMTP port: $mailport"
						mailuser=$(/usr/libexec/PlistBuddy -c "Print:seUser" "$prefsloc" 2>/dev/null)
						if ! [[ $mailuser ]] ; then
							echo "ERROR: no e-mail user account"
							smail=false
						else
							echo "Mail user: $mailuser"
						fi
					fi
				fi
			fi
			if $smail ; then # read from keychain
				password=$(security find-generic-password -w -ga "$LOGNAME" -l "cURL Drop Companion (sendEmail password)" -s "$mailuser" 2>/dev/null)
				if ! [[ $password ]] ; then
					smail=false
					echo "ERROR: no mail password"
				else
					echo "Password: [redacted]"
				fi
			fi
		fi
	else # no sendEmail
		sender=""
		server=""
		mailport=""
		itls="yes"
		mailuser=""
		password=""
	fi
	# read CDC main settings
	port=$(/usr/libexec/PlistBuddy -c "Print:localSharingPort" "$prefsloc" 2>/dev/null)
	if ! [[ $port ]] ; then
		port="8000"
		defaults write "$procid" localSharingPort -integer "$port" 2>/dev/null
	fi
	echo "LAN port: $port"
	wport=$(/usr/libexec/PlistBuddy -c "Print:remoteSharingPort" "$prefsloc" 2>/dev/null)
	if ! [[ $wport ]] ; then
		wport="4747"
		defaults write "$procid" remoteSharingPort -integer "$wport" 2>/dev/null
	fi
	echo "WAN port: $wport"
	sharedir=$(/usr/libexec/PlistBuddy -c "Print:curldropDirectory" "$prefsloc" 2>/dev/null)
	if ! [[ $sharedir ]] ; then
		sharedir="$HOMEDIR/Sites/curldrop"
		defaults write "$procid" curldropDirectory "$sharedir" 2>/dev/null
	fi
	! [[ -d "$sharedir" ]] && mkdir -p "$sharedir"
	echo "curldrop directory: $sharedir"
	ddns_domain=$(/usr/libexec/PlistBuddy -c "Print:dynamicDNSDomain" "$prefsloc" 2>/dev/null)
	if ! [[ $ddns_domain ]] ; then
		echo "DynDNS: [not configured]"
		home_mac=""
		echo "Default AP/router MAC: [not configured]"
	else
		echo "DynDNS: $ddns_domain"
		home_mac=$(/usr/libexec/PlistBuddy -c "Print:APMAC" "$prefsloc" 2>/dev/null)
		if [[ $home_mac ]] ; then
			apmac=true
			echo "Default AP/router MAC: $home_mac"
		else
			echo "Default AP/router MAC: -"
		fi
	fi
fi

if $smail ; then
	echo "sendEmail supported"
else
	echo "NOTE: sendEmail not supported: configuration missing"
fi

$init && _quit-direct

# function: stop the curldrop server daemon
_cdc-stop () {
	errors=false
	# check for remote port file first
	if [[ -f "$sharedir/remote" ]] ; then # exists: previous operation was a remote share
		echo "Remote port file detected"
		# disable port forwarding in AP/router
		closeport=$(cat "$sharedir/remote" 2>/dev/null | xargs)
		if [[ $closeport ]] ; then
			echo "Closing port: $closeport"
			if upnpc -d "$closeport" tcp ; then
				echo "Success: port closed"
				rm -f "$sharedir/remote"
				_notify "☑️ Port $closeport closed"
			else
				errors=true
				echo "ERROR: could not close remote port"
				_notify "⚠️ Error: remote port" "Could not close port"
			fi
		else
			errors=true
			echo "WARNING: no remote port in file"
			_notify "⚠️ Warning: remote port" "No port detected from previous session"
		fi
	else # does not exist: previous operation was a local share
		echo "NOTE: no remote port file detected"
	fi
	# look for PIDs of curldrop workers
	pidlist=$(ps aux | grep "/Python.app/Contents/MacOS/Python " | grep "/curldrop " | awk '{print $2}' | sort -nr)
	processes=false
	if ! [[ $pidlist ]] ; then
		echo "NOTE: no worker processes detected"
		_notify "ℹ️ No worker processes detected"
	else # workers found: quit or (fallback) kill
		processes=true
		workerror=false
		while read -r pid
		do
			if ! kill -n 3 "$pid" 2>/dev/null ; then
				if ! kill -n 9 "$pid" 2>/dev/null ; then
					workerror=true
					echo "Error killing worker PID $pid"
					_notify "⚠️ Error killing process" "PID: $pid"
					continue
				else
					echo "Successfully killed worker PID $pid (signal: 9)"	
				fi
			else
				echo "Successfully killed worker PID $pid (signal: 3)"	
			fi
		done < <(echo "$pidlist")
		if $workerror ; then
			errors=true
		else
			_notify "☑️ cURL Drop server stopped"
		fi
	fi
	# delete the share files proper and their info files
	if ! [[ -f $histloc ]] ; then # no history file (manual deletion?)
		echo "NOTE: history file does not exist"
		if $processes ; then
			errors=true
			_notify "ℹ️ No history file detected"
		fi
	else # parse history for file names
		histevents=$(sort -nr -k1 "$histloc" 2>/dev/null)
		if ! [[ $histevents ]] ; then
			echo "NOTE: history file is empty"
			if $processes ; then
				errors=true
			fi
			_notify "ℹ️ History file is empty"
		else
			# remove previously shared files & their info files
			while read -r histevent
			do
				! [[ $histevent ]] && continue
				rmloc=$(echo "$histevent" | awk -F"$(printf '\t')" '{print $2}')
				if ! [[ $rmloc ]] ; then
					echo "ERROR: could not determine file location!"
					_notify "⚠️ Error determining file location"
					errors=true
				else
					echo "Removing: $rmloc"
					rmbase=$(basename "$rmloc")
					if ! [[ -e "$rmloc" ]] ; then
						echo "ERROR: file missing"
						_notify "⚠️ Error: file missing" "$rmbase"
						errors=true
					else
						if rm -rf "$rmloc" &>/dev/null ; then
							echo "Success: file removed"
							_notify "🗑 File removed" "$rmbase"
						else
							echo "ERROR: could not remove file"
							_notify "⚠️ Error removing file" "$rmbase"
							errors=true
						fi
						rmparent=$(dirname "$rmloc")
						infofile="$rmparent/_$rmbase-info.txt"
						if [[ -f "$infofile" ]] ; then
							if rm -rf "$infofile" &>/dev/null ; then
								echo "Success: info file removed"
							else
								echo "ERROR: could not remove info file"
								_notify "⚠️ Error removing info file" "_$rmbase-info.txt"
								errors=true
							fi
						else
							echo "NOTE: info file does not exist"
						fi
						qrcodefile="$rmparent/_$rmbase-qrcode.png"
						if [[ -f "$qrcodefile" ]] ; then
							if rm -rf "$qrcodefile" &>/dev/null ; then
								echo "Success: QR code image file removed"
							else
								echo "ERROR: could not remove QR code image file"
								_notify "⚠️ Error removing QR Code" "_$rmbase-qrcode.png"
								errors=true
							fi
						else
							echo "NOTE: QR code image file does not exist"
						fi
					fi
				fi
			done < <(echo "$histevents")
			if ! $errors ; then
				_success &
			else
				_sysbeep &
			fi
		fi
		rm -f "$histloc" 2>/dev/null
	fi
	_quit-direct
}

# check for input
if ! [[ $* ]] ; then # no input: open file dialog
	echo "No input: launching startup options"
	setupchoice=$(osascript 2>/dev/null << EOC
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theSetupChoice to button returned of (display dialog "Do you want to stop the cURL Drop server, configure $uiprocess, or select files for sharing?" ¬
		buttons {"Select Files…", "Configure", "Clear Server"} ¬
		default button 3 ¬
		with title "$uiprocess" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOC
	)
	if ! [[ $setupchoice ]] || [[ $setupchoice == "false" ]] ; then
		echo "Options timed out"
		_quit-direct
	fi
	if [[ $setupchoice == "Configure" ]] ; then
		echo "Entering setup..."
		if ! command -v sendEmail &>/dev/null ; then
			smail=false
		else
			smail=true
		fi
		_main-setup
		_quit-direct
	elif [[ $setupchoice == "Clear Server" ]] ; then
		echo "Starting function to stop & clean up the cURL Drop Server..."
		_cdc-stop
		_quit-direct
	fi
	lastnav=$(/usr/libexec/PlistBuddy -c "Print:lastNavigation" "$prefsloc" 2>/dev/null)
	if ! [[ $lastnav ]] || [[ $lastnav == "." ]] ; then
		lastnav="$HOMEDIR"
	fi
	echo "Opening file selection..."
	while true
	do
		fpathchoices=$(osascript 2>/dev/null << EOS
tell application "System Events"
	activate
	set theDefaultPath to "$lastnav" as string
	set theShareFiles to choose file with prompt ¬
		"Please select one or more files to share with cURL Drop…" ¬
		with multiple selections allowed ¬
		default location theDefaultPath
	repeat with aShareFile in theShareFiles
		set contents of aShareFile to POSIX path of (contents of aShareFile)
	end repeat
	set AppleScript's text item delimiters to linefeed
	theShareFiles as text
end tell
EOS
		)
		if ! [[ $fpathchoices ]] || [[ $fpathchoices == "false" ]] ; then
			echo "User has canceled"
			_quit-direct
		fi
		fpathone=$(echo "$fpathchoices" | head -1)
		fpathdir=$(dirname "$fpathone")
		defaults write "$procid" lastNavigation "$fpathdir" 2>/dev/null
		# user has selected files for sharing: populate $@
		shift $#
		while read -r fpathchoice
		do
			if ! [[ -f "$fpathchoice" ]] ; then # might have selected e.g. an .app bundle
				_sysbeep &
				_notify "ℹ️ Wrong file type" "Only regular files are supported"
			else
				echo "User selected: $fpathchoice"
				set -- "$@" "$fpathchoice"
			fi
		done < <(echo "$fpathchoices")
		[[ $* ]] && break
		# ask for file selection again if $@ is still empty
	done
fi

# check for input of multiple files
multi=false
fstr="file"
fstr_long="file is"
lstr="link"
if [[ $# -gt 1 ]] ; then
	multi=true
	fstr="files"
	fstr_long="files are"
	lstr="links"
fi

# ask for local or remote sharing
sharechoice=$(osascript 2>/dev/null << EOC
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theSharingMethod to button returned of (display dialog "Do you want to share your $fstr with a remote user or with a user on the local network?" ¬
		buttons {"Cancel", "Remote", "Local"} ¬
		default button 3 ¬
		cancel button "Cancel" ¬
		with title "$uiprocess" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOC
)
if ! [[ $sharechoice ]] || [[ $sharechoice == "false" ]] ; then
	echo "User canceled"
	_quit-direct
fi
if [[ $sharechoice == "Remote" ]] ; then
	remoteshare=true
	echo "User chose remote file sharing"
else
	remoteshare=false
	echo "User chose local file sharing"
fi

# network settings: needed by both local & remote sharing
routestat=$(route get 0.0.0.0 2>&1)
localdevice=$(echo "$routestat" | awk -F": " '/interface:/{print $2}' | grep -v -e "tun" -e "tap" -e "feth")
if ! [[ $localdevice ]] ; then
	localdevice=$(echo "$netstat_raw" | awk '{print $4}')
	if ! [[ $localdevice ]] ; then
		if ! [[ $apip ]] ; then
			apip=$(echo "$arp_raw" | awk -F"[)(]" '{print $2}')
		fi
		if [[ $apip ]] ; then
			echo "AP/router IP: $apip"
			apagrep=$(echo "$apip" | sed 's/\./\\./g')
			localdevice=$(netstat -nr | grep "$apagrep" | grep "^default" | awk '{print $4}')
		else
			echo "AP/router IP: -"
		fi
		! [[ $localdevice ]] && localdevice="foo0"
	fi
fi
echo "Local network device: $localdevice"
localip=$(ipconfig getifaddr "$localdevice" 2>/dev/null)
if ! [[ $localip ]] ; then
	localip=$(upnpc -s 2>&1 | awk -F" : " '/^Local LAN ip address/{print $2}' 2>/dev/null)
	if ! [[ $localip ]] ; then
		if $remoteshare ; then
			echo "ERROR: could not determine local IP address"
			_sysbeep &
			_notify "⚠️ Local networking error" "No local IP address"
			_quit-direct
		else
			echo "Local IP address: -"
		fi
	fi
else
	echo "Local IP address: $localip"
fi

# individual network settings
if $remoteshare ; then # remote settings
	if $apmac ; then # check if MAC addresses match
		currentmacaddr=$(echo "$arp_raw" | awk -F")" '{print $NF}' | sed -e "s/^ at //" -e "s/ on .*//" | xargs)
		[[ $currentmacaddr != "$home_mac" ]] && apmac=false
	fi
	! $apmac && ddns_domain=""
	gateway=$(echo "$routestat" | awk '/gateway:/ {print $2}')
	if ! [[ $gateway ]] ; then
		! [[ $arp_raw ]] && arp_raw=$(arp -a 2>/dev/null | head -1)
		gateway=$(echo "$arp_raw" | awk -F"[)(]" '{print $1}' | xargs)
	fi
	publicip=""
	publicip=$(external-ip 2>/dev/null)
	if ! [[ $publicip ]] ; then
		if [[ $gateway == "fritz.box" ]] ; then
			publicip=$(curl "http://fritz.box:49000/igdupnp/control/WANIPConn1" -H "Content-Type: text/xml; charset="utf-8"" -H "SoapAction:urn:schemas-upnp-org:service:WANIPConnection:1#GetExternalIPAddress" -d "<?xml version='1.0' encoding='utf-8'?> <s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'> <s:Body> <u:GetExternalIPAddress xmlns:u='urn:schemas-upnp-org:service:WANIPConnection:1' /> </s:Body> </s:Envelope>" -s \
				| grep -Eo '\<[[:digit:]]{1,3}(\.[[:digit:]]{1,3}){3}\>')
		fi
	fi
	if ! [[ $publicip ]] ; then
		icount=0
		while true
		do
			[[ $icount -eq 3 ]] && break
			publicip=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null)
			[[ $publicip ]] && break
			sleep 1
			((icount++))
		done
	fi
	if ! [[ $publicip ]] ; then
		publicip=$(curl -sL --connect-timeout 10 --max-time 3 ipinfo.io/ip 2>/dev/null)
	fi
	if ! [[ $publicip ]] ; then
		publicip=$(curl -sL --connect-timeout 10 --max-time 3 icanhazip.com 2>/dev/null)
	fi
	
	# pre-define base sharing URLs
	if ! [[ $publicip ]] ; then
		echo "ERROR: no public IP address"
		if ! [[ $ddns_domain ]] ; then
			_sysbeep &
			_notify "⚠️ Error: no public IP"
			_quit-direct
		else
			port="$wport"
			echo "DynDNS domain: $ddns_domain"
			curldropdomainurl="$ddns_domain:$port"
			curldropipurl="$ddns_domain:$port"
		fi
	else
		port="$wport"
		echo "Public IP: $publicip"
		if ! [[ $ddns_domain ]] ; then
			echo "NOTE: no DynDNS domain"
			curldropdomainurl="http://$publicip:$port"
			curldropipurl="http://$publicip:$port"
		else
			echo "DynDNS domain: $ddns_domain"
			curldropdomainurl="$ddns_domain:$port"
			curldropipurl="http://$publicip:$port"
		fi
	fi
	
	# open port in AP/router for remote access
	if ! upnpc -e curldrop -a "$localip" "$port" "$port" tcp ; then
		_sysbeep &
		echo "ERROR: unable to configure port forwarding"
		_notify "⚠️ Error: port forwarding"
		upnpc -d "$port" tcp
		_quit-direct
	else
		_beep &
	fi
else # local file sharing
	localhostname=$(scutil --get LocalHostName 2>/dev/null)
	if ! [[ $localhostname ]] && ! [[ $localip ]] ; then
		echo "ERROR: no local network information"
		_sysbeep &
		_notify "⚠️ Error: local network" "Detected neither LocalHostName nor IP address"
		_quit-direct
	fi
	# pre-define base sharing URLs
	if ! [[ $localhostname ]] ; then
		echo "LocalHost Domain: n/a"
		curldropdomainurl="http://$localip:$port"
	else
		echo "LocalHost Domain: $localhostname.local"
		curldropdomainurl="http://$localhostname.local:$port"
	fi
	if ! [[ $localip ]] ; then
		echo "Local IP address: n/a"
		curldropipurl="http://$localhostname.local:$port"
	else
		echo "Local IP address: $localip"
		curldropipurl="http://$localip:$port"
	fi
fi

# check if curldrop (via Python) is already running and start, if necessary
breaker=false
if ! ps aux | grep "/Python.app/Contents/MacOS/Python " | grep "/curldrop " &>/dev/null ; then # not running
	rm -f "$sharedir/remote"
	if $remoteshare ; then
		echo "$port" > "$sharedir/remote"
	fi
	# start curldrop via helper script & check (with timeout) until it's running
	nohup curldrop --port "$port" --upload-dir "$sharedir" &
	disown
	sleep 3
	count=0
	while true
	do
		if [[ $count -eq 10 ]] ; then
			breaker=true
			break
		fi
		if ps aux | grep "/Python.app/Contents/MacOS/Python " | grep "/curldrop " &>/dev/null ; then
			sleep 1
			break
		fi
		((count++))
		sleep 1
	done
fi
if $breaker ; then # failed to start curldrop (after timeout)
	_sysbeep &
	echo "ERROR: no worker processes detected!"
	_notify "⚠️ Error: no workers detected" "Error starting cURL Drop"
	_quit-direct
else
	_beep &
	echo "curldrop execution detected"
fi

rm -f "$histloc" 2>/dev/null

# actual cURL sharing routine
histlist=""
filecount=1
shareinfo=""
seqrcodes=""
amqrcodes=""
errors=false
for filepath in "$@"
do
	fileinfo=""
	filebase=$(basename "$filepath")
	if ! [[ -f "$filepath" ]] ; then
		errors=true
		echo "NOTE: only regular files are supported"
		_notify "ℹ️ Note: only regular files" "$filebase"
		continue
	fi
	# upload to localhost
	shareurl=$(curl --silent --upload-file "$filepath" "http://localhost:$port")
	if ! [[ $shareurl ]] ; then
		echo "ERROR: cURL - no share URL"
		errors=true
		_notify "⚠️ Error sharing file" "$filebase"
		sleep 1
		continue
	fi
	echo "Raw share URL: $shareurl"
	# parse for sharing key
	sharekey=$(echo "$shareurl" | awk -F"/" '{print $4}')
	if ! [[ $sharekey ]] ; then
		errors=true
		echo "ERROR: could not parse the sharing key"
		_notify "⚠️ Error parsing sharing key" "$filebase"
		continue
	fi
	echo "Sharing key: $sharekey"
	filename=$(basename "$filepath" | detox --inline)
	shareloc="$sharedir/$sharekey-$filename"
	histpath="$shareloc"
	if ! [[ -f "$shareloc" ]] ; then
		shareloc=$(find "$sharedir" -mindepth 1 -maxdepth 1 -type f -name "$sharekey*" 2>/dev/null | head -1)
	fi
	if ! [[ $shareloc ]] ; then
		shareloc="-"
		testloc="$filepath"
	else
		testloc="$shareloc"
		histpath="$shareloc"
	fi
	echo "Sharing location: $shareloc"
	infoloc="$sharedir/_$sharekey-$filename-info.txt"
	echo "Info file location: $infoloc"
	qrloc="$sharedir/_$sharekey-$filename-qrcode.png"
	echo "QR code image file location: $qrloc"
	
	# size & hash
	bytes=$(stat -f%z "$testloc" 2>/dev/null)
	mb_raw=$(bc -l <<< "scale=6; $bytes/1000000")
	mbytes=$(_round "$mb_raw" 2)
	[[ $mbytes == "0.00" ]] && mbytes="< 0.01"
	mib_raw=$(bc -l <<< "scale=6; $bytes/1048576")
	mibytes=$(_round "$mib_raw" 2)
	[[ $mibytes == "0.00" ]] && mibytes="< 0.01"
	fsizestr="$bytes B [$mbytes MB | $mibytes MiB]"
	shahash=$(shasum -a 256 "$testloc" | awk '{print $1}')
	
	_notify "✅ File ready to download" "$curldropdomainurl/$sharekey"
	if $multi ; then
		fileinfo="*** File #$filecount ***\nFilename: $filename\nDomain access: $curldropdomainurl/$sharekey\nIP access: $curldropipurl/$sharekey\nFile size: $fsizestr\nSHA-2 (256-bit): $shahash"
	else
		fileinfo="Filename: $filename\nDomain access: $curldropdomainurl/$sharekey\nIP access: $curldropipurl/$sharekey\nFile size: $fsizestr\nSHA-2 (256-bit): $shahash"
	fi
	echo -e "$fileinfo" > "$infoloc"
	
	posixdate=$(date +%s)
	qrencode "$curldropdomainurl/$sharekey" -o "$qrloc" 2>/dev/null
	if [[ $filecount -eq 1 ]] ; then
		seqrcodes="'$qrloc'"
		amqrcodes="$qrloc"
		histlist="$posixdate\t$histpath"
		shareinfo="$fileinfo"
	else
		seqrcodes="$seqrcodes '$qrloc'"
		amqrcodes="$amqrcodes\n$qrloc"
		histlist="$histlist\n$posixdate\t$histpath"
		shareinfo="$shareinfo\n\n$fileinfo"
	fi

	((filecount++))
done

if $errors ; then
	_sysbeep &
else
	_success &
fi

# write history
histlist=$(echo -e "$histlist")
if [[ $histlist ]] ; then
	echo "$histlist" > "$histloc" 2>/dev/null
else
	echo "ERROR: no files shared"
	_notify "⚠️ Error: no files shared"
	_quit-direct
fi
shareinfo=$(echo -e "$shareinfo")
amqrcodes=$(echo -e "$amqrcodes")

echo "$shareinfo" | grep -v "^$"

if ! $remoteshare ; then
	printerlist=$(lpstat -a | awk '{print $1}')
	if [[ $printerlist ]] ; then
		rm -f "/tmp/$procid.cups.txt" 2>/dev/null
		echo "$shareinfo" > "/tmp/$procid.cups.txt"
		if [[ $(echo "$printerlist" | wc -l) -eq 1 ]] ; then
			printer="$printerlist"
		else
			printer=$(lpstat -p -d | awk -F": " '/^system default destination/{print $2}')
			if ! [[ $printer ]] ; then
				printer=$(echo "$printerlist" | head -1)
			fi
		fi
		printing=true
	else
		printing=false
	fi
else
	printing=false
fi

echo "Informing user..."
infochoice=$(osascript 2>/dev/null << EOS
tell application "cURL Drop Companion"
	set theButton to button returned of (display alert ¬
		"Your $fstr_long ready to download. The data will be copied to your pastedboard, and you can now select the sharing method." ¬
		buttons {"Cancel", "Continue"} ¬
		as informational ¬
		message "$shareinfo" ¬
		cancel button 1 ¬
		default button 2 ¬
		giving up after 180)
end tell
EOS
)

if [[ $infochoice != "Continue" ]] ; then
	echo "$shareinfo" | pbcopy
	echo "User canceled"
	_quit-app
fi

# more options? Signal? Threema? SMS? ###
read -d '' methods <<'EOH'
Apple Mail
Display QR Code
Messages
Print
sendEmail
EOH

! $tshare && methods=$(echo "$methods" | grep -v "^Messages$")
! $smail && methods=$(echo "$methods" | grep -v "^sendEmail$")
! $printing && methods=$(echo "$methods" | grep -v "^Print$")

method=$(osascript 2>/dev/null <<EOC
tell application "System Events"
	activate
	set theMethodList to {}
	set theMethods to paragraphs of "$methods"
	repeat with aMethod in theMethods
		set theMethodList to theMethodList & {(aMethod) as string}
	end repeat
	set theMethodChoice to choose from list theMethodList with title "$uiprocess" with prompt "Please select the sharing method." default items {"Apple Mail"}
end tell
EOC
)
if ! [[ $method ]] || [[ $method == "false" ]] ; then
	echo "User canceled"
	echo "$shareinfo" | pbcopy
	_quit-app
fi

echo "User chose: $method"

sharetext=$(echo -e "Your $fstr_long ready to download!\n\n$shareinfo")

# Apple Messages
if [[ $method == "Messages" ]] ; then
	finalsharetext=$(echo -e "\"$sharetext\"")
	echo "Merging QR code image files..."
	posixdate=$(date +%s)
	temp_img="/tmp/_cdc-qrcodes-$posixdate.png"
	if convert "$sharedir/_"*".png" +append "$temp_img" &>/dev/null ; then
		echo "Success: merge"
		terminal-share -service message -text "$finalsharetext" -image "$temp_img" 2>/dev/null
	else
		echo "ERROR: could not merge"
		terminal-share -service message -text "$finalsharetext" 2>/dev/null
	fi
	echo "$shareinfo" | pbcopy
	rm -f "$temp_img" 2>/dev/null
	_quit-app
fi

# Display QR Code
if [[ $method == "Display QR Code" ]] ; then
	while read -r qrloc
	do
		qlmanage -p "$qrloc" &>/dev/null &
	done < <(echo "$amqrcodes")
	echo "$shareinfo" | pbcopy
	_quit-app
fi

# Send to printer
if [[ $method == "Print" ]] ; then
	echo "User chose to print the data ($printer)"
	echo "$shareinfo" | pbcopy
	lpr -P "$printer" "/tmp/$procid.cups.txt"
	_quit-app
fi

# mail routines
accountname=$(id -un)
subject="[$accountname] cURL Drop Companion download $lstr"
recipients=$(osascript 2>/dev/null << EOM
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theMailRecipient to text returned of (display dialog "Please enter the recipient's e-mail address. You can enter several comma-delimited addresses to include other recipients in the BCC." ¬
		default answer "" ¬
		buttons {"Cancel", "Enter"} ¬
		default button 2 ¬
		cancel button "Cancel" ¬
		with title "$uiprocess" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOM
)
if ! [[ $recipients ]] || [[ $recipients == "false" ]] ; then
	echo "User canceled"
	echo "$shareinfo" | pbcopy
	_quit-app
fi
echo "Recipients: $recipients"

# Apple Mail
if [[ $method == "Apple Mail" ]] ; then
	echo "Creating new message in Apple Mail..."
	osascript 2>/dev/null << EON
tell application "Mail"
    activate
    set theAttachmentList to {}
    set theAttachments to paragraphs of "$amqrcodes"
	repeat with anAttachment in theAttachments
		set theAttachmentList to theAttachmentList & {(anAttachment) as POSIX file}
	end repeat
    set AppleScript's text item delimiters to {","}
    set theBCCs to paragraphs of "$recipients"
    set theNewEmail to make new outgoing message with properties {visible:true, sender:"$sender", subject:"$subject", content:"$sharetext" & linefeed & linefeed}
    tell theNewEmail
    	make new to recipient at beginning of to recipients with properties {address:"$sender"}
    	repeat with aBCC in theBCCs
			make new bcc recipient at end of bcc recipients with properties {address:aBCC}
		end repeat
		repeat with anAttachment in theAttachmentList
       		make new attachment with properties {file name:anAttachment} at after last paragraph
       		set content to (content & linefeed)
       	end repeat
    end tell
end tell
EON
	_quit-app
	echo "$shareinfo" | pbcopy
	_quit-app
fi

recipientsnote=$(echo "$recipients" | sed "s/,/ /g")
if [[ $method == "sendEmail" ]] ; then
	echo "Sending message with sendEmail..."
	if sendEmail -o message-content-type=text -o tls="$itls" -f "$sender" -t "$sender" -bcc $(eval echo $recipients) -u "$subject" -m "$sharetext" -a $(eval echo $seqrcodes) -s "$server:$mailport" -xu "$mailuser" -xp "$password" ; then
		echo "Success: information sent"
		_success &
		_notify "✅ Information sent" "$recipientsnote"
	else
		_sysbeep &
		echo "ERROR: could not send e-mail"
		_notify "⚠️ Error sending information" "$recipientsnote"
	fi
	echo "$shareinfo" | pbcopy
	_quit-app
fi
