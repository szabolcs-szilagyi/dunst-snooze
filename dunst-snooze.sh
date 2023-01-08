#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(readlink -f $0)")"
TIMER_FILE="$SCRIPT_DIR/measure"
HOOKS_DIR="$SCRIPT_DIR/hooks"
PID_FILE="$SCRIPT_DIR/process.pid"
# CURRENT_VALUE is representing the snooze time in minutes
CURRENT_VALUE=$(test -e "$TIMER_FILE" && cat "$TIMER_FILE" || echo "0")
PERVIOUS_VALUE="$CURRENT_VALUE"

function is_paused_icon {
	[ "$(dunstctl is-paused)" = "true" ] && echo "" || echo ""
}

function log {
	echo $@ >&2
}

#
# Will call hooks, _if_ directory is present. Will call the script with one of
# two possible flags:
# * --pre <duration time in minutes>
# * --post
#
function call_hooks {
	local flag=$([ "$1" = "paused" ] && echo "--pre $CURRENT_VALUE" || echo "--post")
	if [ -d "$HOOKS_DIR" ]; then
		log "Found hooks dir, running hooks..."
		for hook_script in "$HOOKS_DIR"/*; do
			log "Running script: $hook_script with flag: \"$flag\""
			bash -c "$hook_script $flag" >&2
		done
	fi
}

function set_paused {
	local new_value="$1"
	log "Set paused to: $new_value"
	if [ "$new_value" = "true" ]; then
		dunstctl set-paused true
		call_hooks paused
	else
		dunstctl set-paused false
		call_hooks unpaused
	fi
}

function pause_for_time {
	if [ "$CURRENT_VALUE" -lt 1 ]; then
		set_paused "true" &&
			bash -c "$1" &
	else
		log "Pause for: $CURRENT_VALUE"
		set_paused "true" &&
			bash -c "$1" &
		sleep "$(expr "$CURRENT_VALUE" \* 60)" &
		wait
		set_paused "false"
	fi
}

function format_timer {
	[ "$1" -lt 1 ] && printf "♾" && return
	local hours=$(expr "$1" / 60)
	local minutes=$(expr "$1" % 60)

	[ "$hours" -lt 1 ] &&
		printf "%02.f" "$minutes" ||
		printf "%b:%02.f" "$hours" "$minutes"
}

parse_command_line() {
	ARGS=$(getopt \
		-o t:udD: \
		--long toggle:,up,down,duration: \
		-- "$@")
	getopt_exit="$?"

	if [ "$getopt_exit" -ne 0 ]; then
		log "don't know what you wanted to do"
		exit 1
	fi

	eval set -- "$ARGS"

	for o; do
		case "$o" in
		-D | --duration)
			if [ -n "${2:-}" ]; then
				CURRENT_VALUE="${2}"
				echo "$CURRENT_VALUE" >"$TIMER_FILE"
				shift 2
			fi
			;;
		-t | --toggle)
			if [ -n "${2:-}" ]; then
				local post_call="${2}"
				[ -e "$PID_FILE" ] && kill -9 "$(cat $PID_FILE)"
				log "pid file: $PID_FILE and pid is $$"
				echo "$$" >"$PID_FILE"

				[ "$(dunstctl is-paused)" = "true" ] &&
					set_paused "false" ||
					pause_for_time "$post_call"

				bash -c "$post_call"
				rm "$PID_FILE"
				shift 2
			else
				shift 1
			fi
			;;
		-d | --down)
			[ "$CURRENT_VALUE" -gt 0 ] &&
				CURRENT_VALUE=$(echo "$(($CURRENT_VALUE - 5))")
			shift 1
			;;
		-u | --up)
			CURRENT_VALUE=$(echo "$(($CURRENT_VALUE + 5))")
			shift 1
			;;
		--)
			shift
			break
			;;
		esac
	done
}

function main {
	parse_command_line "$@"

	echo "$CURRENT_VALUE" >"$TIMER_FILE"

	log "$TIMER_FILE - had value: $PERVIOUS_VALUE, now has: $CURRENT_VALUE"

	echo "$(is_paused_icon) $(format_timer "$CURRENT_VALUE")"
}

main "$@"
