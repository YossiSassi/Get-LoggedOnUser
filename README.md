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
