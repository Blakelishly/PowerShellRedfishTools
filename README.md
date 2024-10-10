# PowerShell Redfish Tools

This repository contains a collection of PowerShell scripts designed to facilitate server management using the Redfish API protocol. These scripts enable administrators to automate data center inventory collection, centralize system log retrieval, and execute administrative actions on data center hardware. Each script is located in its own subdirectory under the root, named after the script file.

These tools were featured in the presentation **"Mastering Server Management with PowerShell and Redfish Protocol"** at the [RTPSUG PowerShell Saturday 2024](https://powershellsaturdaync.com/) event.

## Table of Contents

- [PowerShell Redfish Tools](#powershell-redfish-tools)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Scripts](#scripts)
    - [Get-RecursiveRedfishLookup](#get-recursiveredfishlookup)
    - [Start-RedfishHostInventoryCollection](#start-redfishhostinventorycollection)
    - [Get-RedfishTargetLogs](#get-redfishtargetlogs)
    - [Invoke-RemoteManagementActions](#invoke-remotemanagementactions)
  - [Updated Emulator Files](#updated-emulator-files)
  - [License](#license)

## Overview

The scripts in this repository leverage the Redfish API to provide powerful automation capabilities for managing data center hardware. They address common challenges such as lack of documentation, inefficient manual processes, and the need for flexible, scalable management solutions across diverse hardware environments.

## Scripts

### Get-RecursiveRedfishLookup

**Description:**

This script connects to one or more Redfish or Swordfish targets, authenticates, and recursively crawls the Redfish API starting from a specified root URL. It collects data from each endpoint and saves the responses in JSON format to an output directory. This tool is useful for data center inventory automation or managing Redfish-compliant hardware.

**Use Case:**

In divestiture projects where infrastructure needs to be migrated from a parent company's domain to a new environment, documentation of the asset inventory is often limited or outdated. This script facilitates the automated collection of infrastructure data across numerous target systems, enabling administrators to quickly gather detailed information. The custom reports generated can account for hardware variations and manufacturer-specific implementations, providing a comprehensive view of the environment.

**Features:**

- Connects to multiple Redfish/Swordfish targets.
- Authenticates sessions securely.
- Recursively crawls the Redfish API endpoints.
- Saves responses in JSON format for further processing.
- Supports URL filtering to limit the scope of data collection.

**Usage Example:**

```powershell
    $targets = @("10.0.0.16")
    $cred = Get-Credential
    
    .\Get-RecursiveRedfishLookup.ps1 -TargetURIs $targets -Credential $cred -OutputDirectory "C:\RedfishData"
```

**Detailed Documentation:**

Refer to the [Get-RecursiveRedfishLookup](Get-RecursiveRedfishLookup/README.md) directory for a more detailed README and usage instructions.

---

### Start-RedfishHostInventoryCollection

**Description:**

This script imports Redfish JSON data from a specified root directory, processes the data based on provided property mappings, and exports the processed data to CSV files. It facilitates data extraction and transformation from Redfish API responses saved as JSON files.

**Use Case:**

After collecting infrastructure data using the `Get-RecursiveRedfishLookup` script, administrators may need to process and analyze the data. This script processes the collected JSON files, extracts relevant information based on customizable property mappings, and exports the data into CSV files for reporting and analysis.

**Features:**

- Imports Redfish JSON data recursively from a directory.
- Processes data according to user-defined property mappings.
- Exports processed data to CSV files for easy consumption.
- Supports customization for different hardware and manufacturers.

**Usage Example:**

```powershell
    $rootDir = "C:\RedfishData"
    $outputDir = "C:\ProcessedData"
    $propertyMapping = "C:\Config\PropertyMapping.json"
    
    .\Start-RedfishHostInventoryCollection.ps1 -RootDirectory $rootDir -OutputDirectory $outputDir -PropertyMappingFile $propertyMapping
```

**Detailed Documentation:**

Refer to the [Start-RedfishHostInventoryCollection](Start-RedfishHostInventoryCollection/README.md) directory for a more detailed README and usage instructions.

---

### Get-RedfishTargetLogs

**Description:**

This script connects to Redfish or Swordfish targets to collect system logs and outputs them in either JSON or custom-formatted log files. It uses customizable property mappings defined in a `PropertyMapping.json` file to tailor the log entry structures according to specific needs.

**Use Case:**

When troubleshooting specific log events across multiple physical servers and data center equipment, manually accessing each server's Baseboard Management Controller (BMC) to extract logs can be time-consuming and inefficient. This script simplifies the process by enabling centralized log collection across multiple targets. It supports various log formats and can be easily customized to handle different log types across diverse hardware and manufacturers.

**Features:**

- Connects to multiple Redfish/Swordfish targets for log retrieval.
- Authentates sessions securely.
- Collects logs from specified endpoints.
- Supports output in JSON or custom-formatted log files.
- Customizable property mappings for different log formats.

**Usage Example:**

```powershell
    $targets = @("example-target1", "example-target2.exampledomain.com")
    $cred = Get-Credential
    
    .\Get-RedfishTargetLogs.ps1 -TargetURIs $targets -Credential $cred
```

**Detailed Documentation:**

Refer to the [Get-RedfishTargetLogs](Get-RedfishTargetLogs/README.md) directory for a more detailed README and usage instructions.

---

### Invoke-RemoteManagementActions

**Description:**

This script provides an interactive command-line interface (CLI) for performing **GET**, **SET**, and **DELETE** operations on a Redfish/Swordfish API target based on predefined action mappings specified in a JSON file. It facilitates automation and management tasks on Redfish-compliant hardware systems.

**Use Case:**

Executing actions on different data center hardware using PowerShell can be challenging due to differences in data models, often requiring custom functions for each device type. This script offers a flexible solution that allows administrators to define their own operations in a JSON file, streamlining the process of managing hardware configurations.

It acts as a powerful framework that connects to hardware targets using the Redfish API, authenticates sessions, and executes user-defined actions. The script allows users to perform operations such as retrieving hardware information, modifying user accounts, and deleting obsolete data. The JSON configuration file defines these actions, making it easy to extend the tool's functionality to different systems or devices without modifying the core script.

**Features:**

- Interactive CLI for managing Redfish/Swordfish targets.
- Supports **GET**, **SET**, and **DELETE** operations.
- Uses customizable action mappings defined in a JSON file.
- Facilitates operations like modifying boot order, managing user accounts, etc.
- Scalable and adaptable to different hardware and manufacturers.

**Usage Example:**

```powershell
    $target = "10.0.0.16"
    $cred = Get-Credential
    
    .\Invoke-RemoteManagementActions.ps1 -TargetURI $target -Credential $cred -ActionMappingFile "C:\Config\ActionMapping.json"
```

**Detailed Documentation:**

Refer to the [Invoke-RemoteManagementActions](Invoke-RemoteManagementActions/README.md) directory for a more detailed README and usage instructions.

---

## Updated Emulator Files

Also included in this repository are updated emulator files for the [csm-redfish-interface-emulator](https://github.com/Cray-HPE/csm-redfish-interface-emulator). These files patch several issues in the original emulator, and offer recommended Dockerfile and Docker Compose configurations for running the emulator in a containerized environment.

Refer to the [Mastering Server Management with PowerShell and Redfish Protocol](Mastering%20Server%20Management%20with%20PowerShell%20and%20Redfish%20Protocol.pdf) presentation for more information on how this emulator can be used in conjunction with the PowerShell scripts.

## License

This collection of scripts is provided under the MIT License.

**Disclaimer:** These scripts are provided as-is without any warranties. Use them at your own risk. Ensure you have permission to access and manage data on the target systems.
