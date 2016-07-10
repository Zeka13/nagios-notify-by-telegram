#!/bin/bash

sendFunc()
{
	"$tgBinPath" `
	`--rsa-key "$tgKeyPath" `
	`--wait-dialog-list `
	`--exec "$tgSendCmd $contactName $messageText" `
	`--disable-link-preview `
	`--logname "$mesLogFile" `
	`>> $mesLogFile
}

#Path setup
tgSendCmd="msg"
tgDir="/usr/local/bin"
tgBinPath=""$tgDir"/telegram-cli"
tgKeyPath=""$tgDir"/tg-server.pub"
countersDir="/home/telegramd/services/"
logDir="/var/log/telegram"
#dont forget to setup log rotation
mesLogFile=""$logDir"/telegram.log"

#Parse arguments
contactName="$1"
messageText="$2"
serviceName="$3"

#Chat names settings
extraChatName="Extra_Monitoring"
fackupChatName="Fackup_Monitoring"
regularChatName="Regular_Monitoring"

#Maximum MINUTES that service or host can be down
#If this value reched,
#all alarms for <regularChatName>
#will forced to <fackupChatName> or <extraChatName>.
critTimeDiffMins="30"
extraTimeDiffMins="60"

#Exit with error if any parameters are not provided
if [[ -z "$contactName" || -z "$messageText" || -z "$serviceName" ]]
then
        echo "FAIL: cant parse all needed parameters" >> "$mesLogFile"
        echo "1="$1",2="$2",3="$3"" >> "$mesLogFile"
        exit 1
fi

#Exit with error if folder for counters not exists
mkdir -p "$countersDir"
if ! [[ -d "$countersDir" ]]
then
        echo "FAIL: cant create counters folder" >> "$mesLogFile"
        exit 1
fi

#Enable "extra" logic only for specific chat
if [[ "$contactName" == "$regularChatName" ]]
then
	tgSendCmd="post" #its a channels
        #extra monitoring logic
        currentDate=`date +"%Y-%m-%d %H:%M:%S"`
        serviceCounterFile=""$countersDir""$serviceName"_counter"
        serviceDateFile=""$countersDir""$serviceName"_data"

        #Before write - checking permissions
        touch "$serviceCounterFile" && touch "$serviceDateFile"
        if [[ "$?" != "0" ]]
        then
                echo "FAIL: cant access counter file" >> "$mesLogFile"
                exit 1
        fi

	#Get current counter value
	currentCounterAmount=`cat "$serviceCounterFile"`
	previousDate=`cat "$serviceDateFile"`

	#If it is a new count
        if [[ -z "$currentCounterAmount" || -z "$serviceCounterFile" ]]
        then
                currentCounterAmount="0"
                previousDate="$currentDate"
	fi

	#Calculate difference in minutes
	curSecsConverted=$(date +%s -d "$currentDate")
	prevSecsConverted=$(date +%s -d "$previousDate")
	curTimeDiffMins=$(( ($curSecsConverted - $prevSecsConverted) / 60 ))

	#If new notice not older than max TimeDiff
	if [[ "$curTimeDiffMins" -le "$extraTimeDiffMins"  ]] #<=
	then
		#Just force message reciver - its a fuckup!
		if [[ "$currentCounterAmount" -ge "$critTimeDiffMins"  ]] # >=
		then
			contactName="$fackupChatName"
		fi

		#Just force message reciver - its a super fuckup!
		if [[ "$currentCounterAmount" -ge "$extraTimeDiffMins"  ]] # >=
		then
			contactName="$extraChatName"
		fi

		#Increase counter with current time differense
		currentCounterAmount=$((currentCounterAmount+curTimeDiffMins))
		#And remember new values
		echo "$currentCounterAmount" > "$serviceCounterFile"
		echo "$currentDate" > "$serviceDateFile"
	#Reset counter, hold time is over
	else
		echo "0" > "$serviceCounterFile"
		echo "$currentDate" > "$serviceDateFile"
	fi
fi

sendFunc #send telegram message

exit $?
