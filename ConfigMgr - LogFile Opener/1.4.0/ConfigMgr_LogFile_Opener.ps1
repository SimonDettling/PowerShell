<#
.SYNOPSIS
    Provides simple access to the ConfigMgr Client Logs using CMTrace or CMLogViewer
.DESCRIPTION
    Provides simple access to the ConfigMgr Client Logs using CMTrace or CMLogViewer
.PARAMETER CMTrace
    Specify the Path to CMTrace.exe
.PARAMETER CMLogViewer
    Specify the Path to CMLogViewer.exe
.PARAMETER Hostname
    Specify a Default hostname for direct connection. Otherwise the Tool will prompt you to specify a hostname.
.PARAMETER ClientLogFilesDir
    Specify the directory in which the ConfigMgr Client LogFiles are located. (e.g: "Program Files\CCM\Logs")
.PARAMETER DisableLogFileMerging
    If specified, the LogFiles won't get merged by CMTrace
.PARAMETER WindowStyle
    Specify the Window Style of CMTrace and File Explorer. Default value is 'normal'
.PARAMETER CMTraceActionDelay
    Specify the amount of time in milliseconds, the Script should wait between the Steps when opening multiple LogFiles in CMTrace. Default value is 1500
.PARAMETER ActiveLogProgram
    Specify which Log Program should be active when the tool is starting. Default value is 'CMTrace'
.PARAMETER DisableHistoryLogFiles
    If specified, the Tool won't open any history log files
.EXAMPLE
    .\ConfigMgr_LogFile_Opener.ps1 -CMTrace 'C:\temp\CMTrace.exe' -Hostname 'PC01' -ClientLogFilesDir 'Program Files\CCM\Logs' -DisableLogFileMerging -WindowStyle Maximized
    .\ConfigMgr_LogFile_Opener.ps1 -CMLogViewer 'C:\temp\CMLogViewer.exe' -Hostname 'PC02' -CMTraceActionDelay 2000 -DisableHistoryLogFiles -ActiveLogProgram CMLogViewer 
.NOTES
    Script name:   ConfigMgr_LogFile_Opener.ps1
    Author:        @SimonDettling <msitproblog.com>
    Date modified: 2017-05-17
    Version:       1.4.0
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$false, HelpMessage='Specify the hostname for direct connection. Otherwise the Tool will prompt you to specify a hostname.')]
    [String] $Hostname = '',

    [Parameter(Mandatory=$false, HelpMessage='Specify the Path to CMTrace.exe')]
    [String] $CMTrace = 'C:\Windows\CMTrace.exe',

    [Parameter(Mandatory=$false, HelpMessage='Specify the Path to CMLogViewer.exe')]
    [String] $CMLogViewer = 'C:\Program Files (x86)\Configuration Manager Support Center\CMLogViewer.exe',

    [Parameter(Mandatory=$false, HelpMessage='Specify the directory in which the ConfigMgr Client Logfiles are located. (e.g: "Program Files\CCM\Logs")')]
    [String] $ClientLogFilesDir = 'C$\Windows\CCM\Logs',

    [Parameter(Mandatory=$false, HelpMessage="If specified, the LogFiles won't get merged by CMTrace")]
    [Switch] $DisableLogFileMerging,

    [Parameter(Mandatory=$false, HelpMessage="Specify the Window Style of CMTrace and File Explorer. Default value is 'normal'")]
    [ValidateSet('Minimized', 'Maximized', 'Normal')]
    [String] $WindowStyle = 'Normal',

    [Parameter(Mandatory=$false, HelpMessage="Specify the amount of time in milliseconds, the Script should wait between the Steps when opening multiple LogFiles in CMTrace. Default value is 1500")]
    [Int] $CMTraceActionDelay = 1500,

    [Parameter(Mandatory=$false, HelpMessage="Specify which Log Program should be active when the tool is starting. Default value is 'CMTrace'")]
    [ValidateSet('CMTrace', 'CMLogViewer')]
    [String] $ActiveLogProgram = 'CMTrace',

    [Parameter(Mandatory=$false, HelpMessage="If specified, the Tool won't open any history log files")]
    [Switch] $DisableHistoryLogFiles
)

# Add Visual Basic Assembly for displaying message popups
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null 

# Create Shell Object, for handling CMTrace Inputs. (Usage of the .NET Classes led to CMTrace Freezes.)
$shellObj = New-Object -ComObject WScript.Shell

# Contains the information if the connected device is remote or local
$hostnameIsRemote = $true

$logfileTable = @{
    'ccmsetup' = @{
        'path' = 'C$\Windows\ccmsetup\Logs'
        'logfiles' = @('ccmsetup.log')
    }
    'ccmupdate' = @{
        'path' = $clientLogfilesDir
        'logfiles' = @('ScanAgent.log', 'UpdatesDeployment.log', 'UpdatesHandler.log', 'UpdatesStore.log', 'WUAHandler.log')
    }
    'winupdate' = @{
        'path' = 'C$\Windows'
        'logfiles' = @('WindowsUpdate.log')
    }
    'ccmappdiscovery' = @{
        'path' = $clientLogfilesDir
        'logfiles' = @('AppDiscovery.log')
    }
    'ccmappenforce' = @{
        'path' = $clientLogfilesDir
        'logfiles' = @('AppEnforce.log')
    }
    'ccmexecmgr' = @{
        'path' = $clientLogfilesDir
        'logfiles' = @('execmgr.log')
    }
    'ccmexec' = @{
        'path' = $clientLogfilesDir
        'logfiles' = @('CcmExec.log')
    }
    'ccmstartup' = @{
        'path' = $clientLogfilesDir
        'logfiles' = @('ClientIDManagerStartup.log')
    }
    'ccmpolicy' = @{
        'path' = $clientLogfilesDir
        'logfiles' = @('PolicyAgent.log', 'PolicyAgentProvider.log', 'PolicyEvaluator.log', 'StatusAgent.log')
    }
    'ccmepagent' = @{
        'path' = $clientLogfilesDir
        'logfiles' = @('EndpointProtectionAgent.log')
    }
    'ccmdownload' = @{
        'path' = $clientLogfilesDir
        'logfiles' = @('CAS.log', 'CIDownloader.log', 'DataTransferService.log')
    }
    'ccmeval' = @{
        'path' = $clientLogfilesDir
        'logfiles' = @('CcmEval.log')
    }
    'ccminventory' = @{
        'path' = $clientLogfilesDir
        'logfiles' = @('InventoryAgent.log', 'InventoryProvider.log')
    }
    'ccmsmsts' = @{
        'path' = $clientLogfilesDir
        'logfiles' = @('smsts.log')
    }
    'ccmstatemessage' = @{
        'path' = $clientLogfilesDir
        'logfiles' = @('StateMessage.log')
    }
    'winservicing' = @{
        'path' = 'C$\Windows\Panther'
        'logfiles' = @('setupact.log', 'setuperr.log')
    }
}

$ccmBuildNoTable = @{
    '7711' = '2012 RTM';
    '7804' = '2012 SP1';
    '8239' = '2012 SP2 / R2 SP1';
    '7958' = '2012 R2 RTM';
    '8325' = 'CB 1511';
    '8355' = 'CB 1602';
    '8412' = 'CB 1606';
    '8458' = 'CB 1610';
    '8498' = 'CB 1702';
}

Function Open-LogFile ([String] $Action) {
    # Get action from Hash Table, and throw error if it does not exist
    $actionHandler = $logfileTable.GetEnumerator() | Where-Object {$_.Key -eq $action}
    If (!$actionHandler) {
        Invoke-MessageBox -Message "Action '$action' can not be found in Hash Table"
        Invoke-MainMenu
    }

    # Assign values from Hash Table
    $logfilePath = "\\$hostname\$($actionHandler.Value.path)"
    $logfiles = $actionHandler.Value.logfiles

    # Check if logfile path  is accessible
    If (!(Test-Path -Path $logfilePath)) {
        Invoke-MessageBox -Message "'$logfilePath' is not accessible!"
        Invoke-MainMenu
    }

    If ($ActiveLogProgram -eq 'CMTrace') {
        Invoke-CMTrace -Path $logfilePath -Files $logfiles
    }
    ElseIf ($ActiveLogProgram -eq 'CMLogViewer') {
        Invoke-CMLogViewer -Path $logfilePath -Files $logfiles
    }

    Invoke-MainMenu
}

Function Invoke-CMTrace ([String] $Path, [Array] $Files, [Switch] $DisableFirstStartCheck) {
    # Check if CMTrace exists
    If (!(Test-Path -Path $cmtrace)) {
        Invoke-MessageBox -Message "'$cmtrace' is not accessible!"
        Invoke-MainMenu
    }

    # Check if CMTrace was started at least once. This is needed to make sure that the initial FTA PopUp doesn't appear.
    If (!(Test-Path -Path 'HKCU:\Software\Microsoft\Trace32') -and !$disableFirstStartCheck) {
        Invoke-MessageBox -Message "CMTrace needs be started at least once. Click 'OK' to launch CMTrace, confirm all dialogs and try again." -Icon 'Exclamation'
        
        # Empty files array to start a single CMTrace Instance
        $files = @()
    }

    # Write current path in Registry
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Trace32' -Value $path -Name 'Last Directory' -Force

    # Check if multiple files were specified
    If ($files.Count -gt 1) {
        # Start CMTrace and wait until it's open
        Start-Process -FilePath $cmtrace
        Start-Sleep -Milliseconds $cmtraceActionDelay

        # Send CTRL+O to open the open file dialog
        $shellObj.SendKeys('^o')
        Start-Sleep -Milliseconds $cmtraceActionDelay

        # Write logfiles name in CMTrace format, "Log1" "Log2" "Log3" etc.
        $shellObj.SendKeys('"' + [String]::Join('" "', $files) + '"')

        # check if logfile merging is not disabled
        If (!$disableLogfileMerging) {
            # Navigate to Merge checkbox and enable it
            $shellObj.SendKeys('{TAB}{TAB}{TAB}{TAB}{TAB}')
            $shellObj.SendKeys(' ')
        }

        # Send ENTER
        $shellObj.SendKeys('{ENTER}')

        # Wait until log file is loaded
        Start-Sleep -Milliseconds $cmtraceActionDelay

        # Send CTRL + END to scroll to the bottom
        $shellObj.SendKeys('^{END}')

        # Set Empty path in registry
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Trace32' -Value '' -Name 'Last Directory' -Force
    }
    # Check if one file was specified
    ElseIf ($files.Count -eq 1) {
        # Build full logfile path
        $fullLogfilePath = $path + '\' + [String]::Join(" ", $files)

        # Check if Logfile exists
        If (!(Test-Path -Path $fullLogfilePath)) {
            Invoke-MessageBox -Message "'$fullLogfilePath' is not accessible!"
            Invoke-MainMenu
        }

        # Open Logfile in CMTrace
        Start-Process -FilePath $cmtrace -ArgumentList $fullLogfilePath

        # Wait until log file is loaded
        Start-Sleep -Milliseconds $cmtraceActionDelay

        # Send CTRL + END to scroll to the bottom
        $shellObj.SendKeys('^{END}')

        # Set Empty path in registry
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Trace32' -Value '' -Name 'Last Directory' -Force
    }
    # Check if no file was specified
    Else {
        # Open CMTrace
        Start-Process -FilePath $cmtrace
    }

    # Check WindowStyle. NOTE: CMTrace can't be launched using the native 'WindowStyle' Attribute via Start-Process above.
    Switch ($windowStyle) {
        'Minimized' {$shellObj.SendKeys('% n')}
        'Maximized' {$shellObj.SendKeys('% x')}
    }

}

Function Invoke-CMLogViewer ([String] $Path, [Array] $Files) {
    # Check if CMLogViewer exists
    If (!(Test-Path -Path $cmLogViewer)) {
        Invoke-MessageBox -Message "'$cmLogViewer' is not accessible!"
        Invoke-MainMenu
    }
    # Check if log files were specified
    If ($Files -gt 1) {
        # Check if History Logfiles are disabled
        If (!$disableHistoryLogFiles) {
            $discoveredFiles = @()
            # Go through each log file
            foreach ($file in $files) {
                # Search for history log files
                Get-ChildItem -Path $path -Filter ('*' + $file.TrimEnd('.log') + '*') | ForEach-Object {
                    $discoveredFiles += $_.Name
                }
            }
            
            # assign new log files array
            $files = $discoveredFiles
        }

        # Build full logfile path: "Path\Log1" "Path\Log2" "Path\Log3" etc.
        foreach ($file in $files) {
            $fullLogfilePath += '"' + $Path + '\' + $file + '" '
        }

        # Open Logfile in CMLogViewer
        Start-Process -FilePath $cmLogViewer -ArgumentList $fullLogfilePath -WindowStyle $windowStyle
    }
    # Check if no files were specified
    Else {
        # Open CMLogViewer
        Start-Process -FilePath $cmLogViewer -WindowStyle $windowStyle
    }
}


Function Open-Path ([String] $Path) {
    # build full path
    $logfilePath = "\\$hostname\$Path"

    # Check if path is accessible
    If (!(Test-Path -Path $logfilePath)) {
        Invoke-MessageBox -Message "'$logfilePath' is not accessible!"
    }

    # Open File explorer
    Start-Process -FilePath 'C:\Windows\explorer.exe' -ArgumentList $logfilePath -WindowStyle $windowStyle

    Invoke-MainMenu
}

Function Invoke-ClientAction([String[]] $Action) {
    Try {
        # Set ErrorActionPreference stop stop, otherwise Try/Catch won't have an effect on Invoke-WmiMethod
        $ErrorActionPreference = 'Stop'

        foreach ($singleAction in $action) {
            # Trigger specified WMI Method on Client. Note: Invoke-Cim Command doesn't work here --> Error 0x8004101e
            If ($hostnameIsRemote) {
                Invoke-WmiMethod -ComputerName $hostname -Namespace 'root\CCM' -Class 'SMS_Client' -Name 'TriggerSchedule' -ArgumentList ('{' + $singleAction + '}') | Out-Null
            }
            Else {
                Invoke-WmiMethod -Namespace 'root\CCM' -Class 'SMS_Client' -Name 'TriggerSchedule' -ArgumentList ('{' + $singleAction + '}') | Out-Null
            }
        }

        # Display message box
        Invoke-MessageBox -Message 'The Client Action has been executed' -Icon 'Information'
    }
    Catch {
        # Display error message in case of a failure and return to the client action menu
        $errorMessage = $_.Exception.Message
        Invoke-MessageBox -Message "Unable to execute the specified Client Action.`n`n$errorMessage"
    }

    Invoke-ClientActionMenu
}

Function Invoke-MessageBox([String] $Message, [String] $Icon = 'Critical') {
    [Microsoft.VisualBasic.Interaction]::MsgBox($message, "OKOnly,MsgBoxSetForeground,$icon", 'ConfigMgr LogFile Opener') | Out-Null
}

Function Get-ClientVersionString {
    Try {
        # Get client version from WMI
        If ($hostnameIsRemote) {
            $clientVersion = Get-CimInstance -ComputerName $hostname -Namespace 'root\CCM' -ClassName 'SMS_Client' -Property 'ClientVersion' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty 'ClientVersion'
        }
        Else {
            $clientVersion = Get-CimInstance -Namespace 'root\CCM' -ClassName 'SMS_Client' -Property 'ClientVersion' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty 'ClientVersion'
        }

        # Extract build number from client version
        $ccmBuildNo = $clientVersion.Split('.')[2]

        # Get BuildNo String from hash table
        $ccmBuildNoHandler = $ccmBuildNoTable.GetEnumerator() | Where-Object {$_.Key -eq $ccmBuildNo}
        
        # Build client version string
        If ($ccmBuildNoHandler) {
            $clientVersionString = "$($ccmBuildNoHandler.Value) ($clientVersion)"
        }
        Else {
            $clientVersionString = $clientVersion
        }

        Return $clientVersionString
    }
    Catch {
        Return 'n/a'
    }
}

Function Get-OperatingSystemString {
    Try {
        # Get client version from WMI
        If ($hostnameIsRemote) {
            $cimObject = Get-CimInstance -ComputerName $hostname -ClassName 'Win32_OperatingSystem' -Property Caption,Version,OSArchitecture  -ErrorAction SilentlyContinue
        }
        Else {
            $cimObject = Get-CimInstance -ClassName 'Win32_OperatingSystem' -Property Caption,Version,OSArchitecture -ErrorAction SilentlyContinue
        }

        Return "$($cimObject.Caption.Replace('Microsoft', '').Trim()) $($cimObject.OSArchitecture) ($($cimObject.Version))"
    }
    Catch {
        Return 'n/a'
    }
}

Function Set-ActiveLogProgram {
    If ($activeLogProgram -eq 'CMTrace') {
        $activeLogProgram = 'CMLogViewer'
    }
    ElseIf ($activeLogProgram -eq 'CMLogViewer') {
        $activeLogProgram = 'CMTrace'
    }

    Invoke-MainMenu
}

Function Invoke-LogProgram {
    If ($activeLogProgram -eq 'CMTrace') {
        Invoke-CMTrace -DisableFirstStartCheck
    }
    ElseIf ($activeLogProgram -eq 'CMLogViewer') {
        Invoke-CMLogViewer
    }

    Invoke-MainMenu
}

Function Write-MenuHeader {
    Clear-Host
    Write-Output '###########################################################'
    Write-Output '#                                                         #'
    Write-Output '#                ConfigMgr LogFile Opener                 #'
    Write-Output '#                          1.4.0                          #'
    Write-Output '#                     msitproblog.com                     #'
    Write-Output '#                                                         #'
    Write-Output '###########################################################'
    Write-Output ''
}

Function Invoke-MainMenu ([switch] $ResetHostname, [switch] $FirstLaunch) {
    # Reset Hostname if needed
    If ($resetHostname) {
        $hostname = ''
    }

    If ($hostname -eq '') {
        # Get targeted Computer
        Write-MenuHeader
        $hostname = (Read-Host -Prompt 'Enter name of Device').ToUpper()

        # Assign local hostname if no hostname was specified
        If ($hostname -eq '') {
            $hostname = ($env:COMPUTERNAME).ToUpper()

            # Notify user about the assignment of the local hostname
            Invoke-MessageBox -Message "The local device name '$hostname' has been assigned." -Icon 'Information'
        }
    }

    # Perform the following checks / tasks only if the hostname was changed or on first launch
    If ($resetHostname -or $firstLaunch) {
        If ([System.Uri]::CheckHostName($hostname) -eq 'Unknown') {
            Invoke-MessageBox -Message "The specified Device name '$hostname' is not valid."
            Invoke-MainMenu -ResetHostname
        }

        # Check if host is online
        If (!(Test-Path -Path "\\$hostname\C$")) {
            Invoke-MessageBox -Message "The specified Device '$hostname' is not accessible."
            Invoke-MainMenu -ResetHostname
        }

        # Check if the specified host is the local device
        If ($hostname.Split('.')[0] -eq $env:COMPUTERNAME) {
            $hostnameIsRemote = $false
        }
        Else {
            $hostnameIsRemote = $true
        }

        # Get Client Version from specified Device
        $clientVersionString = Get-ClientVersionString

        # Get Operating System from specified Device
        $osString = Get-OperatingSystemString
    }

    # Write main Menu
    Write-MenuHeader
    Write-Output "Connected Device: $hostname"
    Write-Output "Operating System: $osString"
    Write-Output "ConfigMgr Client: $clientVersionString"
    Write-Output ''
    Write-Output '--- Logs --------------------------------------------------'
    Write-Output '[1] ccmsetup.log'
    Write-Output '[2] ScanAgent.log, Updates*.log, WUAHandler.log'
    Write-Output '[3] AppDiscovery.log'
    Write-Output '[4] AppEnforce.log'
    Write-Output '[5] execmgr.log'
    Write-Output '[6] CcmExec.log'
    Write-Output '[7] ClientIDManagerStartup.log'
    Write-Output '[8] Policy*.log, StatusAgent.log'
    Write-Output '[9] EndpointProtectionAgent.log'
    Write-Output '[10] CAS.log, CIDownloader.log, DataTransferService.log'
    Write-Output '[11] CcmEval.log'
    Write-Output '[12] InventoryAgent.log, InventoryProvider.log'
    Write-Output '[13] smsts.log'
    Write-Output '[14] StateMessage.log'
    Write-Output '[15] WindowsUpdate.log'
    Write-Output '[16] setupact.log, setuperr.log'
    Write-Output ''
    Write-Output '--- File Explorer -----------------------------------------'
    Write-Output '[50] C:\Windows\CCM\Logs'
    Write-Output '[51] C:\Windows\ccmcache'
    Write-Output '[52] C:\Windows\ccmsetup'
    Write-Output '[53] C:\Windows\Logs\Software'
    Write-Output ''
    Write-Output '--- Tool --------------------------------------------------'
    Write-Output "[94] Refresh Device data  [95] Toggle Log Program ($activeLogProgram)"
    Write-Output "[96] Client Actions       [97] Start $activeLogProgram"
    Write-Output "[98] Change Device        [99] Exit"
    Write-Output ''

    Switch (Read-Host -Prompt 'Please select an Action') {
        1 {Open-LogFile -Action 'ccmsetup'}
        2 {Open-LogFile -Action 'ccmupdate'}
        3 {Open-LogFile -Action 'ccmappdiscovery'}
        4 {Open-LogFile -Action 'ccmappenforce'}
        5 {Open-LogFile -Action 'ccmexecmgr'}
        6 {Open-LogFile -Action 'ccmexec'}
        7 {Open-LogFile -Action 'ccmstartup'}
        8 {Open-LogFile -Action 'ccmpolicy'}
        9 {Open-LogFile -Action 'ccmepagent'}
        10 {Open-LogFile -Action 'ccmdownload'}
        11 {Open-LogFile -Action 'ccmeval'}
        12 {Open-LogFile -Action 'ccminventory'}
        13 {Open-LogFile -Action 'ccmsmsts'}
        14 {Open-LogFile -Action 'ccmstatemessage'}
        15 {Open-LogFile -Action 'winupdate'}
        16 {Open-LogFile -Action 'winservicing'}
        50 {Open-Path -Path 'C$\Windows\CCM\Logs'}
        51 {Open-Path -Path 'C$\Windows\ccmcache'}
        52 {Open-Path -Path 'C$\Windows\ccmsetup'}
        53 {Open-Path -Path 'C$\Windows\Logs\Software'}
        94 {Invoke-MainMenu}
        95 {Set-ActiveLogProgram}
        96 {Invoke-ClientActionMenu}
        97 {Invoke-LogProgram}
        98 {Invoke-MainMenu -ResetHostname}
        99 {Clear-Host; Exit}
        Default {Invoke-MainMenu}
    }
}

Function Invoke-ClientActionMenu {
    Write-MenuHeader
    Write-Output "Connected Device: $hostname"
    Write-Output "Operating System: $osString"
    Write-Output "ConfigMgr Client: $clientVersionString"
    Write-Output ''
    Write-Output '--- Client Actions ----------------------------------------'
    Write-Output '[1] Application Deployment Evaluation Cycle'
    Write-Output '[2] Discovery Data Collection Cycle'
    Write-Output '[3] File Collection Cycle'
    Write-Output '[4] Hardware Inventory Cycle'
    Write-Output '[5] Machine Policy Retrieval & Evaluation Cycle'
    Write-Output '[6] Software Inventory Cycle'
    Write-Output '[7] Software Metering Usage Report Cycle'
    Write-Output '[8] Software Updates Assignments Evaluation Cycle'
    Write-Output '[9] Software Update Scan Cycle'
    Write-Output '[10] Windows Installers Source List Update Cycle'
    Write-Output '[11] State Message Refresh'
    Write-Output '[12] Reevaluate Endpoint deployment '
    Write-Output '[13] Reevaluate Endpoint AM policy '
    Write-Output ''
    Write-Output '--- Tool --------------------------------------------------'
    Write-Output "[97] Refresh Device data  [98] Back to Main Menu"   
    Write-Output "[99] Exit"
    Write-Output ''

    Switch (Read-Host -Prompt 'Please select an Action') {
        1 {Invoke-ClientAction -Action '00000000-0000-0000-0000-000000000121'}
        2 {Invoke-ClientAction -Action '00000000-0000-0000-0000-000000000003'}
        3 {Invoke-ClientAction -Action '00000000-0000-0000-0000-000000000010'}
        4 {Invoke-ClientAction -Action '00000000-0000-0000-0000-000000000001'}
        5 {Invoke-ClientAction -Action '00000000-0000-0000-0000-000000000021','00000000-0000-0000-0000-000000000022'}
        6 {Invoke-ClientAction -Action '00000000-0000-0000-0000-000000000002'}
        7 {Invoke-ClientAction -Action '00000000-0000-0000-0000-000000000031'}
        8 {Invoke-ClientAction -Action '00000000-0000-0000-0000-000000000108'}
        9 {Invoke-ClientAction -Action '00000000-0000-0000-0000-000000000113'}
        10 {Invoke-ClientAction -Action '00000000-0000-0000-0000-000000000032'}
        11 {Invoke-ClientAction -Action '00000000-0000-0000-0000-000000000111'}
        12 {Invoke-ClientAction -Action '00000000-0000-0000-0000-000000000221'}
        13 {Invoke-ClientAction -Action '00000000-0000-0000-0000-000000000222'}
        97 {Invoke-ClientActionMenu}
        98 {Invoke-MainMenu}
        99 {Clear-Host; Exit}
        Default {Invoke-ClientActionMenu}
    }
}

# Check PowerShell Version
If ($PSVersionTable.PSVersion.Major -lt 3) {
    Invoke-MessageBox -Message 'This tool requires PowerShell 3.0 or later!'
    Exit
}

# Fire up Main Menu
Invoke-MainMenu -FirstLaunch