# Gacha History Retrieval Script with Fixed Credential Location
param(
    [string]$TargetFolder = "Testing",
    [string]$FileName = "output.log",
    [string]$ApiUrl = "https://gf2-gacha-record-us.sunborngame.com/list",
    [int]$GameChannelId = 5,
    [int]$TypeId = 3,
    [string]$OutputFile = "gacha_history_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
)

# Ensure script can run with proper execution policy
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Function to Find Credentials in a Specific Location
function Find-Credentials {
    # Get the AppData/Roaming path for the current user
    $appDataPath = [System.Environment]::GetFolderPath('ApplicationData')
    
    # Construct the full path to the target file
    $filePath = Join-Path $appDataPath $TargetFolder | Join-Path -ChildPath $FileName

    # Check if the file exists
    if (Test-Path $filePath) {
        Write-Host "Credentials file found: $filePath"
        
        # Read the file content
        $fileContent = Get-Content -Path $filePath -Raw
        
        # Regex pattern to find email and access_token
        $regex = '"email":"([^"]+)".*"access_token":"([^"]+)"'
        
        # Match the pattern
        $match = [regex]::Match($fileContent, $regex)
        if ($match.Success) {
            return @{
                Email = $match.Groups[1].Value
                AccessToken = $match.Groups[2].Value
            }
        } else {
            throw "No matching credentials found in the file."
        }
    } else {
        throw "Credentials file not found at $filePath"
    }
}

# Date Formatting Function
function Format-Date {
    param ([long]$timestamp)
    $origin = Get-Date -Date "1/1/1970"
    $date = $origin.AddSeconds($timestamp)
    return $date.ToString("dd-MM-yyyy HH:mm:ss")
}

# Renamed function to use approved verb 'Get'
function Get-GachaHistoryData {
    param (
        [string]$NextId = $null,
        [string]$Email,
        [string]$AccessToken
    )

    $url = "$ApiUrl?game_channel_id=$GameChannelId&type_id=$TypeId&u=$($Email -replace "@", "%40")"
    
    $headers = @{
        Authorization = $AccessToken
        "Content-Type" = "application/json"
    }

    $body = @{
        next = $NextId
        type_id = 1
    } | ConvertTo-Json -Compress

    try {
        $response = Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $body -ContentType "application/json"
        
        if ($response.code -ne 0) {
            throw "API Error: $($response.code)"
        }

        return $response
    }
    catch {
        Write-Error "Failed to fetch gacha history: $_"
        throw
    }
}

# Main Execution Function
function Get-GachaHistory {
    try {
        # Find credentials
        $credentials = Find-Credentials

        $allPulls = @()
        $nextId = $null

        do {
            $data = Get-GachaHistoryData -NextId $nextId -Email $credentials.Email -AccessToken $credentials.AccessToken
            $allPulls += $data.data.list
            $nextId = $data.data.next
        } while ($nextId)

        # Filter pulls from the last 6 months
        $sixMonthsAgo = [Math]::Floor((Get-Date).AddMonths(-6).ToUniversalTime().Subtract((Get-Date -Date "1/1/1970")).TotalSeconds)
        
        $filteredPulls = $allPulls | Where-Object { $_.time -gt $sixMonthsAgo } | 
            Sort-Object -Property time -Descending | 
            ForEach-Object {
                $_ | Add-Member -MemberType NoteProperty -Name formattedTime -Value (Format-Date -timestamp $_.time) -Force
                $_
            }

        # Save to JSON
        $filteredPulls | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputFile -Encoding UTF8
        
        Write-Host "Gacha history saved to $OutputFile"
        Write-Host "Total pulls retrieved: $($filteredPulls.Count)"
    }
    catch {
        Write-Error "Error: $_"
    }
}

# Execute the main function
Get-GachaHistory