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
    A PowerShell script to interactively perform GET, SET, and DELETE operations on a Redfish/Swordfish API target based on an action mapping file.

.DESCRIPTION
    This script connects to a Redfish/Swordfish API target, authenticates the session, and provides an interactive CLI for managing resources. Users can select from predefined actions specified in an action mapping JSON file to perform GET, SET, and DELETE operations. The script facilitates automation and management tasks on Redfish-compliant hardware systems.

.PARAMETER TargetURI
    Specifies the Redfish target URI (IP address or hostname). This is a mandatory parameter.

.PARAMETER Credential
    The credential to use for authentication (username and password). By default, the script prompts for credentials using `Get-Credential`.

.PARAMETER ActionMappingFile
    The path to the JSON file containing action mappings for the script. If not specified, a file named `ActionMapping.json` in the script's directory is used.

.EXAMPLE
    .\Invoke-RemoteManagementActions.ps1 -TargetURI "10.0.0.16" -Credential (Get-Credential) -ActionMappingFile "C:\Config\ActionMapping.json"

    This example connects to the Redfish target at `10.0.0.16`, prompts for credentials, loads the action mappings from `C:\Config\ActionMapping.json`, and starts the interactive CLI.

.EXAMPLE
    .\Invoke-RemoteManagementActions.ps1 -TargetURI "10.0.0.16" -Credential (Get-Credential)

    This example connects to the Redfish target at `10.0.0.16`, prompts for credentials, uses the default `ActionMapping.json` file in the script's directory, and starts the interactive CLI.

.NOTES
    - This script requires PowerShell 7 or higher.
    - The target must support the Redfish/Swordfish API.
    - Ensure proper permissions are granted for the provided credentials.
    - The `ActionMapping.json` file defines available actions and their execution details.
    - All errors are logged and can be reviewed for troubleshooting.

.LICENSE
    MIT License (c) 2024 Blake Cherry
#>
################################################################################################################################
# Define parameters
param (
    [Parameter(Mandatory = $true)]
    [string]$TargetURI,  # The URI of the target Redfish/Swordfish service

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential = (Get-Credential),  # Credentials for authentication

    [Parameter(Mandatory = $false)]
    [string]$ActionMappingFile = 'ActionMapping.json'  # File containing action mappings
)

#region Variables
$ErrorActionPreference = 'Continue'  # Continue execution on non-terminating errors
#endregion Variables

#region Functions
################################################################################################################################
# Function: Connect-SwordfishTarget2
# Description: Establishes a connection to the Swordfish/Redfish target by setting global variables
function Connect-SwordfishTarget2 {
    [CmdletBinding(DefaultParameterSetName='Default')]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Target,       # Target hostname or IP address

        [string]$Port,         # Port number for connection

        [Validateset("http","https")]
        [string]$Protocol = "https"  # Protocol to use (http or https)
    )
    Process {
        # Construct the base URI based on protocol
        if ($Protocol -eq 'http') {
            $Global:Base = "http://$($Target):$($Port)"
        } else {   
            $Global:Base = "https://$($Target)"
        }

        # Set the Redfish API root path
        $Global:RedFishRoot = "/redfish/v1/"
        $Global:BaseTarget  = $Target
        $Global:BaseUri     = $Base + $RedfishRoot    
        $Global:MOCK        = $false  # Indicates whether to use mock data

        Try {   
            # Attempt to retrieve the root Redfish service
            $ReturnData = Invoke-RestMethod -Uri "$BaseUri" -SkipCertificateCheck
        }
        Catch {
            Write-Error "No RedFish/Swordfish target detected or wrong port used at that address. Error: $_"
            exit 1
        }

        if ($ReturnData) {
            # Connection successful; set global variables
            Write-Verbose "The Global Redfish Root Location variable named RedfishRoot will be set to $RedfishRoot"
            Write-Verbose "The Global Base Target Location variable named BaseTarget will be set to $BaseTarget"
            Write-Verbose "The Global Base Uri Location variable named BaseUri will be set to $BaseUri"            
            return $ReturnData
        } 
        else {   
            # Connection failed; clean up global variables
            Write-Verbose "Since no connection was made, the global connection variables have been removed"
            Remove-Variable -Name RedfishRoot -Scope Global
            Remove-Variable -Name BaseTarget -Scope Global
            Remove-Variable -Name Base -Scope Global
            Remove-Variable -Name BaseUri -Scope Global
            Remove-Variable -Name MOCK -Scope Global
            Write-Error "No RedFish/Swordfish target detected or wrong port used at that address"
        }
    }
}
Set-Alias -Name 'Connect-RedfishTarget2' -Value 'Connect-SwordfishTarget2'  # Alias for the connection function

#### Function: Set-TargetAuthentication ####
# Description: Authenticates to the Redfish/Swordfish target by obtaining a session token
function Set-TargetAuthentication {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$URI,  # The URI of the target Redfish/Swordfish service

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential  # User credentials
    )
    try {
        # Clear existing session variables
        $Global:XAuthToken = $null
        $Global:SessionUri = $null
        $Global:RedfishRoot = $null
        $Global:BaseTarget = $null
        $Global:Base = $null
        $Global:BaseUri = $null
        $Global:MOCK = $null

        # Connect to the target
        Write-Verbose "Connecting to Redfish target at $URI"
        $connect = Connect-RedfishTarget2 -Target $URI
        Write-Verbose "Attempting to get session token"

        if (-not $BaseUri) {   
            Write-Warning "This command requires that you run the Connect-SwordfishTarget2 or Connect-RedfishTarget2 first."
            return
        }

        # Prepare the authentication body
        $SSBody = @{
            UserName = $Credential.UserName
            Password = $Credential.GetNetworkCredential().Password
        }
        $SSContType = @{ 'Content-type' = 'Application/json' }
        $BodyJSON = $SSBody | ConvertTo-Json

        # Send POST request to create a session
        $authResult = Invoke-WebRequest -Uri ($BaseUri + "SessionService/Sessions") `
                                       -Headers $SSContType `
                                       -Method Post `
                                       -Body $BodyJSON `
                                       -SkipCertificateCheck                        

        if ($authResult) {
            # Extract the authentication token from headers
            $Global:XAuthToken = (($authResult.Headers).'X-Auth-Token')

            # Determine the session URI from headers or response content
            if ($authResult.Headers.Location) {
                $NewSessionUri = $authResult.Headers.Location
            } else {
                $NewSessionUri = ($authResult.Content | ConvertFrom-Json).message
            }

            $baseUriLength = $Global:Base.Length
            if ($NewSessionUri.StartsWith($Global:Base)) {
                $Global:SessionUri = $NewSessionUri.Substring($baseUriLength)
            } else {
                # If URL does not start with BaseUri, use as is without the protocol
                $Global:SessionUri = $NewSessionUri -replace '^https?://', ''
            }

            Write-Verbose "XAuthToken set to $Global:XAuthToken"
            Write-Verbose "SessionUri set to $Global:SessionUri"
        } else {
            Write-Error "No RedFish/Swordfish target detected or wrong port used at that address"
            exit 1
        }

        # Ensure XAuthToken is a single value
        if ($XAuthToken -is [array]) {
            $Global:XAuthToken = $XAuthToken[0]
        } else {
            $Global:XAuthToken = $XAuthToken
        }
    } catch {
        Write-Error "Failed to authenticate to $URI. Error: $_"
        exit 1
    }
}

#### Function: Disconnect-SwordfishTarget ####
# Description: Disconnects from the Redfish/Swordfish target by terminating the session
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
                $disconnect = Invoke-RestMethod -Method Delete `
                                                 -Uri ($Global:Base + $Global:SessionUri) `
                                                 -Headers $headers `
                                                 -SkipCertificateCheck
                Write-Verbose "Session disconnected successfully. Response: $($disconnect | ConvertTo-Json)"
            } else {
                Write-Warning "Session URI is not available. Cannot disconnect the session."
            }

            # Clear the session token variable
            Remove-Variable -Name XAuthToken -Scope Global -ErrorAction SilentlyContinue
        } catch {
            Write-Error "Failed to disconnect the session. Error: $_"
        }
    }
}
Set-Alias -Name 'Disconnect-RedfishTarget' -Value 'Disconnect-SwordfishTarget'  # Alias for the disconnect function

#### Function: Invoke-RedfishWebRequest ####
# Description: Sends web requests to the Redfish API, handling authentication headers
function Invoke-RedfishWebRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$URL,  # The endpoint URL for the request

        [string]$Method = 'GET',  # HTTP method to use

        $Body  # Body content for POST/PATCH requests
    )
    try {
        # Construct the full URL
        if ($URL -notmatch '^https?://') {
            $fullURL = $Global:Base + $URL
        } else {
            $fullURL = $URL
        }
        # If there are 2 trailing slashes, remove one
        $fullURL = $fullURL -replace '([^:])//', '$1/'

        # Prepare headers with authentication token if available
        $headers = @{}
        if ($Global:XAuthToken) {
            $headers['X-Auth-Token'] = $Global:XAuthToken
        }
        else {
            Write-Warning "No auth token is configured. Skipping headers."
        }

        # Log the request
        Write-Verbose "Sending $Method request to $fullURL"

        # Send the web request based on the presence of a body
        if ($Body) {   
            $response = Invoke-WebRequest -Method $Method `
                                         -Uri $fullURL `
                                         -Headers $headers `
                                         -SkipCertificateCheck `
                                         -Body $Body `
                                         -ContentType 'application/json'
        } else {   
            $response = Invoke-WebRequest -Method $Method `
                                         -Uri $fullURL `
                                         -Headers $headers `
                                         -SkipCertificateCheck
        }

        return $response
    } catch {
        Write-Error "Failed to get data from $URL. Error: $_"
        throw $_
    }
}

#### Function: Get-NestedPropertyValue ####
# Description: Retrieves the value of a nested property within a PowerShell object
function Get-NestedPropertyValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [psobject]$Object,  # The object to traverse

        [Parameter(Mandatory = $true)]
        [string[]]$PropertyPath  # Array representing the path to the desired property
    )

    $currentObject = $Object
    foreach ($propertyName in $PropertyPath) {
        if ($null -eq $currentObject) {
            return $null
        }
        $currentObject = $currentObject."$propertyName"
    }
    return $currentObject
}

#### Function: Start-CrawlRedfishResource ####
# Description: Recursively crawls the Redfish API starting from a given URL and collects JSON responses
function Start-CrawlRedfishResource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$redfishURLRoot,  # Root URL to start crawling

        [Parameter(Mandatory = $true)]
        [string]$URL,  # Current URL to crawl

        [Parameter(Mandatory = $true)]
        [ref]$VisitedURLs,  # Reference to array tracking visited URLs

        [Parameter(Mandatory = $false)]
        [string]$URLFilter = '*',  # Filter pattern for URLs

        [Parameter(Mandatory = $true)]
        [ref]$Results  # Reference to hashtable storing results
    )

    # Skip if URL has already been visited
    if ($VisitedURLs.Value -contains $URL) {
        Write-Verbose "URL $URL has already been visited. Skipping."
        return
    }

    # Determine the relative URL based on BaseUri
    $relativeURL = ""
    if ($URL.StartsWith($Global:BaseUri)) {
        if ($URL.Length -ge $Global:BaseUri.Length) {
            $relativeURL = $URL.Substring($Global:BaseUri.Length)
        } else {
            Write-Warning "URL '$URL' is shorter than BaseUri '$Global:BaseUri'. Skipping Substring."
            $relativeURL = ""
        }
    } else {
        $relativeURL = $URL -replace '^https?://', ''
    }

    # Check if the URL matches the provided filter
    if ($relativeURL -eq $redfishURLRoot) {
        Write-Verbose "URL $URL matches the filter '$URLFilter'."
    }
    else {
        $match = $false
        $pathSegments = $relativeURL -split '/'
        $filterSegments = $URLFilter -split '/'
        Write-Debug "Checking URL $URL against the filter '$URLFilter'."

        for ($i=0; $i -lt $pathSegments.Count; $i++) {
            Write-Debug "Comparing path segment '$($pathSegments[$i])' with filter segment '$($filterSegments[$i])'"
            # If the path segment is empty, skip comparison
            if (-not $pathSegments[$i] -or $pathSegments[$i] -eq '') {
                continue
            }
            elseif ($i -ge $filterSegments.Count) {
                $match = $false
                break
            }
            elseif ($filterSegments[$i] -eq '*') {
                $match = $true
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

    # Mark the URL as visited
    $VisitedURLs.Value += $URL

    # Initialize response variable
    $response = $null

    # Attempt to retrieve the JSON content from the URL
    try {
        Write-Verbose "Fetching URL: $URL"
        $response = Invoke-RedfishWebRequest -URL $URL
    } catch {
        Write-Error "Failed to fetch URL $URL. Error: $_"
        # Store error information in the results
        $response = @{
            'error' = $_.Exception.Message
            'Content' = @{}
        }
    }

    # Skip processing if the response is invalid or contains an error
    if ($response -eq $null -or $response.error) {
        Write-Warning "Skipping further processing for $URL due to error."
        return
    }

    # Convert the response content from JSON
    $content = $response.Content | ConvertFrom-Json

    # Store the content in the results hashtable
    $Results.Value[$URL] = $content

    # Initialize array to collect @odata.id entries
    $odataIds = @()

    # Function: Get-ODataIds
    # Description: Recursively extracts all @odata.id and href entries from the JSON object
    function Get-ODataIds {
        param (
            [object]$obj,          # Current object to inspect
            [ref]$odataIds         # Reference to the array collecting @odata.id entries
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
            # Iterate through each item in the collection
            foreach ($item in $obj) {
                Get-ODataIds -obj $item -odataIds $odataIds
            }
        }
        elseif ($obj -is [PSCustomObject]) {
            # Iterate through each property of the object
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

    # Extract all @odata.id entries from the current JSON content
    Get-ODataIds -obj $content -odataIds ([ref]$odataIds)

    Write-Verbose "Found $($odataIds.Count) @odata.id entries in $URL"

    # Recursively crawl each discovered @odata.id
    foreach ($odataId in $odataIds) {
        # Start crawling from the new URL
        Start-CrawlRedfishResource -URL $odataId `
                                   -VisitedURLs $VisitedURLs `
                                   -URLFilter $URLFilter `
                                   -Results $Results `
                                   -redfishURLRoot $redfishURLRoot
    }
}

#### Function: Perform-GetOperation ####
# Description: Handles the GET operation and displays current values
function Perform-GetOperation {
    param (
        [string[]]$getResourceUris,
        [object]$command
    )

    foreach ($getResourceUri in $getResourceUris) {
        Write-Host "`nProcessing GET resource: $getResourceUri"

        # Get the resource data from Results_GET
        $data = $Results_GET[$getResourceUri]

        Write-Verbose $data | Get-TypeData
        Write-Verbose $data | Select-Object *

        # Retrieve GET command details
        $getCommand = $command.GetCommand

        # Display current values based on property paths
        if ($getCommand) {
            $propertyPaths = $getCommand.PropertyNames

            if ($propertyPaths) {
                Write-Host "Current values:"
                foreach ($propertyPath in $propertyPaths) {
                    $value = Get-NestedPropertyValue -Object $data -PropertyPath $propertyPath
                    # Join the property path with dots for display purposes
                    $propName = ($propertyPath -join '.')
                    Write-Host "$propName : $value"
                }
            } else {
                Write-Host "Response data:"
                $data | Format-List
            }
        }
    }
}

#### Function: Perform-SetOperation ####
# Description: Handles the SET operation including POST/PATCH requests and retrieves updated values
function Perform-SetOperation {
    param (
        [string]$setResourceUri,
        [string]$method,
        [string]$bodyJson,
        [object]$command
    )

    try {
        # Execute the PATCH or POST request
        $response = Invoke-RedfishWebRequest -URL $setResourceUri -Method $method -Body $bodyJson
        Write-Host "Response:"
        # Serialize only the Content property to avoid duplicate keys
        $response.Content | ConvertTo-Json -Depth 100 | Write-Host

        # Extract the new resource URI from the response message
        $parsedResponse = $response.Content | ConvertFrom-Json
        $newResourceUri = $parsedResponse.message

        if ($newResourceUri) {
            Write-Host "Fetching the newly created or updated resource at $newResourceUri"
            $newResponse = Invoke-RedfishWebRequest -URL $newResourceUri -Method 'GET'
            $newData = $newResponse.Content | ConvertFrom-Json

            # Display the updated values based on PropertyNames
            Write-Host "Updated values:"
            foreach ($propertyPath in $command.GetCommand.PropertyNames) {
                $value = Get-NestedPropertyValue -Object $newData -PropertyPath $propertyPath
                $propName = ($propertyPath -join '.')
                Write-Host "$propName : $value"
            }
        } else {
            Write-Warning "No new resource URI found in the response."
        }
    } catch {
        Write-Warning "Failed to execute $method request to $setResourceUri. Error: $_"
        continue
    }
}

#### Function: Perform-DeleteOperation ####
# Description: Handles the DELETE operation, including selecting the resource to delete and confirming deletion
function Perform-DeleteOperation {
    param (
        [string]$deleteResourceFilter,
        [object]$command
    )

    # Initialize VisitedURLs and Results for DELETE crawling
    $VisitedURLs_DELETE = @()
    $Results_DELETE = @{}

    # Start crawling with DeleteResourceFilter to find resources eligible for deletion
    Start-CrawlRedfishResource -URL "$baseUri/" `
                               -VisitedURLs ([ref]$VisitedURLs_DELETE) `
                               -URLFilter $deleteResourceFilter `
                               -Results ([ref]$Results_DELETE) `
                               -redfishURLRoot '/'

    Write-Debug "DELETE resourceUris: $($Results_DELETE.Keys)"

    # Filter the Results to get the resource URIs matching the DeleteResourceFilter
    $deleteResourceUris = $Results_DELETE.Keys | Where-Object {
        if ($_.StartsWith($baseUri)) {
            if ($_.Length -ge $baseUri.Length) {
                $relativeUrl = $_.Substring($baseUri.Length)
            } else {
                Write-Warning "Resource URI '$_' is shorter than BaseUri '$baseUri'. Skipping Substring."
                $relativeUrl = ""
            }
        } else {
            $relativeUrl = $_ -replace '^https?://', ''
        }

        # Ensure both relativeUrl and resourceFilter end with a slash for accurate comparison
        if ($relativeUrl.EndsWith('/') -ne $deleteResourceFilter.EndsWith('/')) {
            if ($relativeUrl.EndsWith('/')) {
                $relativeUrl = $relativeUrl.TrimEnd('/')
            } else {
                $relativeUrl += '/'
            }
        }

        $relativeUrl -like $deleteResourceFilter
    }
    Write-Verbose "Found $($deleteResourceUris.Count) DELETE resources matching filter '$deleteResourceFilter'"

    if (-not $deleteResourceUris) {
        Write-Warning "No DELETE resources found matching filter '$deleteResourceFilter'"
        return
    }

    # Display available resources for deletion
    Write-Host "`nAvailable resources for deletion:"
    for ($i = 0; $i -lt $deleteResourceUris.Count; $i++) {
        $uri = $deleteResourceUris[$i]
        $data = $Results_DELETE[$uri]
        $name = $data.Name
        $id = $data.Id
        Write-Host "$($i+1). $name (ID: $id) - $uri"
    }
    Write-Host "$($deleteResourceUris.Count+1). Cancel"

    # Prompt user to select a resource to delete
    $selection = Read-Host "Select a resource to delete by number"

    [int]$selectedIndex = 0

    if ([int]::TryParse($selection, [ref]$selectedIndex)) {
        if ($selectedIndex -eq ($deleteResourceUris.Count + 1)) {
            Write-Host "Deletion canceled."
            return
        }
        elseif ($selectedIndex -ge 1 -and $selectedIndex -le $deleteResourceUris.Count) {
            $resourceUri = $deleteResourceUris[$selectedIndex - 1]
            Write-Host "`nYou have selected to delete: $resourceUri"

            # Confirm deletion
            $confirm = Read-Host "Are you sure you want to delete this resource? Type 'Yes' to confirm"
            if ($confirm -ne 'Yes') {
                Write-Host "Deletion canceled."
                return
            }

            # Perform DELETE request
            try {
                Write-Verbose "Sending DELETE request to $resourceUri"
                $deleteResponse = Invoke-RedfishWebRequest -URL $resourceUri -Method 'DELETE' -ErrorAction SilentlyContinue
                Write-Host "DELETE request sent successfully."

                # Optionally, confirm deletion by attempting to GET the resource
                try {
                    Write-Verbose "Attempting to confirm deletion by sending GET request to $resourceUri"
                    $confirmResponse = Invoke-RedfishWebRequest -URL $resourceUri -Method 'GET'
                    Write-Warning "Resource still exists after deletion attempt."
                } catch {
                    Write-Host "Deletion confirmed: Resource no longer exists."
                }

            } catch {
                Write-Warning "Failed to execute DELETE request to $resourceUri. Error: $_"
                return
            }

        } else {
            Write-Host "Invalid selection. Please try again."
        }
    } else {
        Write-Host "Invalid input. Please enter a number."
    }
}
#endregion Functions

#region Main Script
################################################################################################################################
# Main execution block

# Validate that TargetURI is a string
if ($TargetURI -isnot [string]) {
    Write-Error "TargetURI must be a string"
    return
}
# Validate that ActionMappingFile exists
if (-not (Test-Path -Path $ActionMappingFile)) {
    Write-Error "ActionMappingFile '$ActionMappingFile' does not exist"
    return
}

Write-Host "Executing script against $TargetURI target"

Write-Host "Processing target: $TargetURI"
try {
    Write-Debug "Attempting to authenticate to $TargetURI"

    # Authenticate to the target
    Set-TargetAuthentication -URI $TargetURI -Credential $Credential

    # Read the action mappings from the JSON file
    $actionMappings = Get-Content -Path $ActionMappingFile | ConvertFrom-Json

    # Start interactive CLI application
    $exitApp = $false
    while (-not $exitApp) {
        Write-Host "`nSelect an operation type:"
        $operationTypes = @("Get", "Set", "Delete", "Exit")
        
        for ($i = 0; $i -lt $operationTypes.Count; $i++) {
            Write-Host "$($i + 1). $($operationTypes[$i])"
        }

        # Prompt user for operation type selection
        $opSelection = Read-Host "Select an operation by number"

        [int]$opIndex = 0

        if ([int]::TryParse($opSelection, [ref]$opIndex)) {
            if ($opIndex -ge 1 -and $opIndex -le ($operationTypes.Count - 1)) {
                $selectedOperation = $operationTypes[$opIndex - 1]
                
                switch ($selectedOperation) {
                    "Get" {
                        # Gather actions that support GET
                        $availableActions = $actionMappings.PSObject.Properties | Where-Object {
                            $_.Value.GetCommand -ne $null -and $_.Value.GetCommand.Method -ne ""
                        }

                        if ($availableActions.Count -eq 0) {
                            Write-Warning "No actions available for GET operations."
                            continue
                        }

                        Write-Host "`nAvailable GET actions:"
                        for ($i = 0; $i -lt $availableActions.Count; $i++) {
                            Write-Host "$($i + 1). $($availableActions[$i].Name)"
                        }
                        Write-Host "$($availableActions.Count + 1). Back to Operation Selection"

                        # Prompt user for action selection
                        $actionSelection = Read-Host "Select a GET action by number"

                        [int]$actionIndex = 0

                        if ([int]::TryParse($actionSelection, [ref]$actionIndex)) {
                            if ($actionIndex -eq ($availableActions.Count + 1)) {
                                continue  # Go back to operation selection
                            }
                            elseif ($actionIndex -ge 1 -and $actionIndex -le $availableActions.Count) {
                                $actionName = $availableActions[$actionIndex - 1].Name
                                $action = $availableActions[$actionIndex - 1].Value

                                # Perform GET Operation
                                Write-Host "`n--- GET Operation for '$actionName' ---"

                                # Retrieve the GetResourceFilter for the selected action
                                $getResourceFilter = $action.GetResourceFilter

                                # --------------------- GET OPERATIONS ---------------------
                                # [Existing GET operation logic]
                                # Initialize VisitedURLs and Results_GET hashtables for GET
                                $VisitedURLs_GET = @()
                                $Results_GET = @{}

                                # Start crawling from the base URI for GET operations
                                Start-CrawlRedfishResource -URL "$baseUri/" `
                                                        -VisitedURLs ([ref]$VisitedURLs_GET) `
                                                        -URLFilter $getResourceFilter `
                                                        -Results ([ref]$Results_GET) `
                                                        -redfishURLRoot '/'

                                Write-Debug "GET resourceUris: $($Results_GET.Keys)"

                                # Filter the Results to get the resource URIs matching the GetResourceFilter
                                $getResourceUris = $Results_GET.Keys | Where-Object {
                                    if ($_.StartsWith($baseUri)) {
                                        if ($_.Length -ge $baseUri.Length) {
                                            $relativeUrl = $_.Substring($baseUri.Length)
                                        } else {
                                            Write-Warning "Resource URI '$_' is shorter than BaseUri '$baseUri'. Skipping Substring."
                                            $relativeUrl = ""
                                        }
                                    } else {
                                        $relativeUrl = $_ -replace '^https?://', ''
                                    }

                                    # Ensure both relativeUrl and resourceFilter end with a slash for accurate comparison
                                    if ($relativeUrl.EndsWith('/') -ne $getResourceFilter.EndsWith('/')) {
                                        if ($relativeUrl.EndsWith('/')) {
                                            $relativeUrl = $relativeUrl.TrimEnd('/')
                                        } else {
                                            $relativeUrl += '/'
                                        }
                                    }

                                    $relativeUrl -like $getResourceFilter
                                }
                                Write-Verbose "Found $($getResourceUris.Count) GET resources matching filter '$getResourceFilter'"

                                if (-not $getResourceUris) {
                                    Write-Warning "No GET resources found matching filter '$getResourceFilter'"
                                } else {
                                    # Perform GET operations
                                    Perform-GetOperation -getResourceUris $getResourceUris -command $action
                                }
                            } else {
                                Write-Host "Invalid selection. Please try again."
                            }
                        } else {
                            Write-Host "Invalid input. Please enter a number."
                        }
                    }

                    "Set" {
                        # Gather actions that support SET
                        $availableActions = $actionMappings.PSObject.Properties | Where-Object {
                            $_.Value.SetCommand -ne $null -and $_.Value.SetCommand.Method -ne ""
                        }

                        if ($availableActions.Count -eq 0) {
                            Write-Warning "No actions available for SET operations."
                            continue
                        }

                        Write-Host "`nAvailable SET actions:"
                        for ($i = 0; $i -lt $availableActions.Count; $i++) {
                            Write-Host "$($i + 1). $($availableActions[$i].Name)"
                        }
                        Write-Host "$($availableActions.Count + 1). Back to Operation Selection"

                        # Prompt user for action selection
                        $actionSelection = Read-Host "Select a SET action by number"

                        [int]$actionIndex = 0

                        if ([int]::TryParse($actionSelection, [ref]$actionIndex)) {
                            if ($actionIndex -eq ($availableActions.Count + 1)) {
                                continue  # Go back to operation selection
                            }
                            elseif ($actionIndex -ge 1 -and $actionIndex -le $availableActions.Count) {
                                $actionName = $availableActions[$actionIndex - 1].Name
                                $action = $availableActions[$actionIndex - 1].Value

                                # Perform SET Operation
                                Write-Host "`n--- SET Operation for '$actionName' ---"

                                # Retrieve the SetResourceFilter for the selected action
                                $setResourceFilter = $action.SetResourceFilter

                                # --------------------- SET OPERATIONS ---------------------
                                # Initialize VisitedURLs and Results_SET hashtables for SET
                                $VisitedURLs_SET = @()
                                $Results_SET = @{}

                                # Start crawling from the base URI for SET operations
                                Start-CrawlRedfishResource -URL "$baseUri/" `
                                                        -VisitedURLs ([ref]$VisitedURLs_SET) `
                                                        -URLFilter $setResourceFilter `
                                                        -Results ([ref]$Results_SET) `
                                                        -redfishURLRoot '/'

                                Write-Debug "SET resourceUris: $($Results_SET.Keys)"

                                # Filter the Results to get the resource URIs matching the SetResourceFilter
                                $setResourceUris = $Results_SET.Keys | Where-Object {
                                    if ($_.StartsWith($baseUri)) {
                                        if ($_.Length -ge $baseUri.Length) {
                                            $relativeUrl = $_.Substring($baseUri.Length)
                                        } else {
                                            Write-Warning "Resource URI '$_' is shorter than BaseUri '$baseUri'. Skipping Substring."
                                            $relativeUrl = ""
                                        }
                                    } else {
                                        $relativeUrl = $_ -replace '^https?://', ''
                                    }

                                    # Ensure both relativeUrl and resourceFilter end with a slash for accurate comparison
                                    if ($relativeUrl.EndsWith('/') -ne $setResourceFilter.EndsWith('/')) {
                                        if ($relativeUrl.EndsWith('/')) {
                                            $relativeUrl = $relativeUrl.TrimEnd('/')
                                        } else {
                                            $relativeUrl += '/'
                                        }
                                    }

                                    $relativeUrl -like $setResourceFilter
                                }
                                Write-Verbose "Found $($setResourceUris.Count) SET resources matching filter '$setResourceFilter'"

                                if (-not $setResourceUris) {
                                    Write-Warning "No SET resources found matching filter '$setResourceFilter'"
                                    continue
                                } else {
                                    # Process each SET resource URI
                                    foreach ($setResourceUri in $setResourceUris) {
                                        Write-Host "`nProcessing SET resource: $setResourceUri"

                                        # Get the resource data from Results_SET
                                        $data = $Results_SET[$setResourceUri]

                                        Write-Verbose $data | Get-TypeData
                                        Write-Verbose $data | Select-Object *

                                        # Retrieve SET command details
                                        $setCommand = $action.SetCommand

                                        $method = $setCommand.Method
                                        if (-not $method) { $method = 'PATCH' }  # Default to PATCH if method not specified

                                        $bodyTemplate = $setCommand.BodyTemplate

                                        # Function: Get-PlaceholdersFromTemplate
                                        # Description: Extracts placeholders from the body template for user input
                                        function Get-PlaceholdersFromTemplate($template) {
                                            $placeholders = @()
                                            $jsonString = $template | ConvertTo-Json -Depth 100
                                            $matches = [regex]::Matches($jsonString, '{{\s*(.*?)\s*}}')
                                            foreach ($match in $matches) {
                                                $placeholders += $match.Groups[1].Value
                                            }
                                            return $placeholders
                                        }

                                        $placeholders = Get-PlaceholdersFromTemplate $bodyTemplate

                                        $userInputs = @{}

                                        # Prompt user for each placeholder value
                                        foreach ($placeholder in $placeholders | Select-Object -Unique) {
                                            $userInput = Read-Host "Enter value for $placeholder"
                                            $userInputs[$placeholder] = $userInput
                                        }

                                        # Function: ReplacePlaceholdersInTemplate
                                        # Description: Replaces placeholders in the body template with user-provided values
                                        function ReplacePlaceholdersInTemplate($template, $values) {
                                            $jsonString = $template | ConvertTo-Json -Depth 100
                                            foreach ($key in $values.Keys) {
                                                $value = $values[$key] -replace '"', '\"'
                                                $jsonString = $jsonString -replace "{{\s*$key\s*}}", $value
                                            }
                                            return $jsonString | ConvertFrom-Json
                                        }

                                        $body = ReplacePlaceholdersInTemplate $bodyTemplate $userInputs

                                        # Convert the body to JSON
                                        $bodyJson = $body | ConvertTo-Json -Depth 100

                                        Write-Host "Sending $method request to $setResourceUri with body:"
                                        Write-Host $bodyJson

                                        # Perform the SET operation
                                        Perform-SetOperation -setResourceUri $setResourceUri `
                                                            -method $method `
                                                            -bodyJson $bodyJson `
                                                            -command $action
                                    }
                                }
                            } else {
                                Write-Host "Invalid selection. Please try again."
                            }
                        } else {
                            Write-Host "Invalid input. Please enter a number."
                        }
                    }

                    "Delete" {
                        # Gather actions that support DELETE
                        $availableActions = $actionMappings.PSObject.Properties | Where-Object {
                            $_.Value.DeleteResourceFilter -ne $null -and $_.Value.DeleteResourceFilter -ne ''
                        }

                        if ($availableActions.Count -eq 0) {
                            Write-Warning "No actions available for DELETE operations."
                            continue
                        }

                        Write-Host "`nAvailable DELETE actions:"
                        for ($i = 0; $i -lt $availableActions.Count; $i++) {
                            Write-Host "$($i + 1). $($availableActions[$i].Name)"
                        }
                        Write-Host "$($availableActions.Count + 1). Back to Operation Selection"

                        # Prompt user for action selection
                        $actionSelection = Read-Host "Select a DELETE action by number"

                        [int]$actionIndex = 0

                        if ([int]::TryParse($actionSelection, [ref]$actionIndex)) {
                            if ($actionIndex -eq ($availableActions.Count + 1)) {
                                continue  # Go back to operation selection
                            }
                            elseif ($actionIndex -ge 1 -and $actionIndex -le $availableActions.Count) {
                                $actionName = $availableActions[$actionIndex - 1].Name
                                $action = $availableActions[$actionIndex - 1].Value

                                # Perform DELETE Operation
                                Write-Host "`n--- DELETE Operation for '$actionName' ---"

                                # Retrieve the DeleteResourceFilter for the selected action
                                $deleteResourceFilter = $action.DeleteResourceFilter

                                # --------------------- DELETE OPERATIONS ---------------------
                                # Perform the DELETE operation
                                Perform-DeleteOperation -deleteResourceFilter $deleteResourceFilter `
                                                        -command $action
                            } else {
                                Write-Host "Invalid selection. Please try again."
                            }
                        } else {
                            Write-Host "Invalid input. Please enter a number."
                        }
                    }

                    default {
                        Write-Host "Invalid operation type selected."
                    }
                }
            }
            elseif ($opIndex -eq $operationTypes.Count) {
                # User selected Exit
                $exitApp = $true
            }
            else {
                Write-Host "Invalid selection. Please try again."
            }
        }
        else {
            Write-Host "Invalid input. Please enter a number."
        }
    }

    # Disconnect from the target after operations are complete
    Write-Host "Disconnecting from system: $TargetURI"
    Disconnect-RedfishTarget -ErrorAction SilentlyContinue

} catch {
    Write-Error "An error occurred while processing target $TargetURI. Error: $_"
    continue
}
#endregion Main Script