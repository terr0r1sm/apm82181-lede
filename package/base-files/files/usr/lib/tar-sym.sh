#!/bin/sh
#
# Copyright (c) 2017 Christian Lamparter <chunkeey@googlemail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 2.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# For a version with a lot more functions and comments,
# visit: <https://github.com/chunkeey/tar-sym>

MAX_INDIRECTIONS=${MAX_INDIRECTIONS:-40}

tar_file=
die() {
	>&2 echo "$@"
	exit 1
}

get_tar() {
	( dd if="$tar_file" skip="$1" bs=1 count="$2" 2>/dev/null | strings -n 1 | head -1 )
}

offset=0
name=
type=
size=

# TAR header parser - Assume that TAR Blocksize is 512.
get_tar_header() {
	[[ "$offset" -ge "$tar_size" ]] && return 1

	local magic_off=$(($offset+257))

	[[ "$(get_tar $magic_off 7)" == "ustar  " ]] && {
		local name_off=$(($offset+0))
	        local type_off=$(($offset+156))
		local link_off=$(($offset+157))
		local size_off=$(($offset+124))

		type="$(get_tar $type_off 1)"
		size="$(get_tar $size_off 12)"

		size=$(printf '%d' $size)

		offset=$(( $offset + ( ($size + 511) / 512 + 1) * 512 ))

		[ "$type" == "2" ] && link="$(get_tar $link_off 100)"

                name="$(get_tar $name_off 100)"
		tar_finished=0
	} || {
		tar_finished=1
	}
}

arrayindex=0
nextarrayindex=0

addarray() {
	arrayindex=$nextarrayindex
	eval arrayname_$arrayindex="$1"
	eval arraytype_$arrayindex="$2"
	eval arrayoffset_$arrayindex="$3"
	eval arraysize_$arrayindex="$4"
	eval arraylink_$arrayindex="$5"
	nextarrayindex=$(($nextarrayindex+1))
}

lookup_array() {
	local tmp
	local i
	for i in $(seq 0 $arrayindex); do
		eval tmp="\$arrayname_$i"
		[ "$tmp" == "$1" ] && {
			echo -n $i
			break
		}
	done
}

adddir() {
	[ -z $(lookup_array "$1") ] && addarray "$1" 1 "$2" 0 0 ""
}

mapper() {
	local dirstack=
	local cleanname=
	local saved_offset=

	offset=0
	tar_finished=0

	get_tar_header

	[ "$tar_finished" -eq "1" ] && \
		die "Unable to read anything. Probably not a compatible tar."

	while [ "$tar_finished" -eq "0" ]; do

		cleanname=$name
		cleanname="${cleanname%/}"
		cleanname="${cleanname#/}"
		cleanname="${cleanname#./}"

		case "$type" in
		""|\
		"0")	# File
			addarray "$cleanname" 0 "$saved_offset" "$size" ""
			;;
		"5")	# Directory
			dirstack=""
			OLDIFS=$IFS;IFS="/";for subdir in $cleanname; do
				IFS=$OLDIFS
				[ -z "$dirstack" ] && adddir "$subdir"
				[ -z "$dirstack" ] || adddir "$dirstack$subdir"
				dirstack="$dirstack$subdir/"
			done
			;;
		"2")	# Softlink
			link=${link%/}

			addarray "$cleanname" 2 0 0 "$link"
			;;
		"*")
			die "Found unhandled $type"
			;;
		esac

		saved_offset=$offset
		get_tar_header
	done
}

dirlevel=0
follow_link() {
	local look="$1"
	local level="$2"
	local stack=

        [ "$level" -ge "$MAX_INDIRECTIONS" ] && {
                die "Too many redirections. Giving up."
        }

	OLDIFS="$IFS";IFS="/";for pele in $look; do
		IFS="$OLDIFS"

		eval stack="\$stack_$dirlevel"
		case "$pele" in
		"..")
			[ "$dirlevel" -eq 0 ] && die "Aborting because link '$look' leaves the archive."
			dirlevel=$(( $dirlevel - 1 ))
			;;
		".")
			;;
		*)
			aid=$(lookup_array "$stack$pele")
			[ -z "$aid" ] && die "'$orig_dest' was not found in archive."

			eval type="\$arraytype_$aid"

			case "$type" in
			"0") # File
				eval filename="\$arrayname_$aid"
				echo "$filename"
				return
				;;
			"1") # Directory
				dirlevel=$(( $dirlevel + 1 ))
				eval stack_$dirlevel="$stack$pele/"
				;;
			"2") # Link
				eval [ -z \$arrayvisited_$aid ] || die "Aborting due to recursive link loop."
				eval arrayvisited_$aid=1
				eval linklink="\$arraylink_$aid"
				follow_link "$linklink" $(( $level + 1 )) "$dirlevel"
				;;
			*)
				die "Internal error"
				;;
			esac
		esac
	done
}

[ "$#" -eq "2" ] || die "Syntax: $0 tarfile.tar path/to/possibly/symlinked/file"

[ -r "$1" ] || {
	die "file: $1 not accessible"
}

orig_dest="$2"
clean_dest="${2%/}"
clean_dest="${clean_dest#./}"
tar_file="$1"
tar_size=$(cat "$tar_file" | wc -c)

mapper

follow_link "$clean_dest" "0"
