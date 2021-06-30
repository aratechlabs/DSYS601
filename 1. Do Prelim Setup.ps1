Set-ExecutionPolicy -ExecutionPolicy Unrestricted
# Add S drive mapping for all PowerShell shells into default PowerShell profile file.
if ( -not ( test-path C:\Temp )) {
    mkdir C:\Temp
}
if (-not (Test-Path c:\temp\InstallStatus.txt)) {
    echo "1" > C:\Temp\InstallStatus.txt
}
if ((get-content c:\temp\InstallStatus.txt) -eq "1") {

    if ( -not ( test-path -PathType Container -Path S:\ ) ) {
        New-PSDrive -Name S -PSProvider FileSystem -Root \\fp01\Staff -persist
    }

    if ( -not ( test-path C:\Users\$env:USERNAME\Documents\WindowsPowerShell )) {
        mkdir C:\Users\$env:USERNAME\Documents\WindowsPowerShell
    }

    copy-item "S:\Deploy\profile.ps1" -Destination "C:\Users\$env:USERNAME\Documents\WindowsPowerShell"
    gci C:\Users\$env:USERNAME\Documents\WindowsPowerShell

    # Disable Hibernation
    powercfg -h off
    
    # Configure TLS1.2 with strong security
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord


    # Install PowerShell modules for Windows Update.
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$False
    Install-Module PSWindowsUpdate -Force -Confirm:$False
    Get-Command –module PSWindowsUpdate -Force -Confirm:$False
    Add-WUServiceManager -ServiceID 7971f918-a847-4430-9279-4a52d1efe18d -Confirm:$False

    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module chocolatey -Force
    choco feature enable -n allowGlobalConfirmation

    choco source add -n=Internal -s="http://ChocoRepo.techlabs.lan/chocolatey"
    choco apikey -s="http://ChocoRepo.techlabs.lan/chocolatey" -k=TechlabsInstall
    choco source remove --name="'chocolatey'"
    choco config set cacheLocation $env:ALLUSERSPROFILE\choco-cache
    choco config set commandExecutionTimeoutSeconds 14400
    # Licensed Feature Only
    # choco feature enable --name="'reduceInstalledPackageSpaceUsage'"
    
    #Copy MOTD Script
    copy-item -Path S:\SysAdmin\motd\Local\motd.vbs -Destination 'C:\programdata\Microsoft\Windows\Start Menu\Programs\StartUp' -Force

    unblock-file 'S:\Deploy\2. Create VLANs on Second NIC.ps1'
    unblock-file 'S:\Deploy\3. Install VMWare Workstation.ps1'
    unblock-file 'S:\Deploy\4. Install apps and reboot.ps1'
    unblock-file 'S:\Deploy\5. Configure D Drive.ps1'
    unblock-file 'S:\Deploy\6. Configure C Drive.ps1'

    # Install Intel Network drivers.
    choco install intel-network-drivers-win10 -y -f --no-progress
    if ($LASTEXITCODE -ne 0) {
        choco install intel-network-drivers-win10 --ignore-checksums -y -f --no-progress
    }
    # Manual install from S:\Deploy\Resources\PROWinx64.exe

    # Need to reapply Network IP address as driver installation above resets addressing to DHCP.
    $IPNumber = (hostname).split("-")[1] 
    if ($IPNumber -ne "Tutor") {
        $IPNumber = $IPNumber.TrimStart("0")
    } else {
        $IPNumber = 24
    }
    $Room = (hostname).split("-")[0]
    $Subnet = $Room.Substring(2)

    get-netadapter -InterfaceAlias Blue | select ifindex | `
    New-NetIPAddress  -AddressFamily IPv4 -IPAddress 172.17.$Subnet.$IPNumber -PrefixLength 16 -DefaultGateway 172.17.0.1
      
    Set-DnsClientServerAddress -InterfaceAlias Blue -ServerAddresses {172.17.62.101,172.17.62.102}
        
    # Enable Remote Desktop and configure Firewall setting
    (Get-WmiObject Win32_TerminalServiceSetting -Namespace root\cimv2\TerminalServices).SetAllowTsConnections(1,1) | Out-Null
    # Enable NLA
    (Get-WmiObject -Class "Win32_TSGeneralSetting" -Namespace root\cimv2\TerminalServices -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(1) | Out-Null
    
    # Move PC to deploy OU to enable Windows Updates
    $PCname = hostname
    $session = new-PSsession -computername DC01
    invoke-command -Session $session -argumentlist $PCname -scriptblock { 
        param ($PCname)
        sl c:\
        import-module activedirectory
        move-adobject -identity (get-adcomputer $PCname).objectguid -TargetPath 'ou=Deploy,dc=techlabs,dc=lan'
        exit
    }
    Set-Service wuauserv -StartupType Manual -Status Running
    get-windowsupdate -Install -AcceptAll -IgnoreReboot
    echo "1A" > C:\Temp\InstallStatus.txt
    restart-computer -force
 
 } elseif ((Get-Content c:\Temp\InstallStatus.txt) -eq "1A") {

    get-windowsupdate -Install -AcceptAll -IgnoreReboot
    $NumberOfUpdatesToApply = @(Get-WUList -MicrosoftUpdate).Count
    if ($NumberofUpdatesToApply -eq 0) {
        echo "2" > C:\Temp\InstallStatus.txt
    }
   Restart-Computer -force
} 
$PCname = hostname
$Room = $PCname.Split("-")[0]
$session = new-PSsession -computername DC01
invoke-command -Session $session -argumentlist $PCname,$Room -scriptblock { 
    param ($PCname, $Room)
    sl c:\
    import-module activedirectory
    move-adobject -identity (get-adcomputer $PCname).objectguid -TargetPath 'ou=$Room,ou=Workstations,dc=techlabs,dc=lan'
    exit
}

Set-Service wuauserv -StartupType Disabled -Status Stopped
  
. 'S:\Deploy\2. Create VLANs on Second NIC.ps1'
