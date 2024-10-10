# Start-RedfishHostInventoryCollection.ps1

This PowerShell script imports Redfish JSON data from a specified root directory, processes the data based on provided property mappings, and exports the processed data to CSV files. It facilitates data extraction and transformation from Redfish API responses saved as JSON files.

## Table of Contents

- [Start-RedfishHostInventoryCollection.ps1](#start-redfishhostinventorycollectionps1)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Usage](#usage)
    - [Parameters](#parameters)
    - [Examples](#examples)
  - [Property Mapping Configuration](#property-mapping-configuration)
    - [Creating `PropertyMapping.json`](#creating-propertymappingjson)
    - [Defining Property Mappings](#defining-property-mappings)
      - [Properties](#properties)
      - [FallbackProperties](#fallbackproperties)
    - [Example `PropertyMapping.json`](#example-propertymappingjson)
    - [Tips for Customizing Property Mappings](#tips-for-customizing-property-mappings)
  - [Notes](#notes)
  - [License](#license)

## Prerequisites

- **PowerShell 7 or higher**
- **Redfish JSON Data:** Output from the `Get-RecursiveRedfishLookup.ps1` script or similar, organized under `redfish/v1/` in the directory structure.

## Usage

### Parameters

The script accepts the following parameters:

- **RootDirectory (Required):** The root directory containing the Redfish JSON files to import.
- **OutputDirectory (Optional):** The directory where the processed CSV files will be saved. Default is `.\Output` in the script's directory.
- **PropertyMappingFile (Optional):** The path to the JSON file containing property mappings for processing the imported data. Default is `.\PropertyMapping.json` in the script's directory.

### Examples

**Example 1: Process Redfish Data with Custom Property Mappings**

```powershell
    $rootDir = "C:\RedfishData"
    $outputDir = "C:\ProcessedData"
    $propertyMapping = "C:\Config\PropertyMapping.json"

    .\Start-RedfishHostInventoryCollection.ps1 -RootDirectory $rootDir -OutputDirectory $outputDir -PropertyMappingFile $propertyMapping
```

This example imports Redfish JSON data from `C:\RedfishData`, processes it using the property mappings defined in `C:\Config\PropertyMapping.json`, and exports the processed data to CSV files in `C:\ProcessedData`.

**Example 2: Process Redfish Data with Default Settings**

```powershell
    $rootDir = "C:\RedfishData"

    .\Start-RedfishHostInventoryCollection.ps1 -RootDirectory $rootDir
```

This example imports Redfish JSON data from `C:\RedfishData`, processes it using the default property mappings, and exports the processed data to CSV files in the default `Output` directory.

## Property Mapping Configuration

### Creating `PropertyMapping.json`

The `PropertyMapping.json` file defines how the script extracts and processes properties from the imported Redfish JSON data. Each mapping corresponds to a specific resource type and specifies which properties to extract.

### Defining Property Mappings

Each entry in the `PropertyMapping.json` file represents a mapping for a specific resource type and includes:

- **Properties:** Defines which properties to extract and how to navigate to them within the JSON data.
- **FallbackProperties:** Alternative property paths to use if the primary property is not found.
- **ResourceFilter:** A filter pattern to identify relevant resources in the JSON data.
- **odataType:** (Optional) Specifies the `@odata.type` of the resources to match.

#### Properties

The `Properties` object maps the desired property names to their paths within the JSON data. Each path is an array of strings representing the hierarchy to navigate to the value.

Example:

```json
    "Properties": {
        "BootOrder": ["Boot", "BootOrder"],
        "TotalSystemMemoryGiB": ["MemorySummary", "TotalSystemMemoryGiB"]
    }
```

This mapping instructs the script to extract:

- `BootOrder` from `Entry.Boot.BootOrder`
- `TotalSystemMemoryGiB` from `Entry.MemorySummary.TotalSystemMemoryGiB`

#### FallbackProperties

The `FallbackProperties` object provides alternative paths if the primary properties are not found.

Example:

```json
    "FallbackProperties": {
        "BootOrder": ["Boot", "BootSourceOverrideSupported"]
    }
```

If `BootOrder` is not found using the primary path, the script will attempt to extract it from `Entry.Boot.BootSourceOverrideSupported`.

### Example `PropertyMapping.json`

Here is an example of a `PropertyMapping.json` file:

```json
    {
        "SystemLog": {
            "Properties": {
                "BootOrder": ["Boot", "BootOrder"],
                "TotalSystemMemoryGiB": ["MemorySummary", "TotalSystemMemoryGiB"]
            },
            "FallbackProperties": {
                "BootOrder": ["Boot", "BootSourceOverrideSupported"]
            },
            "ResourceFilter": "/redfish/v1/Systems/*",
            "odataType": "#ComputerSystem.1.0.1.ComputerSystem"
        },
        "ChassisLog": {
            "Properties": {
                "SerialNumber": ["SerialNumber"],
                "Manufacturer": ["Manufacturer"],
                "Model": ["Model"]
            },
            "FallbackProperties": {
                "SerialNumber": ["SerialNumber"]
            },
            "ResourceFilter": "/redfish/v1/Chassis/*",
            "odataType": "#Chassis.1.0.0.Chassis"
        },
        "AccountLog": {
            "Properties": {
                "UserName": ["UserName"],
                "LoginName": ["Oem", "Hp", "LoginName"],
                "Privileges": ["Oem", "Hp", "Privileges"]
            },
            "FallbackProperties": {},
            "ResourceFilter": "/redfish/v1/AccountService/Accounts/*/",
            "odataType": ""
        }
    }
```

**Explanation:**

- **SystemLog:**
  - **Properties:** Extracts `BootOrder` and `TotalSystemMemoryGiB`.
  - **FallbackProperties:** Uses an alternative path for `BootOrder` if the primary is not found.
  - **ResourceFilter:** Targets resources under `/redfish/v1/Systems/*`.
  - **odataType:** Matches resources of type `#ComputerSystem.1.0.1.ComputerSystem`.

- **ChassisLog:**
  - **Properties:** Extracts `SerialNumber`, `Manufacturer`, and `Model`.
  - **FallbackProperties:** Provides a fallback for `SerialNumber`.
  - **ResourceFilter:** Targets resources under `/redfish/v1/Chassis/*`.
  - **odataType:** Matches resources of type `#Chassis.1.0.0.Chassis`.

- **AccountLog:**
  - **Properties:** Extracts user account information.
  - **ResourceFilter:** Targets resources under `/redfish/v1/AccountService/Accounts/*/`.
  - **odataType:** No specific type filtering.

### Tips for Customizing Property Mappings

- **Identify Resource Paths:** Use the structure of your Redfish JSON data to determine accurate property paths.
- **Use Wildcards in Filters:** The `ResourceFilter` supports wildcards (`*`) to match multiple resources.
- **Fallbacks for Reliability:** Provide fallback properties to ensure data extraction even if some properties are missing.
- **Test Incrementally:** Test your mappings with a small dataset to ensure correctness before processing large amounts of data.
- **Handling `@odata.type`:** Use the `odataType` field to filter resources by their type. Leave it empty (`""`) if not needed.

## Notes

- **Data Organization:** Ensure that the JSON files are organized under `redfish/v1/` in the directory structure for the script to process them correctly.
- **Error Handling:** The script stops on all errors due to `$ErrorActionPreference = 'Stop'`. Adjust as necessary.
- **Verbose Output:** Use the `-Verbose` switch when running the script to get detailed output for troubleshooting.
- **PowerShell Version:** This script requires PowerShell 7 or higher.

## License

This script is provided under the MIT License.

Disclaimer: This script is provided as-is without any warranties. Use it at your own risk. Ensure you have permission to process and export data from the source files.
