# Get-RedfishTargetLogs.ps1

This PowerShell script connects to Redfish or Swordfish targets to collect system logs and outputs them in either JSON or custom-formatted log files. It uses customizable property mappings defined in a `PropertyMapping.json` file to tailor the log entry structures according to your needs.

This script queries for logs from the `/redfish/v1/Systems/$SystemID/LogServices/` endpoint of the Redfish/Swordfish API. It retrieves log entries from the `Entries` collection and processes them based on the property mappings defined in the `PropertyMapping.json` file.

## Table of Contents

- [Get-RedfishTargetLogs.ps1](#get-redfishtargetlogsps1)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Usage](#usage)
    - [Parameters](#parameters)
    - [Examples](#examples)
  - [Property Mapping Configuration](#property-mapping-configuration)
    - [Creating `PropertyMapping.json`](#creating-propertymappingjson)
    - [Defining Custom Log Formats](#defining-custom-log-formats)
      - [Properties](#properties)
      - [LogFormat](#logformat)
    - [Default Mappings](#default-mappings)
    - [Tips for Customizing Property Mappings](#tips-for-customizing-property-mappings)
      - [Notes](#notes)
  - [License](#license)

## Prerequisites

- **PowerShell 7**
- **Network access to Redfish/Swordfish-compliant targets**

## Usage

### Parameters

The script accepts the following parameters:

- **TargetURIs (Required):** An array of target URIs to connect to.
- **Credential (Optional):** A `PSCredential` object for authentication. If not provided, you will be prompted.
- **OutputDirectory (Optional):** The directory where logs will be saved. Default is `.\Logs`.
- **PropertyMappingFile (Optional):** The path to your property mapping JSON file. Default is `.\PropertyMapping.json`.
- **JSONOutput (Optional):** A switch to control the output format. Set to `$true` to output logs in JSON format (default), or `$false` for custom-formatted log files.

### Examples

**Example 1: Collect Logs in JSON Format**

```powershell
$targets = @("example-target1", "example-target2.exampledomain.com")
$cred = Get-Credential

.\Get-RedfishTargetLogs.ps1 -TargetURIs $targets -Credential $cred
```

**Example 2: Collect Logs in Custom Log File Format**

```powershell
$targets = @("10.0.0.100, 10.0.0.110")
$cred = Get-Credential

.\Get-RedfishTargetLogs.ps1 -TargetURIs $targets -Credential $cred -JSONOutput $false
```

**Example 3: Specify Custom Output Directory and Property Mapping File**

```powershell
$targets = @("10.0.100.0:5000")
$cred = Get-Credential

.\Get-RedfishTargetLogs.ps1 -TargetURIs $targets -Credential $cred -OutputDirectory "C:\Logs" -PropertyMappingFile "C:\Config\MyPropertyMapping.json"
```

## Property Mapping Configuration
### Creating `PropertyMapping.json`

The `PropertyMapping.json` file defines how the script maps properties from the log entries retrieved from the Redfish/Swordfish targets to your desired output format.

Here is an example of a `PropertyMapping.json` file:

```json
{
    "#LogEntry.1.0.0.LogEntry": {
        "Properties": {
            "Message": ["Message"],
            "Severity": ["Severity"],
            "Created": ["Created"],
            "RecordId": ["RecordId"],
            "SelfLink": ["links", "self", "href"],
            "Class": ["Oem", "Hp", "Class"]
        },
        "LogFormat": "[{Created}] ({Severity}) - [{RecordId}] {Message} [{Class}]"
    },
    "#LogEntry.v1_11_0.LogEntry": {
        "Properties": {
            "Message": ["Message"],
            "Severity": ["Severity"],
            "Created": ["Created"],
            "RecordId": ["RecordId"],
            "SelfLink": ["Links", "self", "@odata.id"],
            "EventNumber": ["Oem", "Hpe", "EventNumber"],
            "ClassDescription": ["Oem", "Hpe", "ClassDescription"]
        },
        "LogFormat": "[{Created}] ({Severity}) - [{RecordId}] {Message} [{ClassDescription}]"
    }
}
```

Here is an example of a corresponding log entry from a Redfish/Swordfish target:

```json
  {
    "@odata.context": "/redfish/v1/$metadata#Systems/Members/1/LogServices/IML/Entries/Members/$entity",
    "@odata.id": "/redfish/v1/Systems/1/LogServices/IML/Entries/16/",
    "@odata.type": "#LogEntry.1.0.0.LogEntry",
    "Created": "2019-12-06T12:04:00Z",
    "EntryType": "Oem",
    "Id": "16",
    "Message": "Network Adapter Link Down (Slot 0, Port 1)",
    "Name": "Integrated Management Log",
    "Number": 1,
    "Oem": {
      "Hp": {
        "@odata.type": "#HpLogEntry.1.0.0.HpLogEntry",
        "Class": 17,
        "Code": 2,
        "EventNumber": 108,
        "Repaired": false,
        "Type": "HpLogEntry.1.0.0",
        "Updated": "2019-12-06T12:04:00Z"
      }
    },
    "OemRecordFormat": "Hp-IML",
    "RecordId": 108,
    "Severity": "Critical",
    "Type": "LogEntry.1.0.0",
    "links": {
      "self": {
        "href": "/redfish/v1/Systems/1/LogServices/IML/Entries/16/"
      }
    }
  },
```

### Defining Custom Log Formats

Each entry in the `PropertyMapping.json` corresponds to a specific `@odata.type` returned by the Redfish/Swordfish API. The mapping consists of:
- **Properties:** Defines which properties to extract from the log entries and how to navigate to them.
- **LogFormat:** Specifies how to format the log entries using placeholders for the properties.

#### Properties
The `Properties` object maps the desired property names to their paths within the log entry objects. The paths are arrays of strings that represent the hierarchy to navigate to the value.

For example:

```json
"Message": ["Message"]
```

This means that to get the `Message` property, the script will look for `Entry.Message`.

For nested properties:

```json
"Class": ["Oem", "Hp", "Class"]
```

This means that to get the `Class` property, the script will look for `Entry.Oem.Hp.Class`.

#### LogFormat
The `LogFormat` string defines how each log entry should be formatted in the output log file. Use placeholders in curly braces `{}` to include property values.

For example:

```json
"[{Created}] ({Severity}) - [{RecordId}] {Message} [{Class}]"
```

When the script processes a log entry, it will replace the placeholders with the actual property values extracted based on the `Properties` mappings.

### Default Mappings

If a log entry's `@odata.type` does not match any key in your `PropertyMapping.json`, the script uses a default mapping:

```json
{
    "Properties": {
        "Message": ["Message"],
        "Severity": ["Severity"],
        "Created": ["Created"],
        "RecordId": ["RecordId"]
    },
    "LogFormat": "[{Created}] ({Severity}) - [{RecordId}] {Message}"
}
```

This default mapping extracts the `Message`, `Severity`, `Created`, and `RecordId` properties from the log entry and formats them in a simple log entry format.

### Tips for Customizing Property Mappings

- **Identify `@odata.type` Values:** Run the script and check the debug output to see the `@odata.type` values returned by your targets.
- **Define Paths Carefully:** Ensure that the property paths correctly navigate the structure of your log entries.
- **Test Placeholders:** Make sure all placeholders in your `LogFormat` strings have corresponding entries in the `Properties` section.
- **Handle Missing Properties:** The script will replace placeholders with empty strings if the property is missing.

#### Notes
  - **Credentials:** The script uses a single set of provided credentials to authenticate with the targets. Ensure the account exists across all hosts and that the credentials have the necessary permissions.
  - **Authentication:** The script uses session-based authentication and attempts to disconnect sessions gracefully after execution.
  - **Error Handling:** The script stops on all errors due to `$ErrorActionPreference = 'Stop'`. Adjust as necessary.
  - **Debugging:** Use the `-Verbose` and `-Debug` switches when running the script to get detailed output for troubleshooting.

## License
This script is provided under the MIT License.

Disclaimer: This script is provided as-is without any warranties. Use it at your own risk. Ensure you have permission to access and collect logs from the target systems.