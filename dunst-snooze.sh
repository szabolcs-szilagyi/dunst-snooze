#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(readlink -f $0)")"
TIMER_FILE="$SCRIPT_DIR/measure"
PID_FILE="$SCRIPT_DIR/process.pid"
# CURRENT_VALUE is representing the snooze time in minutes
CURRENT_VALUE=$(test -e "$TIMER_FILE" && cat "$TIMER_FILE" || echo "0")
PERVIOUS_VALUE="$CURRENT_VALUE"

function is_paused {
	[ "$(dunstctl is-paused)" = "true" ] && echo "" || echo ""
}

function log {
	echo $@ >&2
}

function pause_for_time {
	if [[ "$CURRENT_VALUE" < 1 ]]; then
		dunstctl set-paused true &&
			bash -c "$1" &
	else
		dunstctl set-paused true &&
			bash -c "$1" &
		sleep "$(expr "$CURRENT_VALUE" \* 60)" &
		wait
		dunstctl set-paused false
	fi
}

function format_timer {
	[[ "$1" < 1 ]] && printf "♾" && return
	local hours=$(expr "$1" / 60)
	local minutes=$(expr "$1" % 60)

	[[ "$hours" < 1 ]] &&
		printf "%02.f" "$minutes" ||
		printf "%b:%02.f" "$hours" "$minutes"
}

case $1 in
"--up")
	CURRENT_VALUE=$(echo "$(($CURRENT_VALUE + 5))")
	;;
"--down")
	[[ "$CURRENT_VALUE" > 0 ]] &&
		CURRENT_VALUE=$(echo "$(($CURRENT_VALUE - 5))")
	;;
"--toggle")
	[ -e "$PID_FILE" ] && kill -9 "$(cat $PID_FILE)"
	log "pid file: $PID_FILE and pid is $$"
	echo "$$" >"$PID_FILE"

	[ "$(dunstctl is-paused)" = "true" ] &&
		dunstctl set-paused false ||
		pause_for_time "$2"

	bash -c "$2"
	rm "$PID_FILE"
	;;
esac

echo "$CURRENT_VALUE" >"$TIMER_FILE"

log "$TIMER_FILE - had value: $PERVIOUS_VALUE, now has: $CURRENT_VALUE"

echo "$(is_paused) $(format_timer "$CURRENT_VALUE")"
