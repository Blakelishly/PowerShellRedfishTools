# Get-RecursiveRedfishLookup.ps1

This PowerShell script connects to one or more Redfish or Swordfish targets, authenticates, and recursively crawls the Redfish API starting from a specified root URL. It collects data from each endpoint and saves the responses in JSON format to an output directory. This script is useful for data center inventory automation or Redfish-compliant hardware management.

The script can filter the URLs to crawl using wildcards, allowing you to limit the scope of the data collection to specific resources.

## Table of Contents

- [Get-RecursiveRedfishLookup.ps1](#get-recursiveredfishlookupps1)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Usage](#usage)
    - [Parameters](#parameters)
    - [Examples](#examples)
      - [Notes](#notes)
  - [License](#license)

## Prerequisites
- **PowerShell 7 or higher**
- **Network access to Redfish/Swordfish-compliant targets**

## Usage

### Parameters

The script accepts the following parameters:

- **TargetURIs (Required):** An array of target URIs (IP addresses or hostnames) to connect to.
- **Credential (Optional):** A PSCredential object for authentication. If not provided, the script will prompt for credentials using Get-Credential.
- **redfishURLRoot (Optional):** The root path for the Redfish API (default: `/redfish/v1/`). Modify if the target uses a different base URL.
- **OutputDirectory (Optional):** The directory where the JSON responses will be saved. If not specified, a directory named `RedfishAPI` is created in the script’s directory.
- **URLFilter (Optional):** A filter for the URL paths to crawl. Wildcards can be used to limit the scope of the crawl. By default, it matches all URLs.

### Examples

**Example 1: Crawl Redfish API and Save Data**

```powershell
$targets = @("10.0.0.16")
$cred = Get-Credential

.\Get-RecursiveRedfishLookup.ps1 -TargetURIs $targets -Credential $cred -OutputDirectory "C:\RedfishData"
```

This example connects to the Redfish target at `10.0.0.16`, prompts for credentials, and crawls the `/redfish/v1/` API. The JSON responses are saved in `C:\RedfishData`.

**Example 2: Crawl Specific URLs Matching a Filter**

```powershell
$targets = @("10.0.0.16", "10.0.0.20")
$cred = Get-Credential

.\Get-RecursiveRedfishLookup.ps1 -TargetURIs $targets -Credential $cred -URLFilter "/redfish/v1/AccountService/Accounts/*/" -RedfishURLRoot "/redfish/v1/AccountService"
```

This example connects to two Redfish targets, filters the URLs to the `/redfish/v1/AccountService` URL root, and only queries entries in the `"/redfish/v1/AccountService/Accounts/*/"` filter, then saves the data to the default output directory.

#### Notes

  - **Credentials:** The script uses a single set of provided credentials to authenticate with the targets. Ensure the account exists across all hosts and that the credentials have the necessary permissions.
  - **Error Handling:** All errors are logged and can be reviewed for troubleshooting. Add the `-Verbose` parameter to see detailed progress information and the `-Debug` parameter for additional debug output.
  - **Compatibility:** The target systems must support the Redfish API.
  - **PowerShell Version:** This script requires PowerShell 7 or higher.
  - **Output Structure:** The script saves the JSON responses in a directory structure that mirrors the API endpoints, facilitating easy navigation and data retrieval.

## License
This script is provided under the MIT License.

Disclaimer: This script is provided as-is without any warranties. Use it at your own risk. Ensure you have permission to access and collect data from the target systems.