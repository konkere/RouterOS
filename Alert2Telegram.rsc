# Script for log's alert (to Telegram)
# Written by Konkere - amorph@konkere.ru
# Tested on MikroTik RouterOS 6.48.6 long-term (CHR and RouterBoard)

:global TlgrmBotID
:global TlgrmChatIDlog
:local SchedulerName "Alert2Telegram"
:local CurrentHour [:pick [/system clock get time] 0 2]
:local GMToffset [:totime [/system clock get gmt-offset ]]
:local YesterdayDate [/system scheduler get [find name="YesterdayDate"] comment]
:local Messages [:toarray [/log find topics~"warning" || topics~"critical" || topics~"error" || topics~"firewall"]]
:local MessagesIgnore {"First ignore";"Second ignore"}
:local LastAlertTime [/system scheduler get [find name="$SchedulerName"] comment]
:local MessageTime
:local message
:local output
:local NewLogs false
:local count 0

:if ([:len $LastAlertTime] = 0) do={
    :set NewLogs true
}

if ( [:len $GMToffset] != 8 ) do={
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

        # Log date jan/01/1970 00:00:00 (full and default)
        :set MessageTime [/log get $MessageCheck time]

        # Log date 00:00:00
        :if ([:len $MessageTime] = 8) do={
            if ($CurrentHour > $GMToffset) do={
                #######################
                # Current date format #
                #######################
                :set MessageTime ([:pick [/system clock get date] 0 11]." ".$MessageTime)
            } else={
                #############################################
                # Current date format (BUG with GMT+offset) #
                #############################################
                :set MessageTime ($YesterdayDate." ".$MessageTime)
            }
        } else={
            # Log date jan/01 00:00:00 for yesterday and today (from 00 to GMToffset hours)
            :if ([:len $MessageTime] = 15 ) do={
                :set MessageTime ([:pick $MessageTime 0 6]."/".[:pick [/system clock get date] 7 11]." ".[:pick $MessageTime 7 15])
            }
        }
    
        :if ($NewLogs = true) do={
            :set output ($output."%F0%9F%9A%A9 ".$MessageTime." ".$message."%0A%0A")
        }

        :if ($MessageTime = $LastAlertTime) do={
            :set NewLogs true
            :set output ""
        }
    }

    :if ($count = ([:len $Messages]-1)) do={
        :if ($NewLogs = false) do={    
            :if ([:len $message] > 0) do={
                :set output ($output."%F0%9F%9A%A9 ".$MessageTime." ".$message."%0A%0A")
            }
        }
    }
    :set count ($count + 1)
}


if ([:len $output] > 0) do={
    /system scheduler set [find name="$SchedulerName"] comment=$MessageTime
    /tool fetch url="https://api.telegram.org/bot$TlgrmBotID/sendmessage?chat_id=$TlgrmChatIDlog&text=%E2%9D%97Alert%E2%9D%97%0A%0A$output" keep-result=no;
    /log info "$SchedulerName - New logs found, send to Telegram"
}
