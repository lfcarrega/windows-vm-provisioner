$computer = Get-CimInstance Win32_ComputerSystem | Select-Object `
    Name, Manufacturer, Model, TotalPhysicalMemory

$cpu = Get-CimInstance Win32_Processor | Select-Object `
    Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed

$disks = Get-CimInstance Win32_DiskDrive | Select-Object `
    Model, Size, SerialNumber, InterfaceType, MediaType

$board = Get-CimInstance Win32_BaseBoard | Select-Object `
    SerialNumber, Manufacturer, Product

$bios = Get-CimInstance Win32_BIOS | Select-Object `
    SerialNumber, Manufacturer, SMBIOSBIOSVersion

$adapters = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object {
    $_.IPAddress -ne $null
}

$adapters = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object {
    $_.IPAddress -ne $null
}

$network = foreach ($adapter in $adapters) {
    $ipv4Index = 0..($adapter.IPAddress.Count - 1) | Where-Object {
        $adapter.IPAddress[$_] -notmatch ":"
    } | Select-Object -First 1

    $ipv6Index = 0..($adapter.IPAddress.Count - 1) | Where-Object {
        $adapter.IPAddress[$_] -match ":" -and $adapter.IPAddress[$_] -notmatch "^fe80"
    } | Select-Object -First 1

    [PSCustomObject]@{
        Description    = $adapter.Description
        IPv4Address    = if ($ipv4Index -ne $null) { $adapter.IPAddress[$ipv4Index] } else { $null }
        SubnetMask     = if ($ipv4Index -ne $null) { $adapter.IPSubnet[$ipv4Index] } else { $null }
        IPv6Address    = if ($ipv6Index -ne $null) { $adapter.IPAddress[$ipv6Index] } else { $null }
        IPv6Prefix     = if ($ipv6Index -ne $null) { $adapter.IPSubnet[$ipv6Index] } else { $null }
        Gateway        = ($adapter.DefaultIPGateway | Where-Object { $_ -notmatch ":" }) -join ","
        Gateway6       = ($adapter.DefaultIPGateway | Where-Object { $_ -match ":" -and $_ -notmatch "^fe80" }) -join ","
        MacAddress     = $adapter.MACAddress
        DNSServers     = $adapter.DNSServerSearchOrder -join ","
        DHCPEnabled    = $adapter.DHCPEnabled
        HasIPv4        = $ipv4Index -ne $null
    }
}

$hostname = $env:COMPUTERNAME

$inventory = [PSCustomObject]@{
    Hostname = $hostname
    Computer = $computer
    Cpu      = $cpu
    Disks    = $disks
    Board    = $board
    Bios     = $bios
    Network  = $network
    Timestamp = (Get-Date).ToString("o")
}

$inventory | ConvertTo-Json -Depth 5