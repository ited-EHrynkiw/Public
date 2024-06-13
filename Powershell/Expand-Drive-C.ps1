# Open PowerShell as Administrator and run this script
# ** Will Only Work If the C: Partition is at the End **


# Get the disk containing the C: drive
$disk = Get-Partition -DriveLetter C | Get-Disk
# Get the partition to be resized (C: drive)
$partition = Get-Partition -DriveLetter C
# Resize the partition to occupy all available space
Resize-Partition -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber -Size ((Get-PartitionSupportedSize -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber).SizeMax)

Write-Host "C: drive has been resized to full capacity."
