Param (
    [string] $ResourceGroupName = "webappdatabase-local-rg",
    [string] $Location = "northeurope",
    [string] $Template = "$PSScriptRoot\azuredeploy.json",
    [string] $TemplateParameters = "$PSScriptRoot\azuredeploy.parameters.json",
    [string] $DscFile = "$PSScriptRoot\DSC\",
    [string] $SSRSFiles = "$PSScriptRoot\SSRS\",
    [string] $ApplicationFiles = "$PSScriptRoot\..\src\WebApp\Publish\",
    [string] $VaultName = "webappdatabase-local-kv",
    [string] $StorageName = "webappdatabaselocaldata",
    [string] $VaultSecretName = "VirtualMachineAdminPassword",
    [string] $AdminUsername = "azureuser"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrEmpty($env:RELEASE_DEFINITIONNAME))
{
    Write-Host (@"
Not executing inside VSTS Release Management.
Make sure you have done "Login-AzureRmAccount" and
"Select-AzureRmSubscription -SubscriptionName name"
so that script continues to work correctly for you.
"@)
}

if ((Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction SilentlyContinue) -eq $null)
{
    Throw "Resource group '$ResourceGroupName' doesn't exist which means 'deploy-initial.ps1' is not called correctly."
}

$StorageContainerRoot = "deploy"
$StorageContainerName = "packages/"
$storage = Get-AzureRmStorageAccount -Name $StorageName -ResourceGroupName $ResourceGroupName
$storageKey = $storage.Context.StorageAccount.Credentials.ExportBase64EncodedKey()
$storageContext = New-AzureStorageContext -StorageAccountName $StorageName -StorageAccountKey $storageKey

if ((Get-AzureStorageContainer -Name $StorageContainerRoot -Context $storageContext -ErrorAction SilentlyContinue) -eq $null)
{
    New-AzureStorageContainer -Name $StorageContainerRoot -Context $storageContext -Permission Off
}

function UploadResourceToStorage([string] $resource)
{
    $returnValue = New-Object -TypeName hashtable
    $fileName = Split-Path -Path $resource -Leaf
    $blob = $StorageContainerName + $fileName
    $expiryTime = (Get-Date).ToUniversalTime().AddHours(4.0)
    $uploadedBlob = Set-AzureStorageBlobContent -Container $StorageContainerRoot -Blob $blob -File $resource -Context $storageContext -Verbose -Force
    $sasToken = New-AzureStorageBlobSASToken -Container $StorageContainerRoot -Blob $blob -Context $storageContext -Protocol HttpsOnly -Permission r -ExpiryTime $expiryTime -Verbose

    $returnValue.url = $storageContext.BlobEndPoint + $StorageContainerRoot + "/" + $uploadedBlob.Name
    $returnValue.token = $sasToken
    return $returnValue
}

function CompressFile([string] $DestinationPath, [string] $LiteralPath, [bool] $IncludeFolderName)
{
    # Windows PowerShell 5.0 is not installed at the VSTS Hosted Agents 
    # and therefore following command won't work
    #Compress-Archive -DestinationPath $DestinationPath -LiteralPath $LiteralPath -Force
    # Fallback is to use good old .NET :D
    Add-Type -Assembly "System.IO.Compression.FileSystem"
    Remove-Item $DestinationPath -Force -ErrorAction SilentlyContinue
    [System.IO.Compression.ZipFile]::CreateFromDirectory(`
        $LiteralPath, `
        $DestinationPath, `
        [System.IO.Compression.CompressionLevel]::Optimal, $IncludeFolderName)
}

$dscPackage = "$PSScriptRoot\dscPackage.zip"
$applicationPackage = "$PSScriptRoot\WebAppAll.zip"
Copy-Item -Path $SSRSFiles -Destination $ApplicationFiles -Force -Recurse
CompressFile -DestinationPath $dscPackage -LiteralPath $DscFile -IncludeFolderName $false
CompressFile -DestinationPath $applicationPackage -LiteralPath $ApplicationFiles -IncludeFolderName $true

$dsc = UploadResourceToStorage($dscPackage)
$package = UploadResourceToStorage($applicationPackage)

# Get password from key vault
$secret = Get-AzureKeyVaultSecret -VaultName $VaultName -Name $VaultSecretName

# Create additional parameters that we pass to the template deployment
$additionalParameters = New-Object -TypeName hashtable
$additionalParameters['virtualMachineAdminUserName'] = $AdminUsername
$additionalParameters['virtualMachineAdminPassword'] = $secret.SecretValue
$additionalParameters['dscLocation'] = $dsc.url
$additionalParameters['dscLocationSasToken'] = ConvertTo-SecureString -String $dsc.token -AsPlainText -Force
#$additionalParameters['applicationPackage'] = ConvertTo-SecureString -String ($package.url + $package.token) -AsPlainText -Force
$additionalParameters['applicationPackage'] = $package.url + $package.token

$result = New-AzureRmResourceGroupDeployment `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile $Template `
    -TemplateParameterFile $TemplateParameters `
    @additionalParameters `
    -Verbose

$result
