#!/bin/sh

DEVICE_NAME=MOD-PCI
TRANSFER=/etc/transfer.ref
CRATECONFIG=/etc/crateconfig
TEMPFILE=/tmp/install-pci.tmp.`date +%s`

OUTPUT=":"
RUN=""
while getopts hvnD:d:t:c: o
do	case $o in
	v)	OUTPUT="echo" ;;		# verbose
	n)	RUN=":" ;;			# dry run
	D)	DEVICE_NAME="$OPTARG" ;;
	d)	DRIVER_NAME="$OPTARG" ;;
	t)	TRANSFER="$OPTARG" ;;
	c)	CRATECONFIG="$OPTARG" ;;
	[h?])	echo >&2 "usage: $0 [-?hvn] [-D device] [-d driver] [-t transfer] [-c crateconfig]"
		exit ;;
	esac
done

$OUTPUT "Installing $DEVICE_NAME driver..."

# generate phys-slot -> lun table
awk '/^#\+#/ && $4 == "PCI" && $6 == "'${DEVICE_NAME}'" {
		printf("%d %d\n", $20, $7)
}' ${TRANSFER} | sort -n > $TEMPFILE

if [ ! -s ${TEMPFILE} ] ; then
    echo "No $DEVICE_NAME declared in $TRANSFER, exiting"
    exit 1
fi

# join phys->slot lun with lun -> pci-bus pci-slot
INSMOD_ARGS=`sort -k1 ${CRATECONFIG} | 
join -o '1.2 2.2 2.3' ${TEMPFILE} - | 
awk '
{
	lun   = sprintf("%s,%d", lun, $1+1)
	bus   = sprintf("%s,%s", bus, $2)
	devfn = sprintf("%s,0x%s", devfn, $3)
}
END {
	lun   = substr(lun, 2)
	bus   = substr(bus, 2)
	devfn = substr(devfn, 2)
	printf("bcs=%s pci-buses=%s pci-slots=%s\n", lun, bus, devfn)
}'`

INSMOD_CMD="insmod $DRIVER_NAME.ko $INSMOD_ARGS"
$OUTPUT installing $DRIVER_NAME by $INSMOD_CMD
sh -c "$RUN $INSMOD_CMD"

MAJOR=`cat /proc/devices | awk '$2 == "'"$DRIVER_NAME"'" {print $1}'`
if [ -z "$MAJOR" ]; then
	echo "driver $DRIVER_NAME not installed!"
	exit 1
fi
MINORS=`awk '/^#\+#/ && $6 == "'"$DEVICE_NAME"'" { printf("%s ", $7) }' $TRANSFER`
$OUTPUT "creating device nodes for driver $DRIVER_NAME, major $MAJOR, minors $MINORS"
for MINOR in $MINORS; do
    sh -c "$RUN rm -f /dev/$DRIVER_NAME.$MINOR"
    sh -c "$RUN mknod /dev/$DRIVER_NAME.$MINOR c $MAJOR $MINOR"
done
