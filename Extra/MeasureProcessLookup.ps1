#Look to see if Measure is running

$Measure = Get-Process MSR* -ErrorAction SilentlyContinue

if (!$Measure){
"Measure is not running on this PC"
}

if ($Measure) {
#If the Measure Process is started
"Measure is currently running on this PC"
$WaitTries = 0
Do{
"Waiting 30 Seconds and Re-evaluating"
$WaitTries = $WaitTries+1
Start-Sleep -Seconds 30
$Measure = Get-Process Measure -ErrorAction SilentlyContinue
if ($WaitTries -ge 10){
"Waited maximum configured time"
"Measure = $Measure"
Break}
#The above sets the max wait value to 5 Mins
}Until (!$Measure)

#Then re-evaluate, and error out if Measure is still running. 
$Measure = Get-Process Measure -ErrorAction SilentlyContinue
if ($Measure) {
"Measure is still running"
"Exiting with Error Code 10"
exit 10 
} # End of If Measure exists #2

if (!$Measure){
"Measure was closed on this PC within the allotted time"
} # If the Measure process doesn't exist anymore, we know it was closed within our allotted time

} # End of If Measure exists #1

