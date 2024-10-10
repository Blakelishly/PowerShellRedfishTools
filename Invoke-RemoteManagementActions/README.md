# Invoke-RemoteManagementActions.ps1

This PowerShell script provides an interactive command-line interface (CLI) for performing **GET**, **SET**, and **DELETE** operations on a Redfish/Swordfish API target based on predefined action mappings specified in a JSON file. It facilitates automation and management tasks on Redfish-compliant hardware systems.

## Table of Contents

- [Invoke-RemoteManagementActions.ps1](#invoke-remotemanagementactionsps1)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Usage](#usage)
    - [Parameters](#parameters)
    - [Action Mapping File](#action-mapping-file)
      - [Creating `ActionMapping.json`](#creating-actionmappingjson)
      - [Defining Actions](#defining-actions)
      - [Commands](#commands)
      - [Resource Filters](#resource-filters)
      - [Example `ActionMapping.json`](#example-actionmappingjson)
        - [Explanation:](#explanation)
        - [Defining Custom Actions:](#defining-custom-actions)
        - [Tips for Customizing Action Mappings](#tips-for-customizing-action-mappings)
    - [Examples](#examples)
      - [Example 1: Use Custom Action Mapping File](#example-1-use-custom-action-mapping-file)
      - [Example 2: Use Default Action Mapping File](#example-2-use-default-action-mapping-file)
    - [Notes](#notes)
  - [License](#license)

## Prerequisites

- **PowerShell 7 or higher**
- **Network access to Redfish/Swordfish-compliant targets**
- **ActionMapping.json** file containing action mappings

## Usage

### Parameters

The script accepts the following parameters:

- **TargetURI (Required):** The URI (IP address or hostname) of the Redfish/Swordfish target to connect to.
- **Credential (Optional):** A `PSCredential` object for authentication. If not provided, the script will prompt for credentials using `Get-Credential`.
- **ActionMappingFile (Optional):** The path to the JSON file containing action mappings. If not specified, a file named `ActionMapping.json` in the script's directory is used.

### Action Mapping File

#### Creating `ActionMapping.json`

The `ActionMapping.json` file defines the available actions and their execution details. Each action includes commands for **GET**, **SET**, and **DELETE** operations, along with resource filters and templates for request bodies.

#### Defining Actions

Each action in the `ActionMapping.json` is defined by a unique key (action name) and contains the following structure:

- **GetCommand:** Defines the GET operation details.
  - **Method:** HTTP method to use for the GET operation (usually `"GET"`).
  - **PropertyNames:** An array of property paths to display when performing the GET operation.

- **SetCommand:** Defines the SET operation details.
  - **Method:** HTTP method to use for the SET operation (e.g., `"PATCH"`, `"POST"`).
  - **BodyTemplate:** A template for the request body, using placeholders for user input.

- **DeleteCommand:** Defines the DELETE operation details.
  - **Method:** HTTP method to use for the DELETE operation (usually `"DELETE"`).

- **GetResourceFilter:** A filter pattern to identify resources for the GET operation.
- **SetResourceFilter:** A filter pattern to identify resources for the SET operation.
- **DeleteResourceFilter:** A filter pattern to identify resources for the DELETE operation.

#### Commands

- **PropertyNames:** Specifies which properties to retrieve and display during the GET operation. Each property is defined as an array representing the path to the property in the JSON response.

- **BodyTemplate:** Defines the structure of the request body for SET operations. Placeholders enclosed in `{{ }}` are used to prompt the user for input during the interactive session.

#### Resource Filters

Resource filters are patterns used to match specific URIs in the Redfish API. They support wildcard characters (`*`) to match multiple resources.

#### Example `ActionMapping.json`

Here is an example of an `ActionMapping.json` file:

```json
{
    "BootSourceOverride-iLO4": {
        "GetCommand": {
            "Method": "GET",
            "PropertyNames": [
                ["Boot", "BootSourceOverrideEnabled"],
                ["Boot", "BootSourceOverrideTarget"],
                ["Boot", "BootSourceOverrideSupported"]
            ]
        },
        "SetCommand": {
            "Method": "PATCH",
            "BodyTemplate": {
                "Boot": {
                    "BootSourceOverrideTarget": "{{BootSourceOverrideTarget}}"
                }
            }
        },
        "DeleteCommand": {
            "Method": ""
        },
        "GetResourceFilter": "/redfish/v1/Systems/*/",
        "SetResourceFilter": "/redfish/v1/Systems/*/",
        "DeleteResourceFilter": ""
    },
    "LocalUserAccountManagement-iLO5": {
        "GetCommand": {
            "Method": "GET",
            "PropertyNames": [
                ["Id"],
                ["UserName"],
                ["Oem", "Hpe", "LoginName"],
                ["RoleId"],
                ["Oem", "Hpe", "Privileges"]
            ]
        },
        "SetCommand": {
            "Method": "POST",
            "BodyTemplate": {
                "UserName": "{{UserName}}",
                "Password": "{{Password}}",
                "RoleId": "{{RoleId}}"
            }
        },
        "DeleteCommand": {
            "Method": "DELETE"
        },
        "GetResourceFilter": "/redfish/v1/AccountService/Accounts/*/",
        "SetResourceFilter": "/redfish/v1/AccountService/Accounts/",
        "DeleteResourceFilter": "/redfish/v1/AccountService/Accounts/*/"
    }
}
```
##### Explanation:

- **BootSourceOverride-iLO4:**

  - **GetCommand:** Retrieves boot source override settings.
    - **Method:** `"GET"`
    - **PropertyNames:** Specifies properties like `BootSourceOverrideEnabled`, `BootSourceOverrideTarget`, and `BootSourceOverrideSupported`.
  - **SetCommand:** Allows setting the `BootSourceOverrideTarget`.
    - **Method:** `"PATCH"`
    - **BodyTemplate:** Uses a placeholder `{{BootSourceOverrideTarget}}` to prompt the user for input.
  - **DeleteCommand:** Not defined (empty method).
  - **Resource Filters:** Apply to resources under `/redfish/v1/Systems/*/`.


- **LocalUserAccountManagement-iLO5:**

  - **GetCommand:** Retrieves user account information.
    - **Method:** `"GET"`
    - **PropertyNames:** Includes `Id`, `UserName`, `LoginName`, `RoleId`, and `Privileges`.
  - **SetCommand:** Allows creating new user accounts.
    - **Method:** `"POST"`
    - **BodyTemplate:** Prompts for `UserName`, `Password`, and `RoleId`.
  - **DeleteCommand:** Supports deleting user accounts.
    - **Method:** `"DELETE"`
  - **Resource Filters:**
    - GetResourceFilter: `/redfish/v1/AccountService/Accounts/*/`
    - SetResourceFilter: `/redfish/v1/AccountService/Accounts/`
    - DeleteResourceFilter: `/redfish/v1/AccountService/Accounts/*/`

##### Defining Custom Actions:

To define your own actions:

1. Create a new action name as a key in the JSON object.
2. Specify the commands (GetCommand, SetCommand, DeleteCommand) as needed.
3. Define the resource filters to target the correct URIs in the Redfish API.
4. Use placeholders in the BodyTemplate to prompt for user input during SET operations.
5. List the property paths in PropertyNames to display during GET operations.

##### Tips for Customizing Action Mappings
Identify Resource Paths: Determine the correct URIs for the resources you want to manage by consulting the Redfish API documentation for your hardware.

Define Accurate Property Paths: Ensure that the property paths in PropertyNames accurately reflect the structure of the JSON responses from your target devices.

Use Placeholders Wisely: In BodyTemplate, use placeholders `({{ }})` for values that should be provided by the user during the interactive session.

Test Your Actions: After defining new actions, test them thoroughly to ensure they behave as expected.

### Examples

#### Example 1: Use Custom Action Mapping File

```powershell
$target = "10.0.0.16" $cred = Get-Credential

.\Invoke-RemoteManagementActions.ps1 -TargetURI $target -Credential $cred -ActionMappingFile "C:\Config\ActionMapping.json"
```

This example connects to the Redfish target at `10.0.0.16`, prompts for credentials, loads the action mappings from `C:\Config\ActionMapping.json`, and starts the interactive CLI.

#### Example 2: Use Default Action Mapping File

```powershell
$target = "10.0.0.16" $cred = Get-Credential

.\Invoke-RemoteManagementActions.ps1 -TargetURI $target -Credential $cred
```

This example connects to the Redfish target at `10.0.0.16`, prompts for credentials, uses the default `ActionMapping.json` file in the script's directory, and starts the interactive CLI.

### Notes

- **Interactive CLI:** After running the script, it provides an interactive menu to select operation types (**GET**, **SET**, **DELETE**) and available actions based on the action mappings.
- **Credentials:** The script uses the provided credentials to authenticate with the target. Ensure the account has the necessary permissions.
- **Action Mappings:** Customize the `ActionMapping.json` file to define specific actions and resource filters suitable for your environment.
- **Error Handling:** All errors are logged and can be reviewed for troubleshooting. Add the `-Verbose` parameter to see detailed progress information and the `-Debug` parameter for additional debug output.
- **Compatibility:** The target systems must support the Redfish/Swordfish API.
- **PowerShell Version:** This script requires PowerShell 7 or higher.

## License

This script is provided under the MIT License.

Disclaimer: This script is provided as-is without any warranties. Use it at your own risk. Ensure you have permission to access and manage data on the target systems.
