# Create schedulers for script Alert2Telegram
# Written by Konkere - amorph@konkere.ru

:global TlgrmBotID "INSERT_YOUR_BOT_TOKEN_HERE"
:global TlgrmChatIDlog "INSERT_YOUR_CHAT_ID_HERE"
/system scheduler
add name=YesterdayDate on-event="/system scheduler set [find name=\"YesterdayDate\"] comment=[/system clock get date]" start-time=23:59:00 interval=1d
add name=Alert2Telegram on-event=Alert2Telegram start-time=00:01:00 interval=00:05:00
add name=TelegramBot on-event=":global TlgrmBotID \"$TlgrmBotID\"\r\n:global TlgrmChatIDlog \"$TlgrmChatIDlog\"" start-time=startup
