﻿# Run this on the site server
$ExportPath = "E:\ExportedQueries"
$Logfile = "$ExportPath\QueryExport.log"
$SiteServer = $env:COMPUTERNAME
$SiteCode = "PS1"

# Create path if not existing
If (!(Test-Path -Path $ExportPath)){ 
    # Export path $ExportPath does not esist, creating it"
    New-Item -Path $ExportPath -ItemType Directory
}

# Validate the path for good measure
If (!(Test-Path -Path $ExportPath)){ 
    Write-Warning "Export path $ExportPath does not exist, aborting..."
    break
}

# Delete any existing logfile if it exists
If (Test-Path $Logfile){Remove-Item $Logfile -Force -ErrorAction SilentlyContinue -Confirm:$false}

Function Write-Log{
	param (
    [Parameter(Mandatory = $true)]
    [string]$Message
   )

   $TimeGenerated = $(Get-Date -UFormat "%D %T")
   $Line = "$TimeGenerated : $Message"
   Add-Content -Value $Line -Path $LogFile -Encoding Ascii

}

function Get-ObjectLocation {
    param (
    [string]$InstanceKey
    )
    
    $ContainerNode = Get-WmiObject -Namespace root/SMS/site_$SiteCode -ComputerName $SiteServer -Query "SELECT ocn.* FROM SMS_ObjectContainerNode AS ocn JOIN SMS_ObjectContainerItem AS oci ON ocn.ContainerNodeID=oci.ContainerNodeID WHERE oci.ObjectType = '7' and oci.InstanceKey='$InstanceKey'"
    if ($ContainerNode -ne $null) {
        $ObjectFolder = $ContainerNode.Name
        if ($ContainerNode.ParentContainerNodeID -eq 0) {
            $ParentFolder = $false
        }
        else {
            $ParentFolder = $true
            $ParentContainerNodeID = $ContainerNode.ParentContainerNodeID
        }
        while ($ParentFolder -eq $true) {
            $ParentContainerNode = Get-WmiObject -Namespace root/SMS/site_$SiteCode -ComputerName $SiteServer -Query "SELECT * FROM SMS_ObjectContainerNode WHERE ContainerNodeID = '$ParentContainerNodeID'"
            $ObjectFolder =  $ParentContainerNode.Name + "\" + $ObjectFolder
            if ($ParentContainerNode.ParentContainerNodeID -eq 0) {
                $ParentFolder = $false
            }
            else {
                $ParentContainerNodeID = $ParentContainerNode.ParentContainerNodeID
            }
        }
        $ObjectFolder = "Root\" + $ObjectFolder
        Write-Output $ObjectFolder
    }
    else {
        $ObjectFolder = "Root"
        Write-Output $ObjectFolder
    }
}

# Connect to ConfigMgr 
Write-Log "Connecting to ConfigMgr"
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
cd "$SiteCode`:"

# Enumerating Custom ConfigMgr Queries (Only)
Write-Log "Enumerating Custom ConfigMgr Queries"
$Queries = Get-CMQuery -Name * | Where-Object {$_.QueryID -inotlike 'SMS*'}
$NumberOfQueries = ($Queries | Measure-Object).Count
Write-Log "Number of Custom ConfigMgr Queries found is $NumberOfQueries"

$Queries | Select -First 1 | Select *

Foreach ($Query in $Queries){

    Write-Log  "Working on query: $Folder\$($Query.Name)"
    $Folder = Get-ObjectLocation -InstanceKey $($Query.QueryID)
    $TargetFolder = "$ExportPath\$Folder"
    If (!(Test-Path -Path $TargetFolder)){ 
        Write-Log "Target folder $TargetFolder does not esist, creating it..."
        New-Item -Path $TargetFolder -ItemType Directory
    } 
    $ExportFilePath = "$TargetFolder\$($Query.Name).mof"
    Write-Log "Exporting query: $Folder\$($Query.Name) to $TargetFolder"
    $Query | Export-CMQuery -ExportFilePath $ExportFilePath

}

