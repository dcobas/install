#!/bin/sh

DEVICE_NAME=NULL
DRIVER_NAME=NULL
TRANSFER=/etc/transfer.ref
MAKEDEVS="y"

OUTPUT=":"
RUN=""
while getopts hvnbD:d:t: o
do	case $o in
	v)	OUTPUT="echo" ;;		# verbose
	n)	RUN=":" OUTPUT="echo" ;;	# dry run
	b)	MAKEDEVS="n" ;;			# omit devnode creation
	D)	DEVICE_NAME="$OPTARG" ;;
	d)	DRIVER_NAME="$OPTARG" ;;
	t)	TRANSFER="$OPTARG" ;;
	[h?])	echo >&2 "usage: $0 [-?hvnb] [-D device] [-d driver] [-t transfer]"
		echo >&2 "	-h, -?		: help"
		echo >&2 "	-v		: verbose"
		echo >&2 "	-n		: dry-run, do not do anything (implies -v)"
		echo >&2 "	-b		: do not make device nodes"
		echo >&2 "	-D device	: hardware device name (e.g. VD80)"
		echo >&2 "	-d device	: driver name (e.g. vd80)"
		echo >&2 "	-t transfer	: transfer.ref file to use (default: /etc/transfer.ref)"
		exit ;;
	esac
done

$OUTPUT "Installing $DEVICE_NAME driver..."
INSMOD_ARGS=`awk -f transfer2insmod.awk $DEVICE_NAME $TRANSFER`
if [ x"$INSMOD_ARGS" == x"" ] ; then
    echo >&2 "No $DEVICE_NAME declared in $TRANSFER, exiting"
    exit 1
fi

INSMOD_CMD="insmod $DRIVER_NAME.ko $INSMOD_ARGS"
$OUTPUT installing $DRIVER_NAME by $INSMOD_CMD
sh -c "$RUN $INSMOD_CMD"

if [ x"$MAKEDEVS" == x"n" ] ; then
    exit 0
fi

MAJOR=`cat /proc/devices | awk '$2 == "'"$DRIVER_NAME"'" {print $1}'`
MINORS=`awk '/^#\+#/ && $6 == "'"$DEVICE_NAME"'" { printf("%s ", $7) }' $TRANSFER`
$OUTPUT "creating device nodes for driver $DRIVER_NAME, major $MAJOR, minors $MINORS"

if [ -z "$MAJOR" ]; then
	echo >&2 "driver $DRIVER_NAME not installed!"
	echo >&2 "command line [$INSMOD_CMD]"
	exit 1
fi
for MINOR in $MINORS; do
    sh -c "$RUN rm -f /dev/$DRIVER_NAME.$MINOR"
    sh -c "$RUN mknod /dev/$DRIVER_NAME.$MINOR c $MAJOR $MINOR"
done
