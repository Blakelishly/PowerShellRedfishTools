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
        if ($file.DirectoryName -notlike '*redfish\v1\*') {
            Write-Verbose "Skipping file '$($file.FullName)' because it is not under 'redfish\v1'."
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
function Get-ValueFromSubPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [psobject]$Object,

        [Parameter(Mandatory = $true)]
        [string[]]$SubPath
    )

    $currentObject = $Object

    Write-Host $currentObject

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

# function Start-ProcessRedfishEntries {
#     [CmdletBinding()]
#     param (
#         [Parameter(Mandatory = $true)]
#         [hashtable]$ImportedData,
#         [Parameter(Mandatory = $true)]
#         [PsCustomObject]$PropertyMappings
#     )

#     $processedEntries = @()

#     foreach ($mapping in $PropertyMappings) {
#         # Get the Properties, FallbackProperties, and URLFilter from the mapping
#         $Properties = $mapping.Properties
#         $FallbackProperties = $mapping.FallbackProperties
#         $URLFilter = $mapping.ResourceFilter

#         foreach ($URL in $ImportedData.keys) {
#             # Split the URLs into segments
#             $pathSegments = $URL -split '/'
#             $filterSegments = $URLFilter -split '/'
#             # Capture hostname as entry in pathSegments right before redfish
#             $hostname = $pathSegments[$pathSegments.IndexOf('redfish') - 1]
#             # Trim the URL to get the relative path - anything after redfish/v1
#             $relativeURL = $URL.Substring($URL.IndexOf('redfish/v1') + 10)

#             Write-Host "Relative URL: $relativeURL"
#             Write-Host "Hostname: $hostname"
            
#             # Match filter
#             $match = $false
#             for ($i=0; $i -lt $pathSegments.Count; $i++) {
#                 if ($i -ge $filterSegments.Count) {
#                     break
#                 }
#                 elseif ($pathSegments[$i] -like $filterSegments[$i]) {
#                     $match = $true
#                 }
#                 else {
#                     $match = $false
#                     break
#                 }
#             }
#             if (-not $match) {
#                 Write-Verbose "URL $URL does not match the filter '$URLFilter'. Skipping."
#                 continue
#             }
#             else {
#                 Write-Verbose "URL $URL matches the filter '$URLFilter'. Processing."
                
#                 foreach ($property in $Properties) {
#                     # "TotalSystemMemoryGiB": ["MemorySummary", "TotalSystemMemoryGiB"]
#                     # Based on each property, supplied as an array of strings representing the property path
#                     $value = Get-ValueFromSubPath -Object $ImportedData[$URL] -SubPath $property
#                     if ($value -eq $null) {
#                         # If the value is null, try to get the value from the matching fallback property
#                         $value = Get-ValueFromSubPath -Object $ImportedData[$URL] -SubPath $FallbackProperties.$property
#                     }
#                     # If the value is still null, set this value to "Not Found"
#                     if ($value -eq $null) {
#                         $value = "Not Found"
#                     }
#                     # Add the property and value to the output hashtable

#                 }
#             }
#         }
#     }

#     return $processedEntries
# }

# # Step 1: Import JSON files recursively
# $RootDirectory = '..\Get-RecursiveRedfishLookup\RedfishAPI\10.0.0.16'  # Update this path as needed
# Write-Host "Importing JSON files from directory: $RootDirectory"
# $importedData = Import-RedfishJsonData -RootDirectory $RootDirectory
# Write-Host "Imported data from $($importedData.Count) JSON files."

# # Step 2: Load property mappings from JSON file
# $PropertyMappings = Get-Content -Path 'PropertyMapping.json' | ConvertFrom-Json

# # Step 3: Process the imported data using the property mappings
# Start-ProcessRedfishEntries -ImportedData $importedData -PropertyMappings $PropertyMappings
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
        Write-Host "Current Object: $currentObject"
        Write-Host "Property Name: $propertyName"
        $currentObject = [PSCustomObject]$currentObject.$propertyName
    }
    return $currentObject
}
# function Get-PropertyValue {
#     [CmdletBinding()]
#     param (
#         [Parameter(Mandatory = $true)]
#         [psobject]$Object,

#         [Parameter(Mandatory = $true)]
#         [string[]]$SubPath
#     )

#     $currentObject = $Object

#     foreach ($key in $SubPath) {
#         if ($currentObject -is [hashtable] -or $currentObject -is [pscustomobject]) {
#             # Use indexing to access the property/key
#             if ($currentObject.PSObject.Properties.Name -contains $key -or $currentObject.ContainsKey($key)) {
#                 $currentObject = $currentObject[$key]
#             }
#             else {
#                 throw "Key '$key' not found in the current object."
#             }
#         }
#         else {
#             throw "Invalid path: '$key' is not a hashtable or custom object"
#         }
#     }

#     return $currentObject
# }

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

    foreach ($mapping in $PropertyMappings.GetEnumerator()) {
        # Get the Properties, FallbackProperties, and URLFilter from the mapping
        $Properties = $mapping.Value.Properties
        $FallbackProperties = $mapping.Value.FallbackProperties
        $URLFilter = $mapping.Value.ResourceFilter

        Write-Host "Processing mapping with URL filter: $URLFilter"
        Write-Host "Properties: $($Properties.Keys -join ', ')"
        Write-Host "Fallback Properties: $($FallbackProperties.Keys -join ', ')"

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

            Write-Host "Processing Hostname: $hostname, Relative URL: $relativeURL"

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
                Write-Host "URL '$relativeURL' does not match the filter '$URLFilter'. Skipping."
                continue
            }
            else {
                Write-Host "URL '$relativeURL' matches the filter '$URLFilter'. Processing."

                # Initialize the hashtable for the hostname/relativeURL if it doesn't exist
                if (-not $processedEntries.ContainsKey($hostname)) {
                    $processedEntries["$hostname-$relativeURL"] = @{}
                }

                foreach ($propertyEntry in $Properties.GetEnumerator()) {
                    $propertyName = $propertyEntry.Key
                    $propertyPath = $propertyEntry.Value

                    # If a value for the property has already been processed and isnt null, skip
                    if ($processedEntries["$hostname-$relativeURL"].ContainsKey($propertyName) -and $processedEntries["$hostname-$relativeURL"][$propertyName] -ne $null) {
                        Write-Host "Property '$propertyName' already processed. Skipping."
                        continue
                    }

                    Write-Host "Processing Property: $propertyName, Path: $($propertyPath -join ', ')"
                    # Retrieve the value using the defined property path
                    # $value = Get-ValueFromSubPath -Object $ImportedData[$URL] -SubPath $propertyPath

                    if ($propertyPath -is [string]) {
                        # If propertyPath is a string, make it into an array
                        $propertyPath = @($propertyPath)
                    }
                    $value = Get-PropertyValue -Object $ImportedData[$URL] -SubPath $propertyPath
                    Write-Host "Value: $value"

                    if ($value -eq $null) {
                        # Attempt to retrieve the value using the fallback property path
                        $fallbackPath = $FallbackProperties[$propertyName]
                        if ($fallbackPath -ne $null) {
                            Write-Host "Fallback Property Path: $($fallbackPath -join ', ')"
                            # $value = Get-ValueFromSubPath -Object $ImportedData[$URL] -SubPath $fallbackPath
                            $value = Get-PropertyValue -Object $ImportedData[$URL] -SubPath $fallbackPath
                            Write-Host "Fallback Value: $value"
                        }
                    }
                    # Ensure the value is cast to a string
                    $value = $value | ConvertTo-Json -Depth 10 | Out-String
                    # Add the property and value to the hostname's hashtable
                    $processedEntries["$hostname-$relativeURL"][$propertyName] = $value
                }
            }
        }
    }

    Write-Host "Processed entries: $($processedEntries | select * | Out-String)"

    # Convert the processed hashtable to an array of PSCustomObjects
    $finalEntries = $processedEntries.GetEnumerator() | ForEach-Object {
        $obj = $_.Value
        $obj.Hostname = "$($_.Key)_$relativeURL"
        [PSCustomObject]$obj
    }

    return $finalEntries
}

# Step 1: Import JSON files recursively
$RootDirectory = '..\Get-RecursiveRedfishLookup\RedfishAPI\10.0.0.17'  # Update this path as needed
Write-Host "Importing JSON files from directory: $RootDirectory"
$importedData = Import-RedfishJsonData -RootDirectory $RootDirectory
Write-Host "Imported data from $($importedData.Count) JSON files."

# Step 2: Load property mappings from JSON file
$PropertyMappings = Get-Content -Path 'PropertyMapping.json' -raw | ConvertFrom-Json -asHashtable

# Step 3: Process the imported data using the property mappings
$processedEntries = Start-ProcessRedfishEntries -ImportedData $importedData -PropertyMappings $PropertyMappings

# Step 4: Export the processed entries to CSV
$csvPath = 'RedfishDataOutput.csv'  # Specify your desired output path
$processedEntries | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "Exported processed data to '$csvPath'."
return $processedEntries