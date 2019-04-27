# This script executes the Sysinternals Autoruns CLI utility and saves the output to a CSV.
# The resulting CSV entries are written to a Windows Event Log called "Autoruns"

# function to calcluate shannon entropy on Image Path items
function GetShannonEntropy {
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [string]$FilePath
)
    $fileEntropy = 0.0
    $FrequencyTable = @{}
    $ByteArrayLength = 0
            
    if(Test-Path $FilePath) {
        $file = (ls $FilePath)
        Try {
            $fileBytes = [System.IO.File]::ReadAllBytes($file.FullName)
        } Catch {
            Write-Error -Message ("Caught {0}." -f $_)
        }

        foreach($fileByte in $fileBytes) {
            $FrequencyTable[$fileByte]++
            $ByteArrayLength++
        }

        $byteMax = 255
        for($byte = 0; $byte -le $byteMax; $byte++) {
            $byteProb = ([double]$FrequencyTable[[byte]$byte])/$ByteArrayLength
            if ($byteProb -gt 0) {
                $fileEntropy += -$byteProb * [Math]::Log($byteProb, 2.0)
            }
        }
        $fileEntropy   
    } 
}

## Code to create the custom Autoruns Windows event log if it doesn't exist
# The following event IDs are in use:
# 1 - Sysinternals Autoruns results
$logfileExists = Get-Eventlog -list | Where-Object {$_.logdisplayname -eq "Autoruns"}
if (! $logfileExists) {
  New-EventLog -LogName Autoruns -Source AutorunsToWinEventLog
  #extend the autorun logs to ensure logs are not loss due to the 1MB log retention limit when creating a new event log using new-eventlog
  Limit-EventLog -LogName Autoruns -MaximumSize 20MB
}

#find the splunkd process and CD to that dir in case someone installs the UF in a non-standard location
$a = Get-Process -Name Splunkd | Select-Object -First 1 | Select-Object Path  
$b = $a.Path 
$autoruns = $b.Replace("bin\splunkd.exe","etc\apps\psu_autoruns_to_win_eventlog\bin\Autorunsc64.exe")
#for testing
#$autoruns = "C:\autorunsc64.exe"

if (Test-Path "$autoruns") {
    #sleep for a while so we don't bog down the computer when it boots up
    Start-Sleep -Seconds 1000
    # Define the path where the Autoruns CSV will be saved
    $autorunsCsv = "AutorunsOutput.csv"

    ## Autorunsc64.exe flags:
    # -nobanner    Don't output the banner (breaks CSV parsing)
    # /accepteula  Automatically accept the EULA
    # -a *         Record all entries
    # -c           Output as CSV
    # -h           Show file hashes
    # -s           Verify digital signatures
    # -v           Query file hashes againt Virustotal (no uploading)
    # -vt          Accept Virustotal Terms of Service
    #  *           Scan all user profiles

    $proc = Start-Process -FilePath "$autoruns" -ArgumentList '-nobanner', '/accepteula', '-a *', '-c', '-h', '-s', '-v', '-vt', '*'  -RedirectStandardOut $autorunsCsv -WindowStyle hidden -Passthru -Wait
    $proc.WaitForExit()
    $autorunsArray = Import-Csv $autorunsCsv

    Foreach ($item in $autorunsArray) {
      $item | Add-Member NoteProperty ShannonEntropy $null

      if ($item."Image Path") {
        Start-Sleep -Seconds 15
        $item.ShannonEntropy = GetShannonEntropy $item."Image Path"
      }
      $item = $(Write-Output $item  | Out-String -Width 1000)
      Write-EventLog -LogName Autoruns -Source AutorunsToWinEventLog -EntryType Information -EventId 1 -Message $item
    }

    #Clean up .csv file so we don't fill up the file system.
    Remove-Item -Path $autorunsCsv
} else {
    Write-Error "Autorunsc.exe not found in $autoruns."
}