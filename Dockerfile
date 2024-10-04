# Use the official PowerShell image as the base
FROM mcr.microsoft.com/powershell:latest

# Metadata
LABEL maintainer="Blake Cherry <bcherry@westmonroe.com>"
LABEL description="Container for running PowerShell Core."

# If additional dependencies are needed, install them here
# Example:
# RUN apt-get update && apt-get install -y git && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set PowerShell as the default command
CMD ["pwsh"]