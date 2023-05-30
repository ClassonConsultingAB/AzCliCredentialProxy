$history = New-Object System.Collections.ArrayList

function Add-TaskHistory($Title, $Status = '', $Elapsed = $null) {
    $item = New-Object psobject -Property @{
        Title   = $Title
        Status  = $Status
        Elapsed = $Elapsed
    }
    $history.Add($item) | Out-Null
}

function Task($Title, $Command, [switch]$Skip) {
    if ($Skip) {
        Add-TaskHistory -Title $Title -Status Skipped
        return
    }
    Write-Host @"

╬════════════
║ $Title
╬═══

"@ -ForegroundColor DarkGray
    $stopWatch = New-Object System.Diagnostics.Stopwatch
    $stopWatch.Start()
    Invoke-Command -ScriptBlock $Command
    $stopWatch.Stop()
    Add-TaskHistory -Title $Title -Status Executed -Elapsed $stopWatch.Elapsed
}

function Write-TaskSummary {
    $total = [timespan]::Zero
    foreach ($item in $history) {
        if ($null -ne $item.Elapsed) {
            $total = $total.Add($item.Elapsed)
        }
    }
    Add-TaskHistory -Title Total -Elapsed $total
    $history | Format-Table
}

function Exec($Command, [switch]$ReturnOutput) {
    if ($Command.GetType().Name -eq 'String') {
        $Command = [scriptblock]::Create($Command)
    }
    Write-Host "[$Command]" -ForegroundColor DarkGray
    if ($ReturnOutput) {
        $result = Invoke-Command -ScriptBlock $Command
    }
    else {
        Invoke-Command -ScriptBlock $Command
    }
    if ($LASTEXITCODE -ne 0) {
        Fail 'Something bad happened'
    }
    if ($ReturnOutput) {
        return $result
    }
}

function Fail($Message) {
    Write-Error $Message
    exit -1
}

function Get-SettingsJson($Settings) {
    $deploySettings = @{}
    foreach ($p in $Settings.GetEnumerator()) {
        $deploySettings.Add($p.Name, @{ value = $p.Value })
    }
    $json = New-Object psobject -Property $deploySettings | ConvertTo-Json -Compress
    if ($IsWindows) {
        return $json -replace '"', '\"'
    }
    return $json
}
