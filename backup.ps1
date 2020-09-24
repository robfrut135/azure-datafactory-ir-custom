param(
	[string]
 	$resourceGroup,
	[string]
 	$stogageAccountName,
	[string]
	$datafactoryName
)

######################################## LOG SETTING ##############################################################
$logLoc = "$env:SystemDrive\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\"
if (! (Test-Path($logLoc)))
{
    New-Item -path $logLoc -type directory -Force
}
$logPath = "$logLoc\tracelog_backup.log"

###################################### BASE FUNCTIONS #############################################################
function Now-Value()
{
    return (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

function Throw-Error([string] $msg)
{
	try
	{
		throw $msg
	}
	catch
	{
		$stack = $_.ScriptStackTrace
		Trace-Log "DMDTTP is failed: $msg`nStack:`n$stack"
	}
	throw $msg
}

function Trace-Log([string] $msg)
{
    $now = Now-Value
    try
    {
        "${now} $msg`n" | Out-File $logPath -Append
    }
    catch
    {
        #ignore any exception during trace
    }
}

function Run-Process([string] $process, [string] $arguments)
{
	Write-Verbose "Run-Process: $process $arguments"

	$errorFile = "$env:tmp\tmp$pid.err"
	$outFile = "$env:tmp\tmp$pid.out"
	"" | Out-File $outFile
	"" | Out-File $errorFile

	$errVariable = ""

	if ([string]::IsNullOrEmpty($arguments))
	{
		$proc = Start-Process -FilePath $process -Wait -Passthru -NoNewWindow -RedirectStandardError $errorFile -RedirectStandardOutput $outFile -ErrorVariable errVariable
	}
	else
	{
		$proc = Start-Process -FilePath $process -ArgumentList $arguments -Wait -Passthru -NoNewWindow -RedirectStandardError $errorFile -RedirectStandardOutput $outFile -ErrorVariable errVariable
	}

	$errContent = [string] (Get-Content -Path $errorFile -Delimiter "!!!DoesNotExist!!!")
	$outContent = [string] (Get-Content -Path $outFile -Delimiter "!!!DoesNotExist!!!")

	Remove-Item $errorFile
	Remove-Item $outFile

	if($proc.ExitCode -ne 0 -or $errVariable -ne "")
	{
		Throw-Error "Failed to run process: exitCode=$($proc.ExitCode), errVariable=$errVariable, errContent=$errContent, outContent=$outContent."
	}

	Trace-Log "Run-Process: ExitCode=$($proc.ExitCode), output=$outContent"

	if ([string]::IsNullOrEmpty($outContent))
	{
		return $outContent
	}

	return $outContent.Trim()
}

###################################### MAIN FUNCTIONS #############################################################
function Backup-Generate(){
	try
	{
		Trace-Log "Backup Integration Runtime Agent"
		Trace-Log "Generate backup file"
		$irCmd = "C:\Program Files\Microsoft Integration Runtime\4.0\Shared\dmgcmd.exe"
		Run-Process $irCmd "-GenerateBackupFile $PWD\datafactory_ir_backup datafactory_ir_backup"
		Trace-Log "Generate backup file is successful"
	}
	catch
	{
		Trace-Log "Backup-Restore has FAILED."
		Trace-Log $_.Exception
        Trace-Log $_.ScriptStackTrace
	}
}

function Backup-Restore(){
	try
	{
		Trace-Log "Upload backup file to Storage"
		Add-AzAccount -identity | Out-File $logPath -Append
		Connect-AzAccount -Identity | Out-File $logPath -Append
		$backupStorage = Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $stogageAccountName
		$ctx = $backupStorage.Context
		Set-AzStorageBlobContent -Context $ctx -Container "backup" -Blob "datafactory/ir/$datafactoryName" -File "$PWD\datafactory_ir_backup" -Force | Out-File $logPath -Append
		Trace-Log "Upload backup file is successful"
	}
	catch
	{
		Trace-Log "Backup-Restore has FAILED."
		Trace-Log $_.Exception
        Trace-Log $_.ScriptStackTrace
	}
}

########################################## MAIN ###################################################################
Trace-Log "START backup.ps1"
Trace-Log "Log file: $logLoc"
Backup-Generate
Backup-Restore
Trace-Log "END backup.ps1"
