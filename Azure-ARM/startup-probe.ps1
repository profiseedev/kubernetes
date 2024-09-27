# Start transcript for logging
$hostname = hostname
$probeLog = "C:\fileshare\startup-probe-$hostname.log"
Start-Transcript -Path $probeLog

$logFilePath = "C:\Profisee\Configuration\LogFiles\SystemLog.log" 
$successString = "User Manager\\ContainerAdministrator Profisee platform configuration finished." 
$checkIntervalSeconds = 5


# Main loop
while ($true) {
    Write-Host "Parsing log file for success and failure strings..."
    if (Test-Path $logFilePath) {
        # Get the entries for success and failure strings
        $successEntries = Get-Content -Path $logFilePath | Select-String -Pattern $successString

        # Get the counts of the entries
        $successCount = $successEntries.Count

        # 1. If success count > 0, break successfully.
        if ($successCount -gt 0) {
            Write-Host "Configuration finished. There may be errors."
            break
        }
    } else {
        Write-Host "Log file not found."
    }

    # Sleep before checking again
    Start-Sleep -Seconds $checkIntervalSeconds
}

Stop-Transcript
