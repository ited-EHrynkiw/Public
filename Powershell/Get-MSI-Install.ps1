param (
    [string]$Url,
    [string]$InstallerName
)

function Log {
    param(
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$timestamp - $Message"
}

function DownloadFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [Parameter(Mandatory = $true)]
        [string]$InstallerName,
        [string]$Path = [System.Environment]::GetEnvironmentVariable('TEMP', 'Machine')
    )
    $OutputPath = Join-Path -Path $Path -ChildPath $InstallerName
    if (Test-Path -Path $OutputPath) {
        Log "File $InstallerName already exists at $OutputPath."
        return $OutputPath
    }
    $webClient = New-Object -TypeName System.Net.WebClient
    $File = $null
    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
    try {
        Log "Download of $InstallerName start"
        $webClient.DownloadFile($Url, $OutputPath)
        Log "Download of $InstallerName done"
        $File = $OutputPath
    }
    catch {
        Log "ERROR: Download of $InstallerName failed - $_"
    }
    finally {
        $webClient.Dispose()
    }
    return $File
}

function Get-MSIFileInformation {

    # Usage: Get-MSIFileInformation -FilePath "C:\path\to\file.msi"
    
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo[]]$FilePath
    ) 
  
    # https://learn.microsoft.com/en-us/windows/win32/msi/installer-opendatabase
    $msiOpenDatabaseModeReadOnly = 0
    
    $productLanguageHashTable = @{
        '1025' = 'Arabic'
        '1026' = 'Bulgarian'
        '1027' = 'Catalan'
        '1028' = 'Chinese - Traditional'
        '1029' = 'Czech'
        '1030' = 'Danish'
        '1031' = 'German'
        '1032' = 'Greek'
        '1033' = 'English'
        '1034' = 'Spanish'
        '1035' = 'Finnish'
        '1036' = 'French'
        '1037' = 'Hebrew'
        '1038' = 'Hungarian'
        '1040' = 'Italian'
        '1041' = 'Japanese'
        '1042' = 'Korean'
        '1043' = 'Dutch'
        '1044' = 'Norwegian'
        '1045' = 'Polish'
        '1046' = 'Brazilian'
        '1048' = 'Romanian'
        '1049' = 'Russian'
        '1050' = 'Croatian'
        '1051' = 'Slovak'
        '1053' = 'Swedish'
        '1054' = 'Thai'
        '1055' = 'Turkish'
        '1058' = 'Ukrainian'
        '1060' = 'Slovenian'
        '1061' = 'Estonian'
        '1062' = 'Latvian'
        '1063' = 'Lithuanian'
        '1081' = 'Hindi'
        '1087' = 'Kazakh'
        '2052' = 'Chinese - Simplified'
        '2070' = 'Portuguese'
        '2074' = 'Serbian'
    }

    $summaryInfoHashTable = @{
        1  = 'Codepage'
        2  = 'Title'
        3  = 'Subject'
        4  = 'Author'
        5  = 'Keywords'
        6  = 'Comment'
        7  = 'Template'
        8  = 'LastAuthor'
        9  = 'RevisionNumber'
        10 = 'EditTime'
        11 = 'LastPrinted'
        12 = 'CreationDate'
        13 = 'LastSaved'
        14 = 'PageCount'
        15 = 'WordCount'
        16 = 'CharacterCount'
        18 = 'ApplicationName'
        19 = 'Security'
    }

    $properties = @('ProductVersion', 'ProductCode', 'ProductName', 'Manufacturer', 'ProductLanguage', 'UpgradeCode')
   
    try {
        $file = Get-ChildItem $FilePath -ErrorAction Stop
    }
    catch {
        Write-Warning "Unable to get file $FilePath $($_.Exception.Message)"
        return
    }

    $object = [PSCustomObject][ordered]@{
        FileName     = $file.Name
        FilePath     = $file.FullName
        'Length(MB)' = $file.Length / 1MB
    }

    # Read property from MSI database
    $windowsInstallerObject = New-Object -ComObject WindowsInstaller.Installer

    # open read only    
    $msiDatabase = $windowsInstallerObject.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $windowsInstallerObject, @($file.FullName, $msiOpenDatabaseModeReadOnly))

    foreach ($property in $properties) {
        $view = $null
        $query = "SELECT Value FROM Property WHERE Property = '$($property)'"
        $view = $msiDatabase.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $msiDatabase, ($query))
        $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null)
        $record = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)

        try {
            $value = $record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, 1)
        }
        catch {
            Write-Verbose "Unable to get '$property' $($_.Exception.Message)"
            $value = ''
        }
        
        if ($property -eq 'ProductLanguage') {
            $value = "$value ($($productLanguageHashTable[$value]))"
        }

        $object | Add-Member -MemberType NoteProperty -Name $property -Value $value
    }

    $summaryInfo = $msiDatabase.GetType().InvokeMember('SummaryInformation', 'GetProperty', $null, $msiDatabase, $null)
    $summaryInfoPropertiesCount = $summaryInfo.GetType().InvokeMember('PropertyCount', 'GetProperty', $null, $summaryInfo, $null)

    (1..$summaryInfoPropertiesCount) | ForEach-Object {
        $value = $SummaryInfo.GetType().InvokeMember("Property", "GetProperty", $Null, $SummaryInfo, $_)

        if ($null -eq $value) {
            $object | Add-Member -MemberType NoteProperty -Name $summaryInfoHashTable[$_] -Value ''
        }
        else {
            $object | Add-Member -MemberType NoteProperty -Name $summaryInfoHashTable[$_] -Value $value
        }
    }

    #$msiDatabase.GetType().InvokeMember('Commit', 'InvokeMethod', $null, $msiDatabase, $null)
    $view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null)
 
    # Run garbage collection and release ComObject
    $null = [System.Runtime.Interopservices.Marshal]::ReleaseComObject($windowsInstallerObject) 
    [System.GC]::Collect()

    return $object  
} 

function Get-InstalledMSIPackages {

    # Example usage:
    # Get all fields
    # Get-InstalledMSIPackages
    # Get only ProductCode field
    # Get-InstalledMSIPackages -Fields "ProductCode"
    # Get multiple fields
    # Get-InstalledMSIPackages -Fields @("ProductCode", "ProductName")

    param(
        [Parameter(Mandatory = $false)]
        [string[]]$Fields = @("ProductCode", "LocalPackage", "VersionString", "ProductName")
    )

    # Create Windows Installer COM object
    $Installer = New-Object -ComObject WindowsInstaller.Installer

    # Retrieve installed products using ProductsEx method
    $InstallerProducts = $Installer.ProductsEx("", "", 7)

    # Initialize an array to store product objects
    $InstalledProducts = @()

    # Iterate through each product and create a custom object
    foreach ($Product in $InstallerProducts) {
        $InstalledProduct = [PSCustomObject]@{
            ProductCode   = $Product.ProductCode()
            LocalPackage  = $Product.InstallProperty("LocalPackage")
            VersionString = $Product.InstallProperty("VersionString")
            ProductName   = $Product.InstallProperty("ProductName")
        }

        # Create a filtered custom object based on the specified fields
        $FilteredProduct = [PSCustomObject]@{}

        foreach ($field in $Fields) {
            if ($InstalledProduct.PSObject.Properties[$field]) {
                $FilteredProduct | Add-Member -MemberType NoteProperty -Name $field -Value $InstalledProduct.$field
            }
        }

        $InstalledProducts += $FilteredProduct
    }

    # Output the array of installed products
    return $InstalledProducts
}

function InstallMsi {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MSIPath,
        [Parameter(Mandatory = $true)]
        [string]$InstallerName
    )
    $LogPath = Join-Path -Path (Split-Path -Path $MSIPath -Parent) -ChildPath "$InstallerName-log.txt"
    try {
        Log "Installing MSI from $MSIPath"
        $Process = (Start-Process msiexec.exe -ArgumentList "/i `"$MSIPath`" /log `"$LogPath`" /quiet /norestart" -Wait -PassThru).ExitCode
        $Process.ExitCode
        
        # Get the ProductCode of the MSI to be installed
        $MSIGUID = Get-MSIFileInformation $MSIPath | Select-Object -ExpandProperty ProductCode
        # Run Get-InstalledMSIPackages and capture the output
        $InstalledPackages = Get-InstalledMSIPackages -Fields "ProductCode"
        # Convert the output to an array of strings for processing
        $ProductCodes = $InstalledPackages | Select-Object -ExpandProperty ProductCode

        $InstalledMsi = $ProductCodes | Where-Object { $_ -eq $MSIGUID }
     
        # Debug
        #Write-Host "MSIGUID: $MSIGUID"
        #Write-Host "InstalledMsi: $InstalledMsi"

        if ($MSIGUID = $InstalledMsi) {
            Log "Application '$InstallerName' installed successfully."
            Log "MSI installation log file: $LogPath"
            return $true
        }
        else {
            throw "Application '$InstallerName' not found after installation."            
        }
    }
    catch {
        Log "ERROR: MSI installation failed - $_"
        Log "MSI installation failed with exit code $($Process.ExitCode). See log file: $LogPath"
        return $false
    }
}

function InstallMsi {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MSIPath,
        [Parameter(Mandatory = $true)]
        [string]$InstallerName
    )
    $LogPath = Join-Path -Path (Split-Path -Path $MSIPath -Parent) -ChildPath "$InstallerName-log.txt"
    try {
        Log "Installing MSI from $MSIPath"
        $Process = (Start-Process msiexec.exe -ArgumentList "/i `"$MSIPath`" /log `"$LogPath`" /quiet /norestart" -Wait -PassThru).ExitCode
        $Process.ExitCode
        
        # Get the ProductCode of the MSI to be installed
        $MSIGUID = Get-MSIFileInformation $MSIPath | Select-Object -ExpandProperty ProductCode
        # Run Get-InstalledMSIPackages and capture the output
        $InstalledPackages = Get-InstalledMSIPackages -Fields "ProductCode"
        # Convert the output to an array of strings for processing
        $ProductCodes = $InstalledPackages | Select-Object -ExpandProperty ProductCode

        $InstalledMsi = $ProductCodes | Where-Object { $_ -eq $MSIGUID }
     

        Write-Host "MSIGUID: $MSIGUID"
        Write-Host "InstalledMsi: $InstalledMsi"

        if ($MSIGUID = $InstalledMsi) {
            Log "Application '$InstallerName' installed successfully."
            Log "MSI installation log file: $LogPath"
            return $true
        }
        else {
            throw "Application '$InstallerName' not found after installation."            
        }
    }
    catch {
        Log "ERROR: MSI installation failed - $_"
        Log "MSI installation failed with exit code $($Process.ExitCode). See log file: $LogPath"
        return $false
    }
}

function CreateStatusMessage {
    param(
        [string]$Status,
        [string]$Url,
        [string]$InstallerName,
        [string]$Path,
        [string]$Message
    )
    $obj = [ordered]@{
        Status        = $Status
        Url           = $Url
        InstallerName = $InstallerName
        Path          = $Path
        Message       = $Message
    }
    $Final = [string]::Join("|", ($obj.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }))
    Write-Output $Final
}

# Check if mandatory parameters are provided
if (-not $Url -or -not $InstallerName) {
    Write-Host "Usage: .\script.ps1 -Url <URL> -InstallerName <InstallerName>"
    exit 1
}

# Define the URL and the destination filename
$filePath = DownloadFile -Url $Url -InstallerName $InstallerName

if ($filePath) {
    Log "Download complete. File saved to $filePath."
    $StatusMessage = CreateStatusMessage -Status "Download" -Url $Url -InstallerName $InstallerName -Path $filePath -Message "Success"
    Log $StatusMessage

    $installResult = InstallMsi -MSIPath $filePath -InstallerName $InstallerName

    if ($installResult) {
        $StatusMessage = CreateStatusMessage -Status "Install" -Url $Url -InstallerName $InstallerName -Path $filePath -Message "Success"
        Log "Installation process completed successfully."
    }
    else {
        $StatusMessage = CreateStatusMessage -Status "Install" -Url $Url -InstallerName $InstallerName -Path $filePath -Message "Failed"
        Log "Installation process failed."
    }
    Log $StatusMessage
}
else {
    $StatusMessage = CreateStatusMessage -Status "Download" -Url $Url -InstallerName $InstallerName -Path $filePath -Message "Failed"
    Log "Download failed. File not found."
    Log $StatusMessage
}
