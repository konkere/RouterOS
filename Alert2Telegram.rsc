# Script for log's alert (to Telegram)
# Written by Konkere - amorph@konkere.ru
# Tested on MikroTik RouterOS 6.48.6 long-term (CHR and RouterBoard)

:global TlgrmBotID
:global TlgrmChatIDlog
:local SchedulerName "Alert2Telegram"
:local CurrentDate [/system clock get date]
:local CurrentHour [:pick [/system clock get time] 0 2]
:local GMToffset [:totime [/system clock get gmt-offset ]]
:local YesterdayDate [/system scheduler get [find name="YesterdayDate"] comment]
# Topics for alert
:local Messages [:toarray [/log find topics~"warning" || topics~"critical" || topics~"error" || topics~"firewall"]]
# Patterns to ignore messages with text
:local MessagesIgnore {"First ignore";"Second ignore"}
:local LastAlertTime [/system scheduler get [find name="$SchedulerName"] comment]
# Trigger for convertation in output messages jan/20/1970 00:00:00 to 00:00:00 20.01.1970
# set false for default
:local ConvertDateTime true
:local MessageDateTime
:local message
:local output
:local NewLogs false
:local count 0


# Function for convert jan/20/1970 00:00:00 to 00:00:00 20.01.1970
:local DefConvertTime do={
    if ($convertDT = true) do={
        :local arrayMonths {jan="01";feb="02";mar="03";apr="04";may="05";jun="06";jul="07";aug="08";sep="09";oct="10";nov="11";dec="12"}
        :local mDate [:pick $MessageDT 4 6]
        :local mYear [:pick $MessageDT 7 11]
        :local mTime [:pick $MessageDT 12 20]
        :local mMonth ($arrayMonths->[:pick $MessageDT 0 3])
        :local MessageDT "$mTime $mDate.$mMonth.$mYear"
        :return $MessageDT
    } else={
        :return $MessageDT
    }
}


:if ([:len $LastAlertTime] = 0) do={
    :set NewLogs true
}

if ( [:len $GMToffset] != 8 ) do={
    # Convert negative GMToffset to readable (7101w3d03:28:16 to -03)
    :set $GMToffset [pick [:totime ([/system clock get gmt-offset ] - 4294967296)] 0 3]
} else={
    :set $GMToffset [:pick [$GMToffset] 0 2]
}

:if ([:len [/system scheduler find name="$SchedulerName"]] = 0) do={
    /log warning "$SchedulerName does not exist, create scheduler first"
}

# Messages loop
:foreach MessageCheck in=$Messages do={
    :local LogEntry true
    :foreach MessageIgnore in=$MessagesIgnore do={
        :if ([/log get $MessageCheck message] ~ "$MessageIgnore") do={
            :set LogEntry false
        }
    }
    :if ($LogEntry = true) do={
        :set message [/log get $MessageCheck message]

        # Log date jan/20/1970 00:00:00 (full and default)
        :set MessageDateTime [/log get $MessageCheck time]

        # Log date 00:00:00
        :if ([:len $MessageDateTime] = 8) do={
            if ($CurrentHour >= $GMToffset) do={
                # Current date format
                :set MessageDateTime ([:pick [/system clock get date] 0 11]." ".$MessageDateTime)
            } else={
                # Yesterday date format (from 00 to GMToffset hours, BUG with GMT+offset)
                :set MessageDateTime ($YesterdayDate." ".$MessageDateTime)
            }
        } else={
            # Log date jan/20 00:00:00 for yesterday and today (from 00 to GMToffset hours)
            :if ([:len $MessageDateTime] = 15 ) do={
                :set MessageDateTime ([:pick $MessageDateTime 0 6]."/".[:pick [/system clock get date] 7 11]." ".[:pick $MessageDateTime 7 15])
            }
        }
    
        :if ($NewLogs = true) do={
            :set output ($output."%F0%9F%9A%A9 ".[$DefConvertTime MessageDT=$MessageDateTime convertDT=$ConvertDateTime]."%0A".$message."%0A%0A")
        }

        :if ($MessageDateTime = $LastAlertTime) do={
            :set NewLogs true
            :set output ""
        }
    }

    :if ($count = ([:len $Messages]-1)) do={
        :if ($NewLogs = false) do={    
            :if ([:len $message] > 0) do={
            :set output ($output."%F0%9F%9A%A9 ".[$DefConvertTime MessageDT=$MessageDateTime convertDT=$ConvertDateTime]."%0A".$message."%0A%0A")
            }
        }
    }
    :set count ($count + 1)
}

# Update var YesterdayDate in scheduler's comment (if YesterdayDate not used at current time)
if (($CurrentHour >= $GMToffset) && ($YesterdayDate != $CurrentDate)) do={
    /system scheduler set [find name="YesterdayDate"] comment=$CurrentDate
}

if ([:len $output] > 0) do={
    /system scheduler set [find name="$SchedulerName"] comment=$MessageDateTime
    /tool fetch url="https://api.telegram.org/bot$TlgrmBotID/sendmessage?chat_id=$TlgrmChatIDlog&text=%E2%9D%97Alert%E2%9D%97%0A%0A$output" keep-result=no;
    /log info "$SchedulerName - New logs found, send to Telegram"
}
