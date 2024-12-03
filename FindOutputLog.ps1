# Enhanced Script to Find output.log in AppData/Roaming/Testing folder
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
      } else {
          Write-Host "File '$fileName' not found in folder '$searchPath'."
      }
  } else {
      Write-Host "The folder '$searchPath' does not exist."
  }
} catch {
  Write-Error "An error occurred: $_"
  Write-Host "Ensure you have internet access and the script URL is correct."
}
