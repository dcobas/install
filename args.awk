{
	lun   = sprintf("%s,%d", lun, $1)
	bus   = sprintf("%s,0x%x", bus, $2)
	devfn = sprintf("%s,0x%x", devfn, $3)
}
END {
	lun   = substr(lun, 2)
	bus   = substr(bus, 2)
	devfn = substr(devfn, 2)
	printf("lun=%s pci-bus=%s pci-devfn=%s\n", lun, bus, devfn)					\
}
