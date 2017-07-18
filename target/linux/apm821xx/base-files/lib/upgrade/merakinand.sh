#!/bin/sh
#
# Copyright (C) 2016 Chris Blake <chrisrblake93@gmail.com>
#
# Custom upgrade script for Meraki NAND devices (ex. MR24)
# Based on merakinand.sh from the ar71xx target
#
. /lib/functions.sh

merakinand_do_kernel_check() {
	local board_name="$1"
	local tar_file="$2"
	local kernelfile=`/usr/lib/tar-sym.sh $tar_file sysupgrade-$board_name/kernel`
	local image_magic_word=`(tar Oxf $tar_file $kernelfile 2>/dev/null | dd bs=1 count=4 skip=0 2>/dev/null | hexdump -v -n 4 -e '1/1 "%02x"')`

	# What is our kernel magic string?
	case "$board_name" in
	"meraki,ikarem"|\
	"meraki,buckminster")
		[ "$image_magic_word" == "8e73ed8a" ] && {
			echo "pass" && return 0
		}
		;;
	esac

	exit 1
}

merakinand_do_platform_check() {
	local board_name="$1"
	local tar_file="$2"
	local controlfile=`/usr/lib/tar-sym.sh $tar_file sysupgrade-$board_name/CONTROL`
	local rootfsfile=`/usr/lib/tar-sym.sh $tar_file sysupgrade-$board_name/root`
	local control_length=`(tar Oxf $tar_file $controlfile | wc -c) 2> /dev/null`
	local file_type="$(identify_tar $2 $rootfsfile)"
	local kernel_magic="$(merakinand_do_kernel_check $1 $2)"

	case "$board_name" in
	"meraki,ikarem"|\
	"meraki,buckminster")
		[ "$control_length" = 0 -o "$file_type" != "squashfs" -o "$kernel_magic" != "pass" ] && {
			echo "Invalid sysupgrade file for $board_name"
			return 1
		}
		;;
	*)
		echo "Unsupported device $board_name";
		return 1
		;;
	esac

	return 0
}

merakinand_do_upgrade() {
	local tar_file="$1"
	local board_name="$(board_name)"

	# Do we need to do any platform tweaks?
	case "$board_name" in
	"meraki,ikarem"|\
	"meraki,buckminster")
		nand_do_upgrade $1
		;;
	*)
		echo "Unsupported device $board_name";
		exit 1
		;;
	esac
}
