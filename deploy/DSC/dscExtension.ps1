Configuration DeployWebAppDatabase
{

Param (
    [Parameter(Mandatory=$true)][string] $nodeName, 
    [Parameter(Mandatory=$true)][string] $applicationPackage)

Import-DscResource -ModuleName PSDesiredStateConfiguration

Node $nodeName
{
    WindowsFeature WebServerRole
    {
        Name = "Web-Server"
        Ensure = "Present"
    }
     
    WindowsFeature WebManagementConsole
    {
      Name = "Web-Mgmt-Console"
      Ensure = "Present"
    }

    WindowsFeature WebManagementService
    {
      Name = "Web-Mgmt-Service"
      Ensure = "Present"
    }

    WindowsFeature WebMgmtTools
    {
        Name = "Web-Mgmt-Tools"
        Ensure = "Present"
        DependsOn = "[WindowsFeature]WebServerRole"
    }

    WindowsFeature WebMgmtConsole
    {
        Name = "Web-Mgmt-Console"
        Ensure = "Present"
        DependsOn = "[WindowsFeature]WebServerRole"
    }

    WindowsFeature ApplicationInitialization
    {
      Name = "Web-AppInit"
      Ensure = "Present"
    }

    WindowsFeature WAS
    {
        Name = "WAS"
        Ensure = "Present"
        DependsOn = "[WindowsFeature]WebServerRole"
    }

    WindowsFeature WASProcessModel
    {
        Name = "WAS-Process-Model"
        Ensure = "Present"
        DependsOn = "[WindowsFeature]WebServerRole"
    }

    WindowsFeature WASNetEnvironment
    {
        Name = "WAS-NET-Environment"
        Ensure = "Present"
        DependsOn = "[WindowsFeature]WebServerRole"
    }

    WindowsFeature WASConfigAPIs
    {
        Name = "WAS-Config-APIs"
        Ensure = "Present"
        DependsOn = "[WindowsFeature]WebServerRole"
    }

    #WindowsFeature NETHTTPActivation
    #{
    #    Name = "NET-HTTP-Activation"
    #    Ensure = "Present"
    #    DependsOn = "[WindowsFeature]WebServerRole"
    #}

    #WindowsFeature NETNonHTTPActiv
    #{
    #    Name = "NET-Non-HTTP-Activ"
    #    Ensure = "Present"
    #    DependsOn = "[WindowsFeature]WebServerRole"
    #}
            
    #WindowsFeature NETWCFHTTPActivation45
    #{
    #    Name = "NET-WCF-HTTP-Activation45"
    #    Ensure = "Present"
    #    DependsOn = "[WindowsFeature]WebServerRole"
    #}

    WindowsFeature ASPNet45
    {
        Name = "Web-Asp-Net45"
        Ensure = "Present"
        DependsOn = "[WindowsFeature]WebServerRole"
    }

    Script DownloadWebDeploy
    {
        DependsOn = "[WindowsFeature]ASPNet45"
        GetScript = {
            @{
                Result = "DownloadWebPIImage"
            }
        }
        TestScript = {
            Test-Path "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
        }
        SetScript ={
            $source = "https://download.microsoft.com/download/0/1/D/01DC28EA-638C-4A22-A57B-4CEF97755C6C/WebDeploy_amd64_en-US.msi"
            $destination = "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
            Invoke-WebRequest $source -OutFile $destination
        }
    }

    Package InstallWebDeploy
    {
        Ensure = "Present"  
        Path  = "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
        Name = "Microsoft Web Deploy 3.6"
        ProductId = "{6773A61D-755B-4F74-95CC-97920E45E696}"
        Arguments = "ADDLOCAL=ALL"
        DependsOn = "[Script]DownloadWebDeploy"
    }

    Service StartWebDeploy
    {                    
        Name = "WMSVC"
        StartupType = "Automatic"
        State = "Running"
        DependsOn = "[Package]InstallWebDeploy"
    }

    #Script GrantAccessToSQL
    #{
    #    DependsOn = "[Service]StartWebDeploy" 

    #    GetScript = {
    #        @{
    #            Result = "GrantAccessToSQL"
    #        }
    #    }

    #    TestScript = {
    #        $false
    #    }

    #    SetScript = {
    #        Import-Module Sqlps
    #        $userName = "IIS APPPOOL\DefaultAppPool"
    #        $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server "."
    #        if ($sqlServer.Logins.Contains($userName) -eq $false)
    #        {
    #            $sqlUser = New-Object Microsoft.SqlServer.Management.Smo.Login -ArgumentList $sqlServer, $userName
    #            $sqlUser.LoginType = "WindowsUser"
    #            $sqlUser.Create()
    #        }
    #        $sqlServer.Roles["dbcreator"].AddMember($userName)
    #    }
    #}

    Script DeployApplication
    {  
        #DependsOn = "[Script]GrantAccessToSQL"
        DependsOn = "[Service]StartWebDeploy"
        GetScript = {
            @{
                Result = "DeployApplication"
            }
        }

        TestScript = {
            # Deployment needs to run always
            $false
        }

        SetScript = {
            #
            # If you need to "wipe out" extension then you can do that with following command:
            # Remove-AzureRmVMDscExtension -ResourceGroupName "webappdatabase-local-rg" -VMName "webappdatabase1"
            # More info: 
            # https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-extensions-troubleshoot/#troubleshooting-extenson-failures
            # 
            $logFile = "c:\WindowsAzure\log.txt"
            Write-Output "ApplicationPackage 1.0: $($using:applicationPackage)" > $logFile
            $destination = "C:\WindowsAzure\WebAppDatabaseAll.zip"

            Invoke-WebRequest $using:applicationPackage -OutFile $destination

            Write-Output "Unpacking application package" >> $logFile
            Expand-Archive -Force -LiteralPath $destination -DestinationPath "C:\WindowsAzure\WebAppDatabase"
            CD "C:\WindowsAzure\WebAppDatabase\app\SSRS\"

            .\configure-SSRS.ps1 >> $logFile
            rs.exe -i PublishReport.rss -s localhost/ReportServer -e Mgmt2010 >> $logFile
            CD ..
            .\WebApp.deploy.cmd /Y >> $logFile
        }
    }
  }
}

# DeployWebAppDatabase
# Start-DscConfiguration -Wait -Verbose -Path .\deployservice
