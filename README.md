# Activity Monitor

## What is it

This simple lua script monitors a services activity of my home server and
switches it off. My current services are: transmission-daemon, minidlna and ssh.
It checks for current active downloading torrents, and active inbound
connections on several ports.

## What is it for

My server is just based on Micro-ITX board and deployed in simple IKEA plastic
box in rack (from IKEA too). Some members of my family are not trust such scheme
and wanted it to be switched off when nobody home. So for convenience is should
powered off after half an hour from last activity. I can switch it on remotely
with WOL from vpn or my android phone.

## What to do with it

You can configure with several variables on the top and then configure cron to
run it once an 1 or 5 minutes or any time, you want.
