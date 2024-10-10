#Requires -Version 7.0
#region License ############################################################
# Copyright (c) 2024 Blake Cherry
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#endregion License ############################################################
<#
.SYNOPSIS
    A PowerShell script to import, process, and export Redfish JSON data to CSV files based on property mappings.

.DESCRIPTION
    This script recursively imports Redfish JSON data from a specified root directory, processes the data according to provided property mappings, and exports the processed data to CSV files in an output directory. It facilitates data extraction and transformation from Redfish API responses saved as JSON files.

.PARAMETER RootDirectory
    Specifies the root directory containing the Redfish JSON files to import. This is a mandatory parameter.
    This should be output from the Get-RecursiveRedfishLookup.ps1 script.

.PARAMETER OutputDirectory
    The directory where the processed CSV files will be saved. If not specified, a directory named `Output` is created in the script's directory.

.PARAMETER PropertyMappingFile
    The path to the JSON file containing property mappings for processing the imported data. If not specified, a file named `PropertyMapping.json` in the script's directory is used.

.EXAMPLE
    .\Start-RedfishHostInventoryCollection.ps1 -RootDirectory "C:\RedfishData" -OutputDirectory "C:\ProcessedData" -PropertyMappingFile "C:\Config\PropertyMapping.json"

    This example imports Redfish JSON data from `C:\RedfishData`, processes it using the property mappings defined in `C:\Config\PropertyMapping.json`, and exports the processed data to CSV files in `C:\ProcessedData`.

.EXAMPLE
    .\Start-RedfishHostInventoryCollection.ps1 -RootDirectory "C:\RedfishData"

    This example imports Redfish JSON data from `C:\RedfishData`, processes it using the default property mappings, and exports the processed data to CSV files in the default `Output` directory.

.NOTES
    - This script requires PowerShell 7 or higher.
    - The JSON files should be organized under `redfish/v1/` in the directory structure.
    - The `PropertyMapping.json` file defines how properties are extracted and processed.
    - All errors are logged and can be reviewed for troubleshooting.

.LICENSE
    MIT License (c) 2024 Blake Cherry
#>
################################################################################################################################
# Define parameters
param (
    [Parameter(Mandatory = $true)]
    [string]$RootDirectory,

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "Output"),

    [Parameter(Mandatory = $false)]
    [string]$PropertyMappingFile = (Join-Path $PSScriptRoot "PropertyMapping.json")
)

#region Variables
$ErrorActionPreference = 'Stop'  # Stop on all errors
#endregion Variables

#region Functions
################################################################################################################################
### Function to import JSON data from a directory recursively
function Import-RedfishJsonData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RootDirectory
    )
    # Initialize an empty hashtable to hold all imported objects
    $importedData = @{}
    # Get all index.json files recursively
    $jsonFiles = Get-ChildItem -Path $RootDirectory -Filter 'index.json' -Recurse -File

    foreach ($file in $jsonFiles) {
        # Check if relative path includes 'redfish'
        # IF WINDOWS, USE -notlike '*redfish\v1\*'
        # IF LINUX OR MAC, USE -notlike '*redfish/v1/*'
        if ($IsWindows -and $file.DirectoryName -notlike '*redfish\v1\*') {
            Write-Verbose "Skipping file '$($file.FullName)' because it is not under 'redfish\v1'."
            continue
        }
        elseif (-not $IsWindows -and $file.DirectoryName -notlike '*redfish/v1/*') {
            Write-Verbose "Skipping file '$($file.FullName)' because it is not under 'redfish/v1'."
            continue
        }
        # Get the relative path of the JSON file
        $relativePath = $file.DirectoryName.Substring($RootDirectory.Length).TrimStart('\','/') -replace '\\', '/'
        # Import the JSON content
        $jsonContent = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json -AsHashtable
        # Store the JSON content in the hashtable using the relative path as the key
        $importedData += @{$relativePath = $jsonContent}
    }

    # Return the hashtable of imported data
    return $importedData
}
# Function to get a value from a nested hashtable or custom object based on a given path
function Get-ValueFromSubPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [psobject]$Object,

        [Parameter(Mandatory = $true)]
        [string[]]$SubPath
    )

    $currentObject = $Object

    foreach ($key in $SubPath) {
        if ($currentObject -is [hashtable] -or $currentObject -is [pscustomobject]) {
            # Use indexing to access the property/key
            if ($currentObject.PSObject.Properties.Name -contains $key -or $currentObject.ContainsKey($key)) {
                $currentObject = $currentObject[$key]
            }
            else {
                throw "Key $key not found in the current object."
            }
        }
        else {
            throw "Invalid path: $key is not a hashtable or custom object"
        }
    }

    return $currentObject
}

#### Function to process properties ####
function Get-PropertyValue {
    param (
        [psobject]$Object,
        [string[]]$SubPath
    )
    if ($null -eq $Object -or $SubPath.Count -eq 0) {
        return $null
    }
    $currentObject = [PSCustomObject]$Object
    foreach ($propertyName in $SubPath) {
        if ($null -eq $currentObject) {
            return $null
        }
        Write-Verbose "Current Object: $currentObject"
        Write-Verbose "Property Name: $propertyName"
        $currentObject = [PSCustomObject]$currentObject.$propertyName
    }
    return $currentObject
}
### Function to process the Redfish entries based on the property mappings
function Start-ProcessRedfishEntries {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$ImportedData,
        [Parameter(Mandatory = $true)]
        [hashtable]$PropertyMappings  # Assuming it's an array of mappings
    )

    # Initialize a hashtable to store processed entries indexed by hostname
    $processedEntries = @{}

    Write-Verbose "Starting to process Redfish entries."
    Write-Verbose "Imported data: $($PropertyMappings.GetEnumerator())"
    # Iterate over each mapping
    foreach ($mapping in $PropertyMappings.GetEnumerator()) {
        # Get name of the mapping
        $mappingName = $mapping.Key
        # Get the Properties, FallbackProperties, and URLFilter from the mapping
        $Properties = $mapping.Value.Properties
        $FallbackProperties = $mapping.Value.FallbackProperties
        $URLFilter = $mapping.Value.ResourceFilter
        $odataType = $mapping.Value.odataType

        Write-Verbose "Processing mapping: $mappingName"
        Write-Verbose "Processing mapping with URL filter: $URLFilter"
        Write-Verbose "Properties: $($Properties.Keys -join ', ')"
        Write-Verbose "Fallback Properties: $($FallbackProperties.Keys -join ', ')"

        foreach ($URL in $ImportedData.Keys) {
            # Split the URLs into segments
            $pathSegments = $URL -split '/'
            $filterSegments = $URLFilter -split '/'

            # Capture hostname as the entry in pathSegments right before 'redfish'
            $redfishIndex = $pathSegments.IndexOf('redfish')
            if ($redfishIndex -le 0) {
                Write-Verbose "Cannot determine hostname for URL '$URL'. Skipping."
                continue
            }
            $hostname = $pathSegments[$redfishIndex - 1]

            # Trim the URL to get the relative path - anything after 'redfish/v1', including 'redfish/v1'
            $relativeURL = $URL.Substring($URL.IndexOf('/redfish/v1'))

            $pathSegments = $relativeURL -split '/'

            Write-Verbose "Processing Hostname: $hostname, Relative URL: $relativeURL"

            # Match filter
            $match = $true
            for ($i = 0; $i -lt $pathSegments.Count; $i++) {
                if ($i -gt $filterSegments.Count) {
                    $match = $false
                    break
                }
                elseif ($pathSegments[$i] -like $filterSegments[$i]) {
                    $match = $true
                }
                else {
                    $match = $false
                    break
                }
            }

            if (-not $match) {
                Write-Verbose "URL '$relativeURL' does not match the filter '$URLFilter'. Skipping."
                continue
            }
            else {
                Write-Verbose "URL '$relativeURL' matches the filter '$URLFilter'. Processing."

                # Check odata.type if specified
                if (($odataType -ne $null -and $odataType -ne "") -and $ImportedData[$URL].ContainsKey('@odata.type')) {
                    $odataTypeValue = $ImportedData[$URL]['@odata.type']
                    if ($odataTypeValue -ne $odataType) {
                        Write-Verbose "URL '$relativeURL' does not have the correct odata.type. Skipping."
                        continue
                    }
                    else {
                        Write-Verbose "URL '$relativeURL' has the correct odata.type. Processing."
                    }
                }
                else {
                    Write-Verbose "No odata.type specified. Processing."
                }

                # Initialize the hashtable for the mapping if it doesn't exist
                if (-not $processedEntries.ContainsKey($mappingName)) {
                    $processedEntries[$mappingName] = @{}
                }
                # Initialize the hashtable for the hostname/relativeURL if it doesn't exist
                if (-not $processedEntries.ContainsKey($hostname)) {
                    $processedEntries[$mappingName]["$hostname-$relativeURL"] = @{}
                }

                foreach ($propertyEntry in $Properties.GetEnumerator()) {
                    $propertyName = $propertyEntry.Key
                    $propertyPath = $propertyEntry.Value

                    # If a value for the property has already been processed and isnt null, skip
                    if ($processedEntries[$mappingName]["$hostname-$relativeURL"].ContainsKey($propertyName) -and $processedEntries["$hostname-$relativeURL"][$propertyName] -ne $null) {
                        Write-Verbose "Property '$propertyName' already processed. Skipping."
                        continue
                    }

                    Write-Verbose "Processing Property: $propertyName, Path: $($propertyPath -join ', ')"
                    # Retrieve the value using the defined property path
                    # $value = Get-ValueFromSubPath -Object $ImportedData[$URL] -SubPath $propertyPath

                    if ($propertyPath -is [string]) {
                        # If propertyPath is a string, make it into an array
                        $propertyPath = @($propertyPath)
                    }
                    $value = Get-PropertyValue -Object $ImportedData[$URL] -SubPath $propertyPath
                    Write-Verbose "Value: $value"

                    if ($value -eq $null) {
                        # Attempt to retrieve the value using the fallback property path
                        $fallbackPath = $FallbackProperties[$propertyName]
                        if ($fallbackPath -ne $null) {
                            Write-Verbose "Fallback Property Path: $($fallbackPath -join ', ')"
                            # $value = Get-ValueFromSubPath -Object $ImportedData[$URL] -SubPath $fallbackPath
                            $value = Get-PropertyValue -Object $ImportedData[$URL] -SubPath $fallbackPath
                            Write-Verbose "Fallback Value: $value"
                        }
                    }
                    # Ensure the value is cast to a string
                    $value = $value | ConvertTo-Json -Depth 100 | Out-String
                    # Add the property and value to the hostname's hashtable
                    $processedEntries[$mappingName]["$hostname-$relativeURL"][$propertyName] = $value
                }
            }
        }
    }

    Write-Verbose "Processed entries: $($processedEntries | select * | Out-String)"

    # Convert the processed hashtable to an array of objects
    $finalEntries = @{}

    # Iterate over a copy of processedEntries
    foreach($entry in @($processedEntries.GetEnumerator())) {
        $mappingName = $entry.Key
        $mappingEntries = @($entry.Value.GetEnumerator())
        foreach($mappingEntry in $mappingEntries) {
            $aMapping = @()
            foreach ($processedEntry in @($processedEntries[$mappingName].GetEnumerator())) {
                $obj = $processedEntry.Value
                $obj.Hostname = "$($processedEntry.Key)"
                $aMapping += [PSCustomObject]$obj
            }
            $finalEntries[$mappingName] = $aMapping
        }
    }

    return $finalEntries
}

#region Main Script
################################################################################################################################

# Step 1: Import JSON files recursively
Write-Host "Importing JSON files from directory: $RootDirectory"
$importedData = Import-RedfishJsonData -RootDirectory $RootDirectory
Write-Host "Imported data from $($importedData.Count) JSON files."

# Step 2: Load property mappings from JSON file
Write-Host "Loading property mappings from file: $PropertyMappingFile"
$PropertyMappings = Get-Content -Path $PropertyMappingFile -Raw | ConvertFrom-Json -AsHashtable
Write-Host "Loaded property mappings from $($PropertyMappings.Count) mappings."
Write-Verbose "Property mappings: $($PropertyMappings | select * | Out-String)"

# Step 3: Process the imported data using the property mappings
Write-Host "Processing imported data using property mappings."
$processedEntries = Start-ProcessRedfishEntries -ImportedData $importedData -PropertyMappings $PropertyMappings
Write-Host "Processed $($processedEntries.Count) entries."

# Step 4: Export the processed entries to CSV
Write-Host "Exporting processed data to '$OutputDirectory'."
# If the output path does not exist, create it
if (-not (Test-Path $OutputDirectory)) {
    Write-Host "Creating output directory: $OutputDirectory"
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
}
foreach ($entry in $processedEntries.keys) {
    $path = Join-Path $OutputDirectory "$entry.csv"
    Write-Debug "Exporting processed data for mapping '$($entry)' to path '$path'."
    $processedEntries.$entry | Export-Csv -Path $path -NoTypeInformation
    Write-Host "Exported processed data to $path."
}
return $processedEntries