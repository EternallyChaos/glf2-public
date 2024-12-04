param(
  [string]$TargetFolder = "AppData\LocalLow\SunBorn\EXILIUM",
  [string]$FileName = "Player.log",
  [string]$ApiUrl = "https://gf2-gacha-record-us.sunborngame.com/list",
  [int]$GameChannelId = 5,
  [int]$TypeId = 3,
  [int]$DelayBetweenCalls = 500, # Delay in milliseconds
  [string]$OutputFile = "$([Environment]::GetFolderPath('Desktop'))\gacha_history_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
)

# Ensure script can run with proper execution policy
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Function to Extract Email from Log File
function Find-Credentials {
  $userProfilePath = [System.Environment]::GetFolderPath('UserProfile')
  $filePath = Join-Path $userProfilePath $TargetFolder | Join-Path -ChildPath $FileName
  
  if (Test-Path $filePath) {
    Write-Host "Credentials file found: $filePath"
    $fileContent = Get-Content -Path $filePath -Raw
      
    $email = $null
    $accessToken = $null

    # Primary method: Direct regex
    $emailRegex = '"account":"([^"]+)"'
    $tokenRegex = '"access_token":"([^"]+)"'

    $emailMatch = [regex]::Match($fileContent, $emailRegex)
    $tokenMatch = [regex]::Match($fileContent, $tokenRegex)

    if ($emailMatch.Success) {
      $email = $emailMatch.Groups[1].Value
      Write-Host "Email found: $email"
    }

    if ($tokenMatch.Success) {
      $accessToken = $tokenMatch.Groups[1].Value
      Write-Host "Access token found"
    }

    # Validate credentials
    if ($email -and $accessToken) {
      return @{
        Email       = $email
        AccessToken = $accessToken
      }
    }
    else {
      throw "Could not find both email and access token in the file."
    }
  }
  else {
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

# Function to Retrieve Gacha History Data
function Get-GachaHistoryData {
  param (
    [string]$NextId = $null,
    [string]$Email,
    [string]$AccessToken,
    [int]$BodyTypeId
  )
  # URL Encode the email using .NET's Uri.EscapeDataString
  $encodedEmail = [uri]::EscapeDataString($Email)
   
  # Construct the URL with the original TypeId
  $fullUrl = "$ApiUrl`?game_channel_id=$GameChannelId&type_id=$TypeId&u=$encodedEmail"
   
  Write-Host "Constructed URL: $fullUrl"
  $headers = @{
    Authorization  = $AccessToken
    "Content-Type" = "application/json"
  }
  $body = @{
    next    = $NextId
    type_id = $BodyTypeId
  } | ConvertTo-Json -Compress

  try {
    $response = Invoke-RestMethod -Uri $fullUrl -Method POST -Headers $headers -Body $body -ContentType "application/json"
       
    if ($response.code -ne 0) {
      throw "API Error: $($response.code)"
    }
    return $response
  }
  catch {
    Write-Error "Failed to fetch gacha history: $_"
    Write-Error "Details: $($_.Exception.Message)"
    Write-Error "URL Used: $fullUrl"
    throw
  }
}

# Main Execution Function
function Get-GachaHistory {
  try {
    # Find credentials
    $credentials = Find-Credentials
    
    # Define procurement types
    $procurementTypes = @{
      StandardProcurement = 1
      TargetedProcurement = 3
      MilitaryUpgrade     = 4
    }
    
    # Object to store all procurement histories
    $allProcurementHistories = @{}

    # Retrieve history for each procurement type
    foreach ($typeName in $procurementTypes.Keys) {
      $bodyTypeId = $procurementTypes[$typeName]
      $allPulls = @()
      $nextId = $null
      $pageCount = 0

      do {
        # Add delay to prevent rate limiting
        if ($pageCount -gt 0) {
          Write-Host "Waiting $DelayBetweenCalls ms to prevent rate limiting..."
          Start-Sleep -Milliseconds $DelayBetweenCalls
        }

        $data = Get-GachaHistoryData -NextId $nextId -Email $credentials.Email -AccessToken $credentials.AccessToken -BodyTypeId $bodyTypeId
        $allPulls += $data.data.list
        $nextId = $data.data.next
        $pageCount++

        Write-Host "Retrieved page $pageCount for $typeName"
      } while ($nextId)


      $filteredPulls = $allPulls | 
      ForEach-Object {
        $_ | Add-Member -MemberType NoteProperty -Name formattedTime -Value (Format-Date -timestamp $_.time) -Force
        $_
      }
      
      # Store filtered pulls for this procurement type
      $allProcurementHistories[$typeName] = $filteredPulls
    }

    # Save to JSON on desktop
    $allProcurementHistories | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputFile -Encoding UTF8
       
    Write-Host "Gacha history saved to $OutputFile"
    Write-Host "Total pulls retrieved:"
    foreach ($typeName in $allProcurementHistories.Keys) {
      Write-Host "$typeName : $($allProcurementHistories[$typeName].Count) pulls"
    }
  }
  catch {
    Write-Error "Error: $_"
    Write-Error "Detailed Error: $($_.Exception.Message)"
  }
}

# Execute the main function
Get-GachaHistory