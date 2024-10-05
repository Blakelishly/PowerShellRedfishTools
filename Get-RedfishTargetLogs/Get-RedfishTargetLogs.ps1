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

################################################################################################################################
# Define parameters
param (
    [Parameter(Mandatory = $true)]
    [string[]]$TargetURIs,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential = (Get-Credential),

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = ".\Logs",

    [Parameter(Mandatory = $false)]
    [string]$PropertyMappingFile = (Join-Path $PSScriptRoot "PropertyMapping.json"),

    [Parameter(Mandatory = $false)]
    [bool]$JSONOutput = $true  # Parameter to control output format
)

#region Variables
$ErrorActionPreference = 'Stop'  # Stop on all errors
#endregion Variables

#region Functions
################################################################################################################################
function Connect-SwordfishTarget 
{
[CmdletBinding(DefaultParameterSetName='Default')]
param ( [Parameter(Mandatory=$true)]    [string]    $Target,
                                        [string]    $Port,            
        [Validateset("http","https")]   [string]    $Protocol   = "https"            
      )
Process
  {   if ( $Protocol -eq 'http')
                {   $Global:Base = "http://$($Target):$($Port)"
                } else 
                {   $Global:Base = "https://$($Target)"                
                }
            $Global:RedFishRoot = "/redfish/v1/"
            $Global:BaseTarget  = $Target
            $Global:BaseUri     = $Base+$RedfishRoot    
            $Global:MOCK        = $false
            Try     {   
                        $ReturnData = invoke-restmethod -uri "$BaseUri" -SkipCertificateCheck
                    }
            Catch   {   $_
                    }
            if ( $ReturnData )
                    {   write-verbose "The Global Redfish Root Location variable named RedfishRoot will be set to $RedfishRoot"
                        write-verbose "The Global Base Target Location variable named BaseTarget will be set to $BaseTarget"
                        write-verbose "The Global Base Uri Location variable named BaseUri will be set to $BaseUri"            
                        return $ReturnData
                    } 
                else 
                    {   Write-verbose "Since no connection was made, the global connection variables have been removed"
                        remove-variable -name RedfishRoot -scope Global
                        remove-variable -name BaseTarget -scope Global
                        remove-variable -name Base -scope Global
                        remove-variable -name BaseUri -scope Global
                        remove-variable -name MOCK -scope Global
                        Write-Error "No RedFish/Swordfish target Detected or wrong port used at that address"
                    }
  }
} 
Set-Alias -name 'Connect-RedfishTarget' -value 'Connect-SwordfishTarget'
#### Function to authenticate to a Redfish or Swordfish target ####
# This function sends a POST request to the session service to get a session token
# Instead of using the SNIA Swordfish module, this module is used, as we need to populate the session ID to disconnect it later
# The SNIA Swordfish module also creates 2 sessions for the same user, which is not ideal
function Set-TargetAuthentication {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$URI,
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential
    )
    try {
        # Clear existing session variables
        $global:XAuthToken = $null
        $global:SessionUri = $null
        $global:RedfishRoot = $null
        $global:BaseTarget = $null
        $global:Base = $null
        $global:BaseUri = $null
        $global:MOCK = $null

        # Connect to the target
        Write-Verbose "Connecting to Redfish target at $URI"
        $connect = Connect-RedfishTarget -Target $URI
        Write-Verbose "Attempting to get session token"

        if ( -not $BaseUri ) {   
            Write-Warning "This command requires that you run the Connect-SwordfishTarget or Connect-RedfishTarget first."
            return
        } 
        $SSBody = @{
            UserName    =   $Credential.UserName;
            Password    =   $Credential.GetNetworkCredential().Password
        }
        $SSContType = @{   
            'Content-type'    = 'Application/json'
        }
        $BodyJSON = $SSBody | convertto-json
        
        $authResult = invoke-WebRequest -uri ( $BaseUri + "SessionService/Sessions" ) -header $SSContType -method Post -Body $BodyJSON -SkipCertificateCheck                        

        if ( $authResult ) {
            $Global:XAuthToken = (($authResult.Headers).'X-Auth-Token')

            # Check if $authResult.Headers.Location is a valid property
            # If not, use $authResult.content converted from JSON as the session URI
            if ($authResult.Headers.Location) {
                $NewSessionUri = $authResult.Headers.Location
            } else {
                $NewSessionUri = ($authResult.Content | ConvertFrom-Json).message
            }

            $baseUriLength = $Global:Base.Length
            if ($NewSessionUri.StartsWith($Global:Base)) {
                $Global:SessionUri = $NewSessionUri.Substring($baseUriLength)
            } else {
                # URL does not start with BaseUri, use as is
                $Global:SessionUri = $NewSessionUri -replace '^https?://', ''
            }

            Write-Verbose "XAuthToken set to $global:XAuthToken"
            Write-Verbose "SessionUri set to $global:SessionUri"
        } else {
            throw "No RedFish/Swordfish target Detected or wrong port used at that address"
        }

        if ($XAuthToken -is [array]) {
            $global:XAuthToken = $XAuthToken[0]
        } else {
            $global:XAuthToken = $XAuthToken
        }
    } catch {
        Write-Error "Failed to authenticate to $URI. Error: $_"
        throw $_
    }
}

#### Function to disconnect from a Redfish or Swordfish target ####
# This function sends a DELETE request to the session URI to terminate the session
function Disconnect-SwordfishTarget {
    [CmdletBinding()]
    param (
    )
    Process {
        try {
            # Check if the session token exists
            if (-not $Global:XAuthToken) {
                Write-Warning "No auth token is configured. Skipping disconnect."
                return
            }
            # Prepare the headers with the session token            
            $headers = @{ 'X-Auth-Token' = $Global:XAuthToken }
            # Send a DELETE request to terminate the session
            if ($Global:SessionUri) {
                Write-Verbose "Disconnecting session at $($Global:Base + $Global:SessionUri)"
                $disconnect = Invoke-RestMethod -Method Delete -Uri ($Global:Base + $Global:SessionUri) -Headers $headers -SkipCertificateCheck
                Write-Verbose "Session disconnected successfully. Response: $($disconnect | ConvertTo-Json)"
            } else {
                Write-Warning "Session URI is not available. Cannot disconnect the session."
            }
            # Clear the session variables
            Remove-Variable -Name XAuthToken -Scope Global -ErrorAction SilentlyContinu
        } catch {
            Write-Error "Failed to disconnect the session. Error: $_"
        }
    }
}
Set-Alias -Name 'Disconnect-RedfishTarget' -Value 'Disconnect-SwordfishTarget'

#### Function to get data from a Redfish URL ####
# This function is a wrapper around Invoke-WebRequest to handle Redfish authentication
# Instead of using the SNIA Swordfish module, this module is used, as it allows headers to be retrieved with Invoke-WebRequest
function Invoke-RedfishWebRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$URL,
        [string]$Method = 'GET',
        $Body
    )
    try {
        # Prepare the full URL
        if ($URL -notmatch '^https?://') {
            $fullURL = $Global:Base + $URL
        } else {
            $fullURL = $URL
        }
        # Prepare headers
        $headers = @{}
        if ($Global:XAuthToken) {
            $headers['X-Auth-Token'] = $Global:XAuthToken
        }
        else {
            Write-Warning "No auth token is configured. Skipping headers."
        }
        # Send GET request
        Write-Verbose "Sending GET request to $fullURL"
        if ($Body) {   
            $response = Invoke-WebRequest -Method $Method -Uri $fullURL -Headers $headers -SkipCertificateCheck -Body $Body
        } else {   
            $response = Invoke-WebRequest -Method $Method -Uri $fullURL -Headers $headers -SkipCertificateCheck
        }
        
        return $response
    } catch {
        Write-Error "Failed to get data from $URL. Error: $_"
        throw $_
    }
}

function Get-SwordfishByURL
{
[CmdletBinding()]
    param(  
        [Parameter(Mandatory=$True, ValueFromPipeline=$true)]
        $URL
    )
    process {   
        try {   
            Write-Verbose "Getting Data from $URL"
            $MyData = Invoke-RedfishWebRequest -url ( $URL ) -erroraction stop
            if ( $MyData.exception ) {
                return
            } 
            else {
                Write-Verbose "Data Retrieved: $($MyData)"
                return $MyData.content | ConvertFrom-Json
            }
        }
        catch {   
            $_
            return
        } 
    }
}
Set-Alias -Value 'Get-SwordfishByURL' -Name 'Get-RedfishByURL'

#### Function to get the system object ####
function Get-Systems {
    [CmdletBinding()]
    param ()
    try {
        $SystemData = Get-RedfishByURL -URL '/redfish/v1/Systems'
        Write-Verbose "System Data: $($SystemData | ConvertTo-Json -Depth 15)"
        $SysCollection=@()
        foreach($Sys in ($SystemData).Members ) {   
            $SysCollection +=  Get-RedfishByURL -URL ($Sys.'@odata.id')  
        }
        Write-Debug "System Info: $($SysCollection | ConvertTo-Json -Depth 15)"
        return $SysCollection
    } catch {
        Write-Error "Failed to get system. Error: $_"
        throw $_
    }
}

#### Function to get the log services object ####
function Get-LogServices {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SystemID
    )
    try {
        $logServices = Get-RedfishByURL -URL "/redfish/v1/Systems/$SystemID/LogServices/"
        Write-Debug "LogServices: $($logServices | ConvertTo-Json -Depth 15)"
        return $logServices.Members
    } catch {
        Write-Error "Failed to get LogServices for System ID $SystemID. Error: $_"
        throw $_
    }
}

#### Function to get log entries for a given log service ####
function Get-LogEntries {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogServiceURL
    )
    try {
        # Get the Entries URL
        $logService = Get-RedfishByURL -URL $LogServiceURL
        Write-Debug "LogService ($LogServiceURL): $($logService | ConvertTo-Json -Depth 15)"
        $entriesURL = $logService.Entries.'@odata.id'

        # Get all Entries
        $entriesData = Get-RedfishByURL -URL $entriesURL
        Write-Debug "Entries ($entriesURL): $($entriesData | ConvertTo-Json -Depth 15)"

        $entryItems = @()
        foreach ($entry in $entriesData.Members) {
            $entryURL = $entry.'@odata.id'
            $entryData = Get-RedfishByURL -URL $entryURL
            Write-Debug "Queryed Entry ($entryURL): $($entryData | ConvertTo-Json -Depth 15)"
            $entryItems += $entryData
        }

        return $entryItems
    } catch {
        Write-Error "Failed to get log entries from $LogServiceURL. Error: $_"
        throw $_
    }
}

#### Function to process log entries based on property mappings ####
function Start-ProcessLogEntry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [psobject]$Entry,
        [Parameter(Mandatory = $true)]
        $PropertyMappings
    )

    if ($Entry -eq $null) {
        Write-Warning "Start-ProcessLogEntry received a null Entry."
        return $null
    }

    $odataType = $Entry.'@odata.type'
    Write-Verbose "Processing Entry with @odata.type: $odataType"

    # Adjusted to access PSCustomObject properties correctly
    $mapping = $PropertyMappings."$odataType"
    if (-not $mapping) {
        # Default mapping
        Write-Warning "No mapping found for $odataType. Using default mapping structure."
        $propertiesToInclude = @("Message", "Severity", "Created", "RecordId")
        $propertyPaths = @{}
        foreach ($prop in $propertiesToInclude) {
            $propertyPaths[$prop] = @($prop)
        }
        $logFormat = "[{Created}] ({Severity}) - [{RecordId}] {Message}"
    } else {
        $propertiesToInclude = @($mapping.Properties.PSObject.Properties.Name)
        $propertyPaths = $mapping.Properties
        $logFormat = $mapping.LogFormat
    }

    Write-Debug "Properties to include: $($propertiesToInclude -join ', ')"
    Write-Debug "Property paths: $($propertyPaths | ConvertTo-Json -Depth 10)"
    Write-Debug "LogFormat: $logFormat"

    #### Function to recursively process properties ####
    function Get-PropertyValue {
        param (
            [psobject]$Object,
            [string[]]$PropertyPath
        )
        if ($null -eq $Object -or $PropertyPath.Count -eq 0) {
            return $null
        }
        $currentObject = $Object
        foreach ($propertyName in $PropertyPath) {
            if ($null -eq $currentObject) {
                return $null
            }
            $currentObject = $currentObject."$propertyName"
        }
        return $currentObject
    }

    $logEvent = [hashtable]@{}
    foreach ($prop in $propertiesToInclude) {
        $propertyPath = $propertyPaths.$prop
        if ($propertyPath -is [string]) {
            # If propertyPath is a string, make it into an array
            $propertyPath = @($propertyPath)
        }
        $value = Get-PropertyValue -Object $Entry -PropertyPath $propertyPath
        Write-Debug "Property '$prop' value: $value"
        $logEvent[$prop] = $value
    }

    # Include the LogFormat in the $logEvent
    $logEvent['LogFormat'] = $logFormat
    Write-Debug "Constructed logEvent: $($logEvent | ConvertTo-Json -Depth 10)"

    return $logEvent
}

#### Function to expand the log format string with the property values ####
function Expand-LogFormat {
    param (
        [string]$FormatString,
        [object]$Values
    )

    if (-not $FormatString) {
        Write-Warning "Expand-LogFormat: FormatString is null or empty."
        return ''
    }

    if (-not $Values) {
        Write-Warning "Expand-LogFormat: Values is null."
        return $FormatString
    }

    $result = $FormatString

    # Find all placeholders in the format string
    $placeholders = [regex]::Matches($FormatString, '\{(\w+)\}')

    foreach ($placeholder in $placeholders) {
        $key = $placeholder.Groups[1].Value
        $value = ''

        if ($Values -is [hashtable]) {
            if ($Values.ContainsKey($key)) {
                $value = $Values[$key]
            }
        } else {
            $prop = $Values.PSObject.Properties[$key]
            if ($prop) {
                $value = $prop.Value
            }
        }

        # Replace the placeholder with the value
        $placeholderText = '{' + $key + '}'
        $result = $result.Replace($placeholderText, [string]$value)
    }

    return $result
}
#endregion Functions

#region Main Script
################################################################################################################################
Write-Output "Executing script against $($TargetURIs.Count) target(s)"
Write-Output "Target URIs: $($TargetURIs -join ', ') `n"

# Load property mappings
try {
    if (Test-Path $PropertyMappingFile) {
        $jsonContent = Get-Content $PropertyMappingFile -Raw
        $propertyMappings = $jsonContent | ConvertFrom-Json
        Write-Debug "Property Mappings Loaded: $($propertyMappings | ConvertTo-Json -Depth 15)"
    } else {
        Write-Warning "Property mapping file not found at $PropertyMappingFile. Using default mappings."
        $propertyMappings = @{}
    }
} catch {
    Write-Error "Failed to load property mappings. Error: $_"
    exit 1
}

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputDirectory)) {
    try {
        New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    } catch {
        Write-Error "Failed to create output directory at $OutputDirectory. Error: $_"
        exit 1
    }
}

## Main script logic ##
foreach ($targetURI in $TargetURIs) {
    Write-Output "|- Processing target: $targetURI"
    try {
        # Authenticate to the target
        Set-TargetAuthentication -URI $targetURI -Credential $Credential

        # Get the system objects
        $systems = Get-Systems

        if (-not $systems) {
            Write-Warning "No systems found for target $targetURI"
            continue
        }

        Write-Output "|- Found $($systems.Count) system(s) for target: $targetURI"

        foreach ($system in $systems) {

            # Get the system ID and name
            $systemID = $system.Id
            if (-not $systemID) {
                Write-Warning "System ID not found for system $targetURI"
                continue
            }
            $systemName = $system.Name -replace '[^\w\.\-]', '_'
            if (-not $systemName -or $systemName -like 'Computer_System' -or $systemName -eq '') {
                $systemName = $system.HostName -replace '[^\w\.\-]', '_'
            }
            if (-not $systemName -or $systemName -eq '') {
                $systemName_uri = $targetURI -replace '[^\w\.\-]', '_'
                $systemName_ID = $systemID -replace '[^\w\.\-]', '_'
                $systemName = "System_$systemName_uri-$systemName_ID"
                
            }
            Write-Output "|-- System ID: $systemID"
            Write-Output "|-- System Name: $systemName"

            # Get the log services object
            $logServices = Get-LogServices -SystemID $systemID
            if ($logServices.Count -eq 0) {
                Write-Warning "No LogServices found for system $targetURI"
                continue
            }

            # For each log service, get the log entries and process them with property mappings
            $systemLogs = @()
            foreach ($logService in $logServices) {
                $logServiceURL = $logService.'@odata.id'

                # Check if there is a trailing slash in the URL
                if ($logServiceURL[-1] -eq '/') {
                    $logServiceURL = $logServiceURL.Substring(0, $logServiceURL.Length - 1)
                }
                $logServiceName = ($logServiceURL -split '/')[-1]
                
                Write-Output "|-- Processing Log Collection: $logServiceName"

                # Get the log entries
                $entries = Get-LogEntries -LogServiceURL $logServiceURL
                $processedEntries = @()

                # Process each entry
                foreach ($entry in $entries) {
                    Write-Debug "Processing Entry ID: $($entry.Id)"
                    $processedEntry = Start-ProcessLogEntry -Entry $entry -PropertyMappings $propertyMappings
                    if ($processedEntry -ne $null) {
                        $processedEntries += $processedEntry
                    } else {
                        Write-Warning "Processed entry is null for Entry ID: $($entry.Id)"
                    }
                }

                # Add the processed entries to the system logs
                $logObject = @{
                    LogServiceName = $logServiceName
                    Entries        = $processedEntries
                }
                $systemLogs += $logObject
                }

                Write-Debug "Log Processing Complete: $($systemLogs | ConvertTo-Json -Depth 15)"

                # Prepare the system information object
                $systemInfo = @{
                    TargetURI = $targetURI
                    SystemID  = $systemID
                    System    = @{
                        Name         = $system.Name
                        Manufacturer = $system.Manufacturer
                        Model        = $system.Model
                        SerialNumber = $system.SerialNumber
                    }
                    Logs      = $systemLogs
                }

                # Get timestamp
                $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

                if ($JSONOutput) {
                    # Write output to JSON file with timestamp
                    $outputFile = Join-Path $OutputDirectory "${systemName}_$timestamp.json"
                    # Remove LogFormat from the output JSON
                    $systemInfo.Logs | ForEach-Object { $_.Entries | ForEach-Object { $_.Remove('LogFormat') } }
                    # Write the system information to a JSON file
                    $systemInfo | ConvertTo-Json -Depth 100 | Out-File -FilePath $outputFile -Encoding utf8
                    Write-Output "|-- Logs saved to JSON file: $outputFile"
                }
                else {
                    # Create directories and write log files
                    $systemDir = Join-Path $OutputDirectory $systemName
                    if (-not (Test-Path $systemDir)) {
                        New-Item -ItemType Directory -Path $systemDir | Out-Null
                    }

                # Include general system information
                $generalInfo = @"
Hostname: $($system.HostName)
System Name: $($system.Name)
System ID: $($system.Id)
Manufacturer: $($system.Manufacturer)
Model: $($system.Model)
Serial Number: $($system.SerialNumber)

"@
                # Write log files for each log service
                foreach ($logObject in $systemInfo.Logs) {
                    $logServiceName = $logObject.LogServiceName
                    $logDir = Join-Path $systemDir $logServiceName

                    Write-Debug "Writing log file for LogService: $logServiceName"

                    # Create the log directory if it doesn't exist
                    if (-not (Test-Path $logDir)) {
                        New-Item -ItemType Directory -Path $logDir | Out-Null
                    }

                    $logFileName = "${logServiceName}_logs_${timestamp}.log"
                    $logFilePath = Join-Path $logDir $logFileName

                    # Build the content of the log file
                    $logContent = $generalInfo + "`n"

                    foreach ($entry in $logObject.Entries) {
                        if ($entry -eq $null) {
                            Write-Warning "Encountered a null entry in log entries."
                            continue
                        }
                    
                        Write-Debug "Processing entry: $($entry | ConvertTo-Json -Depth 10)"
                    
                        # Get the LogFormat from the processed entry
                        $logFormat = $entry['LogFormat']
                        Write-Debug "LogFormat: $logFormat"
                    
                        if (-not $logFormat) {
                            Write-Warning "LogFormat is null or empty for entry: $($entry | ConvertTo-Json -Depth 10)"
                            $logFormat = "[{Created}] ({Severity}) - [{RecordId}] {Message}"
                        }
                    
                        # Build the log line using the custom format
                        $logLine = Expand-LogFormat -FormatString $logFormat -Values $entry
                        Write-Debug "LogLine: $logLine"
                    
                        $logContent += $logLine + "`n"
                    }
                    
                    # Write the log content to file
                    $logContent | Out-File -FilePath $logFilePath -Encoding utf8
                    Write-Output "|-- Log file saved to $logFilePath"
                }
            }

            # Disconnect from the target
            Write-Output "|- Disconnecting from system: $targetURI"
            Disconnect-RedfishTarget -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Error "An error occurred while processing system $targetURI. Error: $_"
        continue
    }
}

#endregion Main Script
################################################################################################################################
