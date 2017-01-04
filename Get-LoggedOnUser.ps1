function global:Get-LoggedOnUser {
# PS version: 2.0 (tested Win7+)
# Written by: Yossi Sassi (yossis@protonmail.com) 
# Script version: 1.0 
# Updated: January 3rd, 2017

<# 
.SYNOPSIS

Gets currently logged-on users on all domain computers, to see if they are local admins or not.

.DESCRIPTION

Gets currently logged-on users (interactive logins) on all computer accounts in the domain, and reports whether the logged-on user is member of the local administrators group on that machine. This function does not require any external module, all code provided as is in the function.

.PARAMETER File

The name and location of the report file (Defaults to c:\LoggedOn.txt).

.PARAMETER ShowResultsToScreen

When specified, this switch shows the data collected in real time in the console, in addition to the log file.
   
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
HostName Logged-On User or Host Status   Is Admin
-------- -----------------------------   --------
LON-DC1  No User logged On interactively False   
LON-CL1  ADATUM\Administrator            True    
LON-SVR1 ADATUM\adam                     False   
MSL1     ADATUM\yossis                   False   

.EXAMPLE

PS C:\> $loggedOn = Import-Csv c:\LoggedOn.txt -Delimiter "`t"; $loggedOn | sort 'is admin' -Descending | ft -AutoSize
Gets the content of the report file into a variable, and outputs the results into a table, sorted by 'Is Admin' property.

e.g.
HostName Logged-On User or Host Status   Is Admin
-------- -----------------------------   --------
LON-CL1  ADATUM\Administrator            True    
MSL1     ADATUM\yossis                   False   
LON-SVR1 ADATUM\adam                     False   
LON-DC1  No User logged On interactively False
#>
[cmdletbinding()]
param ([switch]$ShowResultsToScreen, [string]$File = "c:\LoggedOn.txt"
 )

# Check for number of computer accounts in the domain. If over 500, suggest potential alternatives
#$Computers = get-adcomputer -filter * -Properties dnshostname | select -exp dnshostname
$Searcher = New-Object DirectoryServices.DirectorySearcher([ADSI]"")
$Searcher.Filter = "(objectClass=computer)"
$Computers = ($Searcher.Findall())

if ($Computers.count -gt 500) {
$PromptText = "You have over 500 computer accounts in domain $env:USERDNSDOMAIN.`nAre you sure you want to proceed?`nNote: Running this script over the network could take a while, and in large AD networks you might prefer running it locally using SCCM, PSRemoting etc."
$PromptTitle = "Check-LoggedOnUserRemotely"
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
$report += "HostName`tLogged-On User or Host Status`tIs Admin"
$OfflineComputers = @()

foreach ($comp in $Computers)
    {     
     if (Test-Connection -Computer $Comp.Properties.dnshostname -Count 1 -Quiet) {        
     $user = gwmi win32_computersystem -ComputerName $comp.Properties.dnshostname | select -ExpandProperty username 
     if ($user -eq $null) {$user = "No User logged On interactively"} 
        else # Check if local admin
        # Note: locally can be checkd as- [Security.Principal.WindowsIdentity]::GetCurrent().IsInRole([Security.PrincipaltInRole] “Administrator”)        
        {
        $group = [ADSI]"WinNT://$($Comp.Properties.dnshostname)/administrators,group"
        $member=@($group.psbase.invoke("Members"))      
        $usersInGroup = $member | ForEach-Object {([ADSI]$_).InvokeGet("Name")} 
        foreach ($GroupEntry in $usersInGroup) 
            {if ($GroupEntry -eq ($user.Split("\")[1])) {$AdminRole = $true}}
        }
     if ($AdminRole -ne $true -and $user -ne $null) {$AdminRole = $false} # if not admin, set to false     
     if ($ShowResultsToScreen) {write-host "$($comp.properties.name)`t$user`t$AdminRole"}
     $report += "$($comp.properties.name)`t$user`t$AdminRole"
     $user = $null
     $adminRole = $null
     $group = $null
     $member = $null
     $usersInGroup = $null
     } else # computer didn't respond to ping     
      {$report += $($comp.properties.name) + "`tdidn't respond to ping - possibly Offile or Port issue"; $OfflineComputers += $($comp.properties.name)
      if ($ShowResultsToScreen) {Write-Warning "$($comp.properties.name)`tdidn't respond to ping - possibly  Offile or Port issue"}
      }
    }
$report | Out-File $File 
If ($OfflineComputers -ne $null) # If there were offline / Non-responsive computers
{ $OfflineComputers | Out-File c:\NonRespondingComputers.txt
  Write-Warning "Total of $($OfflineComputers.count) computers didn't respond.`nNon-Responding computers where saved into c:\NonRespondingComputers.txt." -ForegroundColor  
 }
Write-Host "The full report was saved to $File" -ForegroundColor Cyan
# Set back the system's current Error Action Preference
$ErrorActionPreference = $CurrentEAP
}