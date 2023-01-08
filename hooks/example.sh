#!/usr/bin/env bash

# This is an example hook that only logs a line in the console
case $1 in
"--pre")
	echo "[example-hook] Pausing notifications for $2 minutes"
	;;
"--post")
	echo "[example-hook] Resume notifications"
	;;
esac
