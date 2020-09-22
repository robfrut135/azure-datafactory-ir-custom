param(
	[string]
 	$gatewayKey,
    [string]
    $jreURI,
    [string]
    $jreName
)

# init log setting
$logLoc = "$env:SystemDrive\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\"
if (! (Test-Path($logLoc)))
{
    New-Item -path $logLoc -type directory -Force
}
$logPath = "$logLoc\tracelog.log"
"Start to excute gatewayInstall.ps1. `n" | Out-File $logPath

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

function Download-File([string] $url, [string] $path)
{
    try
    {
        $ErrorActionPreference = "Stop";
        $client = New-Object System.Net.WebClient
        $client.DownloadFile($url, $path)
        Trace-Log "Download file successfully. Location: $path"
    }
    catch
    {
        Trace-Log "Fail to download file"
        Trace-Log $_.Exception.ToString()
        throw
    }
}

function Install-Gateway([string] $gwPath)
{
	if ([string]::IsNullOrEmpty($gwPath))
    {
		Throw-Error "Integration Runtime Agent path is not specified"
    }
	if (!(Test-Path -Path $gwPath))
	{
		Throw-Error "Invalid Integration Runtime Agent path: $gwPath"
	}

	Trace-Log "Start Integration Runtime Agent installation"
	Run-Process "msiexec.exe" "/i gateway.msi INSTALLTYPE=AzureTemplate /quiet /norestart"
	Start-Sleep -Seconds 30
	Trace-Log "Installation of Integration Runtime Agent is successful"
}

function Register-Gateway([string] $instanceKey)
{
    Trace-Log "Register Integration Runtime Agent"
	$currentDate =  Get-Date -Format "yyMMddHHmmss"
	$filePath = "C:\Program Files\Microsoft Integration Runtime\4.0\Shared\dmgcmd.exe"
    Run-Process $filePath "-Restart"
    Run-Process $filePath "-EnableRemoteAccess 8060"
	Run-Process $filePath "-RegisterNewNode $instanceKey hip$currentDate"
    Trace-Log "Integration Runtime Agent registration is successful!"
}

function Install-JRE([string] $jrePath, [string] $jreName)
{
	if ([string]::IsNullOrEmpty($jrePath) -Or [string]::IsNullOrEmpty($jreName))
    {
		Throw-Error "JRE path or name not specified"
    }

	if (!(Test-Path -Path $jrePath))
	{
		Throw-Error "Invalid JRE path: $jrePath"
	}

	Trace-Log "Start JRE installation"

    Expand-Archive -Force -Path $jrePath -DestinationPath .

    [System.Environment]::SetEnvironmentVariable('PATH', "$env:Path;$PWD\$jreName\bin", [System.EnvironmentVariableTarget]::Machine)
    [System.Environment]::SetEnvironmentVariable('JAVA_HOME', "$PWD\$jreName\bin", [System.EnvironmentVariableTarget]::Machine)

    $env:Path += "$PWD\$jreName\bin"

    echo $env:JAVA_HOME
    echo $env:Path

    java -version

	Start-Sleep -Seconds 10

	Trace-Log "Installation of JRE is successful"
}

Trace-Log "Log file: $logLoc"

Trace-Log "Data Factory Integration Runtime Agent"
$irUri = "https://go.microsoft.com/fwlink/?linkid=839822"
Trace-Log "Gateway download fw link: $irUri"
$gwPath= "$PWD\gateway.msi"
Trace-Log "Gateway download location: $gwPath"
Download-File $irUri $gwPath
Install-Gateway $gwPath
Register-Gateway $gatewayKey

Trace-Log "Java Runtime Environment"
Trace-Log "JRE from: $jreURI"
$jrePath= "$PWD\jre.zip"
Trace-Log "JRE location: $jrePath"
Download-File $jreURI $jrePath
Install-JRE $jrePath $jreName

Trace-Log "Visual C++ 2010 Redistributable"
$vcUri = "https://download.microsoft.com/download/3/2/2/3224B87F-CFA0-4E70-BDA3-3DE650EFEBA5/vcredist_x64.exe"
Trace-Log "Package from: $vcUri"
$vcPath= "$PWD\vcredist_x64.exe"
Trace-Log "Package location: $vcPath"
.\vcredist_x64.exe -q

Trace-Log "SAP HANA ODBC Driver"
Trace-Log "TODO"
