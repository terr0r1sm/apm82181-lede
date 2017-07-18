#!/bin/sh

. /lib/functions.sh
. /lib/functions/leds.sh
. /lib/functions/apm821xx.sh

boot="$(apm821xx_get_dt_led boot)"
failsafe="$(apm821xx_get_dt_led failsafe)"
running="$(apm821xx_get_dt_led running)"
upgrade="$(apm821xx_get_dt_led upgrade)"

set_state() {
	status_led="$boot"

	case "$1" in
	preinit_regular)
		status_led_blink_preinit_regular
		;;
	preinit)
		status_led_blink_preinit
		;;
	failsafe)
		status_led_off
		[ -n "$running" ] && {
			status_led="$running"
			status_led_off
		}
		status_led="$failsafe"
		status_led_blink_failsafe
		;;
	upgrade)
		[ -n "$running" ] && {
			status_led="$upgrade"
			status_led_blink_preinit_regular
		}
                ;;
	done)
		status_led_off
		[ -n "$running" ] && {
			status_led="$running"
			status_led_on
		}
		;;
	esac
}
