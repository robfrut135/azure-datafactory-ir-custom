# azure-datafactory-ir-custom

Prepare an Integration Runtime node for Azure Data Factory environment.

Main components deployed inside the node

* Integration Runtime agent (Install-IR)
* Java Runtime Environment (Install-JRE)
* Visual C++ Redistributable package (Install-VisuaCPackage)
* SAP HANA ODBC driver (Install-SAP-ODBC-Driver)
* PowerShell modules: Azure PowerShell (Install-Modules)
* Scheduled task for running Integration Runtime backups (Install-IR-Backup)
* Load Integration Runtime agent on startup (Load-IR-Backup)
