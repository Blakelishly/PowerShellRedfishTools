#Requires -Version 7.0
Write-Host "Running tests..."
# $TargetURIs = @("10.0.0.17","10.0.100.10:8460", "10.0.100.10:8461", "10.0.100.10:8462", "10.0.100.10:8463", "10.0.100.10:8464", "10.0.100.10:8465", "10.0.100.10:8466", "10.0.100.10:8467", "10.0.100.10:8468", "10.0.100.10:8469", "10.0.100.10:8470", "10.0.100.10:8471", "10.0.100.10:8472", "10.0.100.10:8473")
$TargetURIs = @("10.0.0.17","10.0.100.10:8466","10.0.100.10:8470")
$targetUsername = "redfish"
$targetPassword = "redfish123"
$targetPasswordSecure = ConvertTo-SecureString $targetPassword -AsPlainText -Force
$targetCredential = New-Object System.Management.Automation.PSCredential ($targetUsername, $targetPasswordSecure)
Write-Host "|-- Target URIs: $TargetURIs"
Write-Host "|-- Target username: $targetUsername"

# Get-RecursiveRedfishLookup
$runTest1_1 = $true
$runTest1_2 = $true
# Start-RedfishHostInventoryCollection
$runTest2_1 = $true
$runTest2_2 = $true
# Get-RedfishTargetLogs
$runTest3_1 = $true
$runTest3_2 = $true
# Invoke-RemoteManagementActions
$runTest4_1 = $false
$runTest4_2 = $false

# Run the tests
if($runTest1_1 -or $runTest1_2){
# Get-RecursiveRedfishLookup
Write-Host "|-- Testing: Get-RecursiveRedfishLookup"
$scriptParentPath = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$scriptRelativePath = Join-Path -Path "Get-RecursiveRedfishLookup" -ChildPath "Get-RecursiveRedfishLookup.ps1"
$scriptPath = Join-Path -Path $scriptParentPath -ChildPath $scriptRelativePath
Write-Host "|-- Script path: $scriptPath"
if($runTest1_1){
# Get-RecursiveRedfishLookup RUN1
Write-Host "|---- Executing RUN1"
$redfishURLRoot = "/redfish/v1/"
$OutputDirectory = "Get-RecursiveRedfishLookup-RUN1"
$URLFilter = "*"
Write-Host "|------ Testing with URLFilter: $URLFilter"
Write-Host "|------ Output directory: $OutputDirectory"
Write-Host "|------ Target Redfish Root: $redfishURLRoot"
& $scriptPath -TargetURIs $TargetURIs -Credential $targetCredential -redfishURLRoot $redfishURLRoot -OutputDirectory $OutputDirectory -URLFilter $URLFilter
}
if($runTest1_2){
# Get-RecursiveRedfishLookup RUN2
Write-Host "|---- Executing RUN2"
$redfishURLRoot = "/redfish/v1/AccountService"
$OutputDirectory = "Get-RecursiveRedfishLookup-RUN2"
$URLFilter = "/redfish/v1/AccountService/Accounts/*/"
Write-Host "|------ Testing with URLFilter: $URLFilter"
Write-Host "|------ Output directory: $OutputDirectory"
Write-Host "|------ Target Redfish Root: $redfishURLRoot"
& $scriptPath -TargetURIs $TargetURIs -Credential $targetCredential -redfishURLRoot $redfishURLRoot -OutputDirectory $OutputDirectory -URLFilter $URLFilter
}
}

if($runTest2_1 -or $runTest2_2){
# Start-RedfishHostInventoryCollection
Write-Host "|-- Testing: Start-RedfishHostInventoryCollection"
$scriptParentPath = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$scriptRelativePath = Join-Path -Path "Start-RedfishHostInventoryCollection" -ChildPath "Start-RedfishHostInventoryCollection.ps1"
$propertyMappingRelativePath = Join-Path -Path "Start-RedfishHostInventoryCollection" -ChildPath "PropertyMapping.json"
$scriptPath = Join-Path -Path $scriptParentPath -ChildPath $scriptRelativePath
$propertyMappingPath = Join-Path -Path $scriptParentPath -ChildPath $propertyMappingRelativePath
Write-Host "|-- Script path: $scriptPath"
Write-Host "|-- Property Mapping File: $propertyMappingPath"
if($runTest2_1){
# Start-RedfishHostInventoryCollection RUN1
Write-Host "|---- Executing RUN1"
$RootDirectory = "Get-RecursiveRedfishLookup-RUN1"
$OutputDirectory = "Start-RedfishHostInventoryCollection-RUN1"
Write-Host "|------ Root Directory: $RootDirectory"
Write-Host "|------ CSV Output Path: $OutputDirectory"
& $scriptPath -RootDirectory $RootDirectory -OutputDirectory $OutputDirectory -PropertyMappingFile $propertyMappingPath
}
if($runTest2_2){
# Start-RedfishHostInventoryCollection RUN2
Write-Host "|---- Executing RUN2"
$RootDirectory = "Get-RecursiveRedfishLookup-RUN2"
$OutputDirectory = "Start-RedfishHostInventoryCollection-RUN2"
Write-Host "|------ Root Directory: $RootDirectory"
Write-Host "|------ CSV Output Path: $OutputDirectory"
& $scriptPath -RootDirectory $RootDirectory -OutputDirectory $OutputDirectory -PropertyMappingFile $propertyMappingPath
}
}

if($runTest3_1 -or $runTest3_2){
# Get-RedfishTargetLogs
Write-Host "|-- Testing: Get-RedfishTargetLogs"
$scriptParentPath = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$scriptRelativePath = Join-Path -Path "Get-RedfishTargetLogs" -ChildPath "Get-RedfishTargetLogs.ps1"
$propertyMappingRelativePath = Join-Path -Path "Get-RedfishTargetLogs" -ChildPath "PropertyMapping.json"
$scriptPath = Join-Path -Path $scriptParentPath -ChildPath $scriptRelativePath
$propertyMappingPath = Join-Path -Path $scriptParentPath -ChildPath $propertyMappingRelativePath
Write-Host "|-- Script path: $scriptPath"
Write-Host "|-- Property Mapping File: $propertyMappingPath"
if($runTest3_1){
# Get-RedfishTargetLogs RUN1
Write-Host "|---- Executing RUN1"
$OutputDirectory = "Get-RedfishTargetLogs-RUN1"
$JSONOutput = $true
Write-Host "|------ Output Directory: $OutputDirectory"
Write-Host "|------ JSON Output: $JSONOutput"
& $scriptPath -TargetURIs $TargetURIs -Credential $targetCredential -OutputDirectory $OutputDirectory -JSONOutput $JSONOutput
}
if($runTest3_2){
# Get-RedfishTargetLogs RUN2
Write-Host "|---- Executing RUN2"
$OutputDirectory = "Get-RedfishTargetLogs-RUN2"
$JSONOutput = $false
Write-Host "|------ Output Directory: $OutputDirectory"
Write-Host "|------ JSON Output: $JSONOutput"
& $scriptPath -TargetURIs $TargetURIs -Credential $targetCredential -OutputDirectory $OutputDirectory -JSONOutput $JSONOutput
}
}

if($runTest4_1 -or $runTest4_2){
# Invoke-RemoteManagementActions
Write-Host "|-- Testing: Invoke-RemoteManagementActions"
$scriptParentPath = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$scriptRelativePath = Join-Path -Path "Invoke-RemoteManagementActions" -ChildPath "Invoke-RemoteManagementActions.ps1"
$ActionMappingFileRelativePath = Join-Path -Path "Invoke-RemoteManagementActions" -ChildPath "ActionMapping.json"
$scriptPath = Join-Path -Path $scriptParentPath -ChildPath $scriptRelativePath
$ActionMappingFilePath = Join-Path -Path $scriptParentPath -ChildPath $ActionMappingFileRelativePath
Write-Host "|-- Script path: $scriptPath"
Write-Host "|-- Action Mapping File: $ActionMappingFilePath"
if($runTest4_1){
# Invoke-RemoteManagementActions RUN1
Write-Host "|---- Executing RUN1"
$targetURI = "10.0.0.17"
Write-Host "|------ Target URI: $targetURI"
& $scriptPath -TargetURI $targetURI -Credential $targetCredential -ActionMappingFile $ActionMappingFilePath
}
if($runTest4_2){
# Invoke-RemoteManagementActions RUN2
Write-Host "|---- Executing RUN2"
$targetURI = "10.0.100.10:8466"
Write-Host "|------ Target URI: $targetURI"
& $scriptPath -TargetURI $targetURI -Credential $targetCredential -ActionMappingFile $ActionMappingFilePath
}
}