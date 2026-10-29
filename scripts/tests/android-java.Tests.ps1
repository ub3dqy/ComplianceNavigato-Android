. (Join-Path (Split-Path -Parent $PSScriptRoot) 'android-common.ps1')

Describe 'Qualified project Java selection' {
    BeforeEach {
        $savedJavaHome = $env:JAVA_HOME
        $projectRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path (Join-Path $projectRoot 'mobile') -Force
        '17.0.21' | Set-Content -LiteralPath (Join-Path $projectRoot 'mobile\.java-version')
        function New-SyntheticJdk([string]$HomePath, [string]$Version) {
            $null = New-Item -ItemType Directory -Path (Join-Path $HomePath 'bin') -Force
            ('JAVA_VERSION="{0}"' -f $Version) | Set-Content -LiteralPath (Join-Path $HomePath 'release')
            foreach ($tool in @('java', 'keytool', 'jarsigner')) {
                '' | Set-Content -LiteralPath (Join-Path $HomePath "bin\$tool.exe")
            }
            return $HomePath
        }
        $env:JAVA_HOME = New-SyntheticJdk (Join-Path $projectRoot 'ambient-old') '17.0.18'
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'java' }
    }
    AfterEach { $env:JAVA_HOME = $savedJavaHome }

    It 'selects the project security release over an old ambient JAVA_HOME' {
        $qualified = New-SyntheticJdk (Join-Path $projectRoot 'artifacts\tools\microsoft-jdk-17.0.21\jdk-17.0.21.0.2+1') '17.0.21.0.2'
        (Get-AndroidJavaHome -ProjectRoot $projectRoot) | Should Be $qualified
    }
    It 'permits a qualified environment JDK when the project SDK is absent' {
        $env:JAVA_HOME = New-SyntheticJdk (Join-Path $projectRoot 'ci-jdk') '17.0.22+2'
        (Get-AndroidJavaHome -ProjectRoot $projectRoot) | Should Be $env:JAVA_HOME
    }
    It 'refuses the old global Java without silently using it' {
        { Get-AndroidJavaHome -ProjectRoot $projectRoot } | Should Throw '17.0.21'
    }
    It 'refuses a different Java family even when its number is newer' {
        $env:JAVA_HOME = New-SyntheticJdk (Join-Path $projectRoot 'wrong-family') '21.0.13'
        { Get-AndroidJavaHome -ProjectRoot $projectRoot } | Should Throw 'JDK 17'
    }
    It 'requires signing tools as well as the runtime' {
        $partial = Join-Path $projectRoot 'artifacts\tools\jdk-17.0.21'
        $null = New-Item -ItemType Directory -Path (Join-Path $partial 'bin') -Force
        'JAVA_VERSION="17.0.21"' | Set-Content (Join-Path $partial 'release')
        '' | Set-Content (Join-Path $partial 'bin\java.exe')
        { Get-AndroidJavaHome -ProjectRoot $projectRoot } | Should Throw 'JDK 17'
    }
    It 'rejects malformed project minimum metadata' {
        '17.0.21; synthetic-command' | Set-Content -LiteralPath (Join-Path $projectRoot 'mobile\.java-version')
        { Get-AndroidJavaHome -ProjectRoot $projectRoot } | Should Throw 'Java'
    }
    It 'stops the actual Windows wrapper before Java when qualification fails' {
        $scriptsRoot = Join-Path $projectRoot 'scripts'
        $androidRoot = Join-Path $projectRoot 'mobile\android'
        $null = New-Item -ItemType Directory -Path $scriptsRoot, $androidRoot -Force
        foreach ($file in @('android-common.ps1', 'get-android-java-home.ps1')) {
            Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) $file) -Destination $scriptsRoot
        }
        $wrapper = Join-Path $androidRoot 'gradlew.bat'
        Copy-Item -LiteralPath (Join-Path $script:AndroidProjectRoot 'mobile\android\gradlew.bat') -Destination $wrapper
        'invalid-minimum' | Set-Content -LiteralPath (Join-Path $projectRoot 'mobile\.java-version')
        $previousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $output = @(& $wrapper --version 2>&1) -join "`n"
            $exitCode = $LASTEXITCODE
        } finally { $ErrorActionPreference = $previousPreference }
        $exitCode | Should Not Be 0
        $output | Should Match 'No qualified project JDK'
    }
    It 'uses the qualified Java for SDK batch tools and restores the ambient selection' {
        $qualified = New-SyntheticJdk (Join-Path $projectRoot 'artifacts\tools\jdk-17.0.21') '17.0.21'
        $ambient = $env:JAVA_HOME
        Mock Get-AndroidJavaHome { $qualified }
        $wrapper = Join-Path $projectRoot 'sdk-wrapper.bat'
        "@echo off`r`necho %JAVA_HOME%`r`nexit /b 0`r`n" | Set-Content -LiteralPath $wrapper -Encoding Ascii
        (Invoke-NativeText $wrapper @()).Trim() | Should Be $qualified
        $env:JAVA_HOME | Should Be $ambient
    }
    It 'restores the ambient Java after an SDK wrapper fails' {
        $ambient = $env:JAVA_HOME
        Mock Get-AndroidJavaHome { 'C:\synthetic-qualified-jdk' }
        $wrapper = Join-Path $projectRoot 'failed-sdk-wrapper.bat'
        "@echo off`r`nexit /b 7`r`n" | Set-Content -LiteralPath $wrapper -Encoding Ascii
        { Invoke-NativeText $wrapper @() } | Should Throw '7'
        $env:JAVA_HOME | Should Be $ambient
    }
    It 'restores an absent ambient JAVA_HOME after an SDK wrapper' {
        $env:JAVA_HOME = $null
        Mock Get-AndroidJavaHome { 'C:\synthetic-qualified-jdk' }
        $wrapper = Join-Path $projectRoot 'unset-sdk-wrapper.bat'
        "@echo off`r`necho %JAVA_HOME%`r`nexit /b 0`r`n" | Set-Content -LiteralPath $wrapper -Encoding Ascii
        (Invoke-NativeText $wrapper @()).Trim() | Should Be 'C:\synthetic-qualified-jdk'
        [string]::IsNullOrEmpty($env:JAVA_HOME) | Should Be $true
    }
}
