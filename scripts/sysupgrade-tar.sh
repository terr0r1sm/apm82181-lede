#!/bin/sh

dtname=""
board=""
kernel=""
rootfs=""
outfile=""
images=""
err=""

while [ "$1" ]; do
	case "$1" in
	"--board")
		board="$2"
		shift
		shift
		continue
		;;
	"--dtname")
		dtname="$2"
		shift
		shift
		continue
		;;
	"--kernel")
		kernel="$2"
		shift
		shift
		continue
		;;
	"--rootfs")
		rootfs="$2"
		shift
		shift
		continue
		;;
	*)
		if [ ! "$outfile" ]; then
			outfile=$1
			shift
			continue
		fi
		;;
	esac
done

if [ ! -n "$board" -a ! -n "$dtname" ] && [ ! -r "$kernel" -a  ! -r "$rootfs" -o ! "$outfile" ]; then
	echo "syntax: $0 [--board boardname] [--dtname dtname] [--kernel kernelimage] [--rootfs rootfs] out"
	exit 1
fi

tmpdir="$( mktemp -d 2> /dev/null )"
if [ -z "$tmpdir" ]; then
	# try OSX signature
	tmpdir="$( mktemp -t 'ubitmp' -d )"
fi

if [ -z "$tmpdir" ]; then
	exit 1
fi

[ -z "${board}" ] || {
	mkdir -p "${tmpdir}/sysupgrade-${board}"
	echo "BOARD=${board}" > "${tmpdir}/sysupgrade-${board}/CONTROL"
	[ -z "${rootfs}" ] || cp "${rootfs}" "${tmpdir}/sysupgrade-${board}/root"
	[ -z "${kernel}" ] || cp "${kernel}" "${tmpdir}/sysupgrade-${board}/kernel"
	images+="sysupgrade-${board}"
}

[ -z "${dtname}" ] || {
	mkdir -p "${tmpdir}/sysupgrade-${dtname}"
	echo "BOARD=${dtname}" > "${tmpdir}/sysupgrade-${dtname}/CONTROL"
	if [ -z "${board}" ]; then
		[ -z "${rootfs}" ] || cp "${rootfs}" "${tmpdir}/sysupgrade-${dtname}/root"
		[ -z "${kernel}" ] || cp "${kernel}" "${tmpdir}/sysupgrade-${dtname}/kernel"
	else
		[ -z "${rootfs}" ] || ln -s "../sysupgrade-${board}/root" "${tmpdir}/sysupgrade-${dtname}/root"
		[ -z "${kernel}" ] || ln -s "../sysupgrade-${board}/kernel" "${tmpdir}/sysupgrade-${dtname}/kernel"
	fi
	images+=" sysupgrade-${dtname}"
}

mtime=""
if [ -n "$SOURCE_DATE_EPOCH" ]; then
	mtime="--mtime=@${SOURCE_DATE_EPOCH}"
fi

(cd "$tmpdir"; tar cvf sysupgrade.tar ${images} ${mtime})
err="$?"
if [ -e "$tmpdir/sysupgrade.tar" ]; then
	cp "$tmpdir/sysupgrade.tar" "$outfile"
else
	err=2
fi
rm -rf "$tmpdir"

exit $err
