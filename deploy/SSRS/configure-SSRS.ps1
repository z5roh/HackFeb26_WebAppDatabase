#
# Script originally from:
# https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-classic-ps-sql-report/
#

## This script configures a Native mode report server without HTTPS
$ErrorActionPreference = "Stop"

$server = "localhost" #$env:COMPUTERNAME
$HTTPport = 80 # change the value if you used a different port for the private HTTP endpoint when the VM was created.

## Set PowerShell execution policy to be able to run scripts
Set-ExecutionPolicy RemoteSigned -Force

## Utility method for verifying an operation's result
function CheckResult
{
    param($wmi_result, $actionname)
    if ($wmi_result.HRESULT -ne 0) {
        write-error "$actionname failed. Error from WMI: $($wmi_result.Error)"
    }
}

$starttime=Get-Date
write-host -foregroundcolor DarkGray $starttime StartTime

## ReportServer Database name - this can be changed if needed
$dbName='ReportServer'

## Register for MSReportServer_ConfigurationSetting
## Change the version portion of the path to "v12" to use the script for SQL Server 2014
$RSObject = Get-WmiObject -class "MSReportServer_ConfigurationSetting" -namespace "root\Microsoft\SqlServer\ReportServer\RS_MSSQLSERVER\v12\Admin"

if ($RSObject.IsInitialized -eq $false)
{
    ## Report Server Configuration Steps

    ## Setting the web service URL ##
    write-host -foregroundcolor green "Setting the web service URL"
    write-host -foregroundcolor green ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    $time=Get-Date
    write-host -foregroundcolor DarkGray $time

    ## SetVirtualDirectory for ReportServer site
    Write-Host 'Calling SetVirtualDirectory'
    $r = $RSObject.SetVirtualDirectory('ReportServerWebService','ReportServer',1033)
    CheckResult $r "SetVirtualDirectory for ReportServer"

    ## ReserveURL for ReportServerWebService - port $HTTPport (for local usage)
    write-host "Calling ReserveURL port $HTTPport"
    $r = $RSObject.ReserveURL('ReportServerWebService',"http://+:$HTTPport",1033)
    CheckResult $r "ReserveURL for ReportServer port $HTTPport" 

    ## Setting the Database ##
    write-host -foregroundcolor green "Setting the Database"
    write-host -foregroundcolor green ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    $time=Get-Date
    write-host -foregroundcolor DarkGray $time

    ## GenerateDatabaseScript - for creating the database
    Write-Host "Calling GenerateDatabaseCreationScript for database $dbName"
    $r = $RSObject.GenerateDatabaseCreationScript($dbName,1033,$false)
    CheckResult $r "GenerateDatabaseCreationScript"
    $script = $r.Script

    ## Execute sql script to create the database
    write-host 'Executing Database Creation Script'
    $savedcvd = Get-Location
    Import-Module SQLPS              ## this automatically changes to sqlserver provider
    Invoke-SqlCmd -Query $script
    Set-Location $savedcvd

    ## GenerateGrantRightsScript 
    $DBUser = "NT Service\ReportServer"
    write-host "Calling GenerateDatabaseRightsScript with user $DBUser"
    $r = $RSObject.GenerateDatabaseRightsScript($DBUser,$dbName,$false,$true)
    CheckResult $r "GenerateDatabaseRightsScript"
    $script = $r.Script

    ## Execute grant rights script
    write-host 'Executing Database Rights Script'
    $savedcvd = Get-Location
    cd sqlserver:\
    Invoke-SqlCmd -Query $script
    Set-Location $savedcvd

    ## SetDBConnection - uses Windows Service (type 2), username is ignored
    write-host "Calling SetDatabaseConnection server $server, DB $dbName"
    $r = $RSObject.SetDatabaseConnection($server,$dbName,2,'','')
    CheckResult $r "SetDatabaseConnection"  

    ## Setting the Report Manager URL ##
    write-host -foregroundcolor green "Setting the Report Manager URL"
    write-host -foregroundcolor green ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    $time=Get-Date
    write-host -foregroundcolor DarkGray $time

    ## SetVirtualDirectory for Reports (Report Manager) site
    write-host 'Calling SetVirtualDirectory'
    $r = $RSObject.SetVirtualDirectory('ReportManager','Reports',1033)
    CheckResult $r "SetVirtualDirectory"

    ## ReserveURL for ReportManager  - port $HTTPport
    write-host "Calling ReserveURL for ReportManager, port $HTTPport"
    $r = $RSObject.ReserveURL('ReportManager',"http://+:$HTTPport",1033)
    CheckResult $r "ReserveURL for ReportManager port $HTTPport"

    write-host -foregroundcolor green "Open Firewall port for $HTTPport"
    write-host -foregroundcolor green ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    $time=Get-Date
    write-host -foregroundcolor DarkGray $time

    ## Open Firewall port for $HTTPport
    New-NetFirewallRule -DisplayName “Report Server (TCP on port $HTTPport)” -Direction Inbound –Protocol TCP –LocalPort $HTTPport
    write-host "Added rule Report Server (TCP on port $HTTPport) in Windows Firewall"

    write-host 'Operations completed, Report Server is ready'
    write-host -foregroundcolor DarkGray $starttime StartTime
    $time=Get-Date
    write-host -foregroundcolor DarkGray $time
}
else
{
    Write-Host "SSRS already initialized."
}
