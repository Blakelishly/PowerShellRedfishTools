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
    [string]$redfishURLRoot = '/redfish/v1/',

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "RedfishAPI"),

    [Parameter(Mandatory = $false)]
    [string]$URLFilter = '*'
)

#region Variables
$ErrorActionPreference = 'Continue'
#endregion Variables

#region Import Required Modules
# try {
#     Import-Module SNIASwordfish -Force -ErrorAction Stop
# } catch {
#     Write-Error "Failed to import SNIASwordfish module. $_"
#     exit 1
# }
#endregion Import Required Modules

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
            $PowerShellVersion = ($PSVersionTable.PSVersion).major
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

#### Function to recursively crawl the Redfish API ####
# Starting from the root URL, this function crawls the Redfish API and saves the JSON responses to files
function Start-CrawlRedfishResource {
    [CmdletBinding()]
    param (
        # URL to start initial crawling from
        [Parameter(Mandatory = $true)]
        [string]$redfishURLRoot,
        # URL to start crawling from
        [Parameter(Mandatory = $true)]
        [string]$URL,
        # TLD for the output directory
        [Parameter(Mandatory = $true)]
        [string]$OutputDirectory,
        # Use a reference to the VisitedURLs array to keep track of visited URLs throughout the recursion
        [Parameter(Mandatory = $true)]
        [ref]$VisitedURLs,
        # Filter to match URLs against
        [Parameter(Mandatory = $false)]
        [string]$URLFilter = '*'
    )
    # Check if URL has been visited
    if ($VisitedURLs.Value -contains $URL) {
        Write-Verbose "URL $URL has already been visited. Skipping."
        return
    }

    # Check if URL matches the filter
    $relativeURL = $URL
    # Account for BaseURi with trailing slash or without
    if ($Global:BaseUri.EndsWith('/')) {
        $baseUriLength = $Global:BaseUri.Length
    } else {
        $baseUriLength = $Global:BaseUri.Length + 1
    }
    if ($URL.StartsWith($Global:BaseUri)) {
        $relativeURL = $URL.Substring($Global:BaseUri.Length)
    }

    # Trim the URL to get the relative path
    if ($URL.StartsWith($Global:BaseUri)) {
        $relativePath = $URL.Substring($baseUriLength)
    } else {
        # URL does not start with BaseUri, use as is
        $relativePath = $URL -replace '^https?://', ''
    }
    # Make sure the filter doesnt include the base URL
    if ($URLFilter.StartsWith($Global:BaseUri)) {
        $URLFilter = $URLFilter.Substring($baseUriLength)
    } else {
        # URL does not start with BaseUri, use as is
        $URLFilter = $URLFilter -replace '^https?://', ''
    }

    # Match filter
    if ($relativeURL -eq $redfishURLRoot) {
        Write-Verbose "URL $URL matches the filter '$URLFilter'."
    }
    else {
        $match = $false
        $pathSegments = $relativeURL -split '/'
        $filterSegments = $URLFilter -split '/'

        for ($i=0; $i -lt $pathSegments.Count; $i++) {
            if ($i -ge $filterSegments.Count) {
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
            Write-Verbose "URL $URL does not match the filter '$URLFilter'. Skipping."
            return
        }
    }

    # Add URL to VisitedURLs
    $VisitedURLs.Value += $URL

    # Replace any invalid path characters - this is to make the file system happy
    $relativePath = $relativePath -replace '[<>:"/\\|?*]', '_'

    # Initialize response variable
    $response = $null

    # Get the JSON response from the URL
    try {
        Write-Verbose "Fetching URL: $URL"
        $response = Invoke-RedfishWebRequest -Url $URL
    } catch {
        Write-Error "Failed to fetch URL $URL. Error: $_"
        # Create an error object to save to the file
        $response = @{
            'error' = $_.Exception.Message
            # Empty JSON to avoid errors
            'Content' = (@{} | ConvertTo-Json)
        }
    }

    # Fetch the supported HTTP methods from the headers
    $supportedMethods = @()
    Write-Verbose "Fetching supported HTTP methods for URL: $URL"
    if ($response.Headers.Allow) {
        $supportedMethods = $response.Headers.Allow -split ',\s*'
    } else {
        Write-Verbose "Allow header not found in OPTIONS response for $URL"
    }
    $response = $response.Content | ConvertFrom-Json

    # Add supported methods to the response object
    if ($response -is [PSCustomObject]) {
        $response | Add-Member -MemberType NoteProperty -Name 'SupportedHTTPMethods' -Value $supportedMethods
    } elseif ($response -is [hashtable]) {
        $response['SupportedHTTPMethods'] = $supportedMethods
    }

    # Build the full output directory path
    $fullOutputDir = Join-Path $OutputDirectory (($relativePath -split '_') -join '\')

    # Ensure the directory exists
    if (-not (Test-Path $fullOutputDir)) {
        New-Item -ItemType Directory -Path $fullOutputDir -Force | Out-Null
    }

    # Save the JSON response to a file named 'index.json' in the directory
    $jsonOutputFile = Join-Path $fullOutputDir 'index.json'
    Write-Verbose "Saving JSON response to $jsonOutputFile"
    if ($response -ne $null) {
        $response | ConvertTo-Json -Depth 100 | Out-File -FilePath $jsonOutputFile -Encoding utf8
    } else {
        # Save an empty JSON file if no content or error
        @{} | ConvertTo-Json | Out-File -FilePath $jsonOutputFile -Encoding utf8
    }

    # If we didn't get a valid response, we can't proceed further
    if ($response -eq $null -or $response.error) {
        Write-Warning "Skipping further processing for $URL due to error."
        return
    }

    # Now, find all @odata.id entries in the JSON response
    $odataIds = @()

    # Function to recursively find @odata.id entries in the JSON response
    function Get-ODataIds {
        param (
            [object]$obj,
            [ref]$odataIds
        )

        if ($null -eq $obj) {
            return
        }
        elseif ($obj -is [string]) {
            return
        }
        elseif ($obj.GetType().IsPrimitive -or $obj -is [System.ValueType]) {
            # Skip primitive types and value types to prevent infinite recursion
            return
        }
        elseif ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [string])) {
            foreach ($item in $obj) {
                Get-ODataIds -obj $item -odataIds $odataIds
            }
        }
        elseif ($obj -is [PSCustomObject]) {
            foreach ($property in $obj.PSObject.Properties) {
                $key = $property.Name
                $value = $property.Value
                if ($key -eq '@odata.id' -or $key -eq 'href') {
                    $odataIds.Value += $value
                } else {
                    Get-ODataIds -obj $value -odataIds $odataIds
                }
            }
        }
        else {
            # For other object types, attempt to get properties
            $properties = $obj | Get-Member -MemberType Properties -ErrorAction SilentlyContinue
            if ($properties.Count -gt 0) {
                foreach ($property in $properties) {
                    $key = $property.Name
                    $value = $obj.$key
                    if ($key -eq '@odata.id' -or $key -eq 'href') {
                        $odataIds.Value += $value
                    } else {
                        Get-ODataIds -obj $value -odataIds $odataIds
                    }
                }
            }
        }
    }

    # Call the function to find @odata.id entries
    # Returns when all @odata.id entries are found
    Get-ODataIds -obj $response -odataIds ([ref]$odataIds)

    Write-Verbose "Found $($odataIds.Count) @odata.id entries in $URL"

    foreach ($odataId in $odataIds) {
        # Recursively crawl the resource
        Start-CrawlRedfishResource -URL $odataId -OutputDirectory $OutputDirectory -VisitedURLs $VisitedURLs -URLFilter $URLFilter -redfishURLRoot $redfishURLRoot
    }
}
#endregion Functions

#region Main Script
################################################################################################################################
Write-Host "Executing script against $($TargetURIs.Count) target(s)"
Write-Host "Target URIs: $($TargetURIs -join ', ') `n"

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputDirectory)) {
    try {
        New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    } catch {
        Write-Error "Failed to create output directory at $OutputDirectory. Error: $_"
        exit 1
    }
}

foreach ($targetURI in $TargetURIs) {
    Write-Host "|- Processing target: $targetURI"
    try {
        # Authenticate to the target
        Set-TargetAuthentication -URI $targetURI -Credential $Credential

        # Initialize VisitedURLs
        $VisitedURLs = @()

        # Make subdirectory for the target
        $targetOutputDirectory = Join-Path $OutputDirectory ($targetURI -replace '[<>:"/\\|?*]', '_')
        if (-not (Test-Path $targetOutputDirectory)) {
            New-Item -ItemType Directory -Path $targetOutputDirectory | Out-Null
        }
        
        # Start crawling from /redfish/v1/
        Start-CrawlRedfishResource -URL $redfishURLRoot -OutputDirectory $targetOutputDirectory -VisitedURLs ([ref]$VisitedURLs) -URLFilter $URLFilter -redfishURLRoot $redfishURLRoot

        # Disconnect from the target
        Write-Host "|- Disconnecting from system: $targetURI"
        Disconnect-RedfishTarget -ErrorAction SilentlyContinue

    } catch {
        Write-Error "An error occurred while processing target $targetURI. Error: $_"
        continue
    }
}

#endregion Main Script
################################################################################################################################