. (Join-Path $PSScriptRoot 'android-common.ps1')

# Only emit the selected path: gradlew.bat consumes this as one value.
Get-AndroidJavaHome
