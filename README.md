# bios-storage-check

bios-storage-check is a small Windows tool written in AutoIt that helps you figure out how your storage is presented to Windows. It gives a best‑effort BIOS storage mode guess, AHCI versus Intel RST or VMD style setups, by looking at controller names and active driver services, and it detects whether your physical disk bus is NVMe or SATA using Windows Storage data.

In real life this comes up more than people think. It helps when you are about to reinstall Windows and you want to avoid the classic “Windows installer cannot see my drive” situation that happens on some systems with Intel RST or VMD enabled. It is also useful right before cloning or imaging a machine, because storage mode mismatches and controller drivers can break a migration. It helps when a SMART or NVMe tool shows nothing or shows the drive in a weird way, which can happen when the disk is presented behind a controller. It is handy in support tickets too, because you can copy the output and immediately show what drivers are actually active, what Windows thinks the disk bus is, and whether any RAID style presentation is involved.

To use it, run the script, or a compiled EXE if you build one. The window shows a one‑line Top Summary and then a detailed report. Click “Copy Output” to paste it into a ticket or share it for troubleshooting, or “Save TXT” to export a report file.

For developers, open the .au3 in SciTE or AutoIt and run or compile with AutoIt3Wrapper. The detection is based on Windows visible signals, so it cannot read a BIOS or UEFI toggle directly on all systems, it is an inference that is usually accurate for practical support work, and it is designed to make odd cases obvious in the output, like RST or VMD masking NVMe, disks showing BusType RAID, or iaStor drivers being active even when the controller name still says AHCI.

