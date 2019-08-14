function global:Get-LoggedOnUser {
# PS version: 2.0 (tested Win7+)
# Written by: Yossi Sassi (yossis@protonmail.com) 
# Script version: 1.2
# Updated: August 14th, 2019

<# 
.SYNOPSIS

Gets current interactively logged-on users on all enabled domain computers, and check if they are a Direct member of Local Administrators group (Not from Group membership (e.g. "Domain admins"), but were directly added to the local administrators group)

.DESCRIPTION

Gets currently logged-on users (interactive logins) on all computer accounts in the domain, and reports whether the logged-on user is member of the local administrators group on that machine. This function does not require any external module, all code provided as is in the function.

.PARAMETER File

The name and location of the report file (Defaults to c:\LoggedOn.txt).

.PARAMETER ShowResultsToScreen

When specified, this switch shows the data collected in real time in the console, in addition to the log file.

.PARAMETER DoNotPingComputer

By Default - computers will first be pinged for 10ms timeout. If not responding, computer will be skipped. 
When specifying -DoNotPingComputer parameter, computer will be queried and tried access even if ping/ICMP echo response is blocked.
   
.EXAMPLE

PS C:\> Get-LoggedOnUser -File c:\temp\users-report.log
Sets the currently logged-on users report file to be saved at c:\temp\users-report.log.
Default is c:\LoggedOn.txt.

.EXAMPLE

PS C:\> Get-LoggedOnUser -ShowResultsToScreen
Shows the data collected in real time, onto the screen, in addition to the log file.

e.g.
LON-DC1	No User logged On interactively	False
LON-CL1	ADATUM\Administrator	True
LON-SVR1	ADATUM\adam	False
MSL1	ADATUM\yossis	False
The full report was saved to c:\LoggedOn.txt

.EXAMPLE

PS C:\> Import-Csv .\LoggedOn.txt -Delimiter "`t" | ft -AutoSize
Imports the CSV report file into Powershell, and lists the data in a table.

e.g.
HostName Logged-OnUserOrHostStatus       IsDirectLocalAdmin
-------- -------------------------       ------------------
LON-DC1  No User logged On interactively False   
LON-CL1  ADATUM\Administrator            True    
LON-SVR1 ADATUM\adam                     False   
MSL1     ADATUM\yossis                   False   

.EXAMPLE

PS C:\> $loggedOn = Import-Csv c:\LoggedOn.txt -Delimiter "`t"; $loggedOn | sort IsDirectLocalAdmin -Descending | ft -AutoSize
Gets the content of the report file into a variable, and outputs the results into a table, sorted by 'IsDirectLocalAdmin' property.

e.g.
HostName Logged-OnUserOrHostStatus       IsDirectLocalAdmin
-------- -------------------------       ------------------
LON-CL1  ADATUM\Administrator            True    
MSL1     ADATUM\yossis                   False   
LON-SVR1 ADATUM\adam                     False   
LON-DC1  No User logged On interactively False
#>
[cmdletbinding()]
param ([switch]$ShowResultsToScreen, 
[switch]$DoNotPingComputer,
[string]$File = "$ENV:TEMP\LoggedOn.txt"
 )

# Initialize
Write-Host "Initializing query. please wait...`n" -ForegroundColor cyan

# Check for number of computer accounts in the domain. If over 500, suggest potential alternatives
# Get all Enabled computer accounts 
$Searcher = New-Object DirectoryServices.DirectorySearcher([ADSI]"")
$Searcher.Filter = "(&(objectClass=computer)(!userAccountControl:1.2.840.113556.1.4.803:=2))"
$Searcher.PageSize = 50000 # by default, 1000 are returned for adsiSearcher. this script will handle up to 50K acccounts.
$Computers = ($Searcher.Findall())

if ($Computers.count -gt 500) {
$PromptText = "You have $($computers.count) enabled computer accounts in domain $env:USERDNSDOMAIN.`nAre you sure you want to proceed?`nNote: Running this script over the network could take a while, and in large AD networks you might prefer running it locally using SCCM, PSRemoting etc."
$PromptTitle = "Get-LoggedOnUser"
$Options = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$Options.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
$Options.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))
$Choice = $host.ui.PromptForChoice($PromptTitle,$PromptText,$Options,0)
If ($Choice -eq 1) {break}}

# If OK - continue with the script
# Get the current Error Action Preference
$CurrentEAP = $ErrorActionPreference
# Set script not to alert for errors
$ErrorActionPreference = "silentlycontinue"
$report = @()
$report += "HostName`tLogged-OnUserOrHostStatus`tIsDirectLocalAdmin"
$OfflineComputers = @()

# If not responding to Ping - by default, host will be skipped. 
# NOTE: Default timeout for ping is 10ms - you can change it in the following function below
filter Invoke-Ping {(New-Object System.Net.NetworkInformation.Ping).Send($_,10)}

foreach ($comp in $Computers)
    { 
    # Check if computer needs to be Pinged first or not, and if Yes - see if responds to ping    
     switch ($DoNotPingComputer)
     {
     $false {$ProceedToCheck = ($Comp.Properties.dnshostname | Invoke-Ping).status -eq "Success"}
     $true {$ProceedToCheck = $true}
    }
     
     if ($ProceedToCheck) {   
     $user = gwmi win32_computersystem -ComputerName $Comp.Properties.dnshostname | select -ExpandProperty username1
# If wmi query returned empty results - try querying with QUSER for active console session 
if ($user -eq $null) {
$user = quser /SERVER:$($Comp.Properties.dnshostname) | select-string active | % {$_.toString().split(" ")[1].Trim()}
} 

# Check if logged on user is a Direct member of Local Administrators group
     if ($user -eq $null) {$user = "No User logged On interactively"} 
        else # Check if local admin
        # Note: locally can be checkd as- [Security.Principal.WindowsIdentity]::GetCurrent().IsInRole([Security.PrincipaltInRole] "Administrator")        
        {
        $group = [ADSI]"WinNT://$($Comp.Properties.dnshostname)/administrators,group"
        $member=@($group.psbase.invoke("Members"))      
        $usersInGroup = $member | ForEach-Object {([ADSI]$_).InvokeGet("Name")} 
        foreach ($GroupEntry in $usersInGroup) 
            {if ($GroupEntry -eq $user) {$AdminRole = $true}}
        }
     if ($AdminRole -ne $true -and $user -ne $null) {$AdminRole = $false} # if not admin, set to false     
     if ($ShowResultsToScreen) {write-host "$($Comp.Properties.dnshostname)`t$user`t$AdminRole"}
     $report += "$($Comp.Properties.dnshostname)`t$user`t$AdminRole"
     $user = $null
     $adminRole = $null
     $group = $null
     $member = $null
     $usersInGroup = $null
     } 
     else 
     # computer didn't respond to ping     
      {$report += $($Comp.Properties.dnshostname) + "`tdidn't respond to ping - possibly Offile or Firewall issue"; $OfflineComputers += $($comp.properties.name)
      if ($ShowResultsToScreen) {Write-Warning "$($Comp.Properties.dnshostname)`tdidn't respond to ping - possibly  Offile or Port issue"}
      }
    }
$report | Out-File $File 

# Wrap up
Write-Host "`nCompleted checking $($Computers.Count) hosts.`n" -ForegroundColor Green

# check for offline computers, if encountered
If ($OfflineComputers -ne $null) # If there were offline / Non-responsive computers
{ $OfflineComputers | Out-File "$ENV:Temp\NonRespondingComputers.txt"
  Write-Warning "Total of $($OfflineComputers.count) computers didn't respond to Ping.`nNon-Responding computers where saved into $($ENV:Temp)\NonRespondingComputers.txt." 
 }

Write-Host "The full report was saved to $File" -ForegroundColor Cyan
# Set back the system's current Error Action Preference
$ErrorActionPreference = $CurrentEAP
}
