# Enhanced Script to Find One Email and One Access Token in output.log
try {
  # Ensure script can run regardless of execution policy
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

  # Define the folder name and file name to search for
  $targetFolder = "Testing"
  $fileName = "output.log"

  # Get the AppData/Roaming path for the current user
  $appDataPath = [System.Environment]::GetFolderPath('ApplicationData') # Roaming AppData

  # Construct the full path to the target folder
  $searchPath = Join-Path $appDataPath $targetFolder

  # Check if the target folder exists
  if (Test-Path $searchPath) {
    # Search for the file in the folder
    $filePath = Get-ChildItem -Path $searchPath -Filter $fileName -File -ErrorAction SilentlyContinue

    if ($filePath) {
      Write-Host "File found: $($filePath.FullName)"
          
      # Read the content of the file
      $fileContent = Get-Content -Path $filePath.FullName -Raw

      # Regex pattern to find email and access_token on the same line
      $regex = '"email":"([^"]+)".*"access_token":"([^"]+)"'
          
      # Match the pattern
      $match = [regex]::Match($fileContent, $regex)

      if ($match.Success) {
        # Extract email and access token from the matched groups
        $email = $match.Groups[1].Value
        $accessToken = $match.Groups[2].Value
        Write-Host "`nMatch found:"
        Write-Host "Email: $email"
        Write-Host "Access Token: $accessToken"
      }
      else {
        Write-Host "`nNo matching email and access token found."
      }
    }
    else {
      Write-Host "File '$fileName' not found in folder '$searchPath'."
    }
  }
  else {
    Write-Host "The folder '$searchPath' does not exist."
  }
}
catch {
  Write-Error "An error occurred: $_"
  Write-Host "Ensure you have the correct file path and format."
}
