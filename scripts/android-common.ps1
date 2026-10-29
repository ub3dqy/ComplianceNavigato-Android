$ErrorActionPreference = "Stop"

$script:AndroidProjectRoot = Split-Path -Parent $PSScriptRoot
$script:AndroidMobileRoot = Join-Path $script:AndroidProjectRoot "mobile"
$script:PilotKeyAlias = "compliance-navigator-pilot"
$script:PilotKeyPath = Join-Path $env:USERPROFILE ".android\compliance-navigator-pilot-upload.jks"
$script:PilotSecretPath = Join-Path $env:USERPROFILE ".android\compliance-navigator-pilot-signing.dpapi.json"

function Get-PilotAppVersion([string]$ProjectRoot = $script:AndroidProjectRoot) {
    $pubspec = [IO.File]::ReadAllText((Join-Path $ProjectRoot 'mobile/pubspec.yaml'))
    $matches = [regex]::Matches($pubspec, '(?m)^version:\s*([0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4})\+([1-9][0-9]{0,9})\s*$')
    if ($matches.Count -ne 1) { throw 'A single explicit Android version is required.' }
    $code = [long]$matches[0].Groups[2].Value
    if ($code -gt 2100000000) { throw 'Android version code exceeds the platform limit.' }
    $version = $matches[0].Groups[1].Value
    return [pscustomobject]@{ Version=$version; VersionName="$version-pilot"; VersionCode=[int]$code }
}

function Resolve-FlutterCommand([string]$ProjectRoot = $script:AndroidProjectRoot) {
    $versionFile = Join-Path $ProjectRoot "mobile\.flutter-version"
    $version = (Get-Content -LiteralPath $versionFile -Raw).Trim()
    if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "Некорректная закреплённая версия Flutter." }
    $projectSdk = Join-Path $ProjectRoot "artifacts\tools\flutter-$version\bin\flutter.bat"
    $dart = Join-Path (Split-Path -Parent $projectSdk) 'dart.bat'
    if (-not (Test-Path -LiteralPath $projectSdk -PathType Leaf) -or
        -not (Test-Path -LiteralPath $dart -PathType Leaf)) {
        throw "Отдельный Flutter $version проекта не подготовлен в artifacts/tools. Общий SDK не используется."
    }
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $projectSdk --no-version-check --version --machine 2>&1 | ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($exitCode -ne 0) { throw "Проверка отдельного Flutter $version завершилась ошибкой." }
    try { $actual = ($output -join "`n") | ConvertFrom-Json }
    catch { throw "Отдельный Flutter $version не вернул корректные сведения о версии." }
    if ($actual -isnot [pscustomobject] -or $actual.frameworkVersion -cne $version -or $actual.channel -cne 'stable') {
        throw "Нужен отдельный Flutter $version stable; версия или канал SDK проекта не совпадают."
    }
    return (Resolve-Path -LiteralPath $projectSdk).Path
}

function Resolve-AndroidSdkPath {
    foreach ($candidate in @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME, "E:\Android\Sdk", (Join-Path $env:LOCALAPPDATA "Android\Sdk"))) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate "platform-tools\adb.exe"))) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw "Android SDK не найден."
}

function Resolve-AndroidTool([string]$Name, [switch]$BuildTool) {
    $sdk = Resolve-AndroidSdkPath
    if ($BuildTool) {
        $directory = Get-ChildItem -LiteralPath (Join-Path $sdk "build-tools") -Directory |
            Where-Object { $_.Name -match '^36\.\d+\.\d+$' } |
            Sort-Object { [version]$_.Name } -Descending |
            Select-Object -First 1
        if (-not $directory) { throw "Android build-tools 36.x не найдены." }
        $path = Join-Path $directory.FullName "$Name.exe"
        if (-not (Test-Path -LiteralPath $path)) {
            $path = Join-Path $directory.FullName "$Name.bat"
        }
    } else {
        $path = Join-Path $sdk "platform-tools\$Name.exe"
    }
    if (-not (Test-Path -LiteralPath $path)) { throw "$Name не найден: $path" }
    return $path
}

function Resolve-AndroidCommandLineTool(
    [ValidateSet('apkanalyzer', 'avdmanager', 'sdkmanager')][string]$Name,
    [string]$ProjectRoot = $script:AndroidProjectRoot
) {
    $version = (Get-Content -LiteralPath (Join-Path $ProjectRoot 'mobile\.android-command-line-tools-version') -Raw).Trim()
    if ($version -notmatch '^\d+\.\d+(?:\.\d+)?$') { throw 'Invalid Android command-line tools pin.' }
    $sdk = Resolve-AndroidSdkPath
    foreach ($folder in @($version, 'latest')) {
        $directory = Join-Path $sdk "cmdline-tools\$folder"
        $properties = Join-Path $directory 'source.properties'
        if (-not (Test-Path -LiteralPath $properties -PathType Leaf) -or
            -not (Select-String -LiteralPath $properties -Pattern ('^Pkg\.Revision\s*=\s*' + [regex]::Escape($version) + '\s*$') -Quiet)) {
            continue
        }
        foreach ($extension in @('exe', 'bat')) {
            $tool = Join-Path $directory "bin\$Name.$extension"
            if (Test-Path -LiteralPath $tool -PathType Leaf) { return $tool }
        }
    }
    throw "Android command-line tools $version with $Name are not prepared or their actual version differs."
}

function Get-AndroidJavaVersion([string]$JavaHome) {
    if (-not $JavaHome) { return $null }
    foreach ($file in @('release', 'bin\java.exe', 'bin\keytool.exe', 'bin\jarsigner.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path $JavaHome $file) -PathType Leaf)) { return $null }
    }
    $release = Get-Content -LiteralPath (Join-Path $JavaHome 'release') -Raw
    $match = [regex]::Match($release, '(?m)^JAVA_VERSION="(?<core>17\.0\.\d+)(?:[.+-][^"]*)?"\r?$')
    if (-not $match.Success) { return $null }
    return [version]$match.Groups['core'].Value
}

function Get-AndroidJavaHome([string]$ProjectRoot = $script:AndroidProjectRoot) {
    $minimum = (Get-Content -LiteralPath (Join-Path $ProjectRoot 'mobile\.java-version') -Raw).Trim()
    if ($minimum -notmatch '^17\.0\.[1-9]\d*$') { throw 'Некорректная минимальная версия Java проекта.' }
    $minimumVersion = [version]$minimum
    $tools = Join-Path $ProjectRoot 'artifacts\tools'
    $qualified = @()
    if (Test-Path -LiteralPath $tools -PathType Container) {
        foreach ($directory in @(Get-ChildItem -LiteralPath $tools -Directory | Where-Object {
            $_.Name -match '^(microsoft-jdk|temurin|jdk)-'
        })) {
            $homes = @($directory.FullName) + @(Get-ChildItem -LiteralPath $directory.FullName -Directory | ForEach-Object FullName)
            foreach ($homePath in $homes) {
                $version = Get-AndroidJavaVersion $homePath
                if ($version -and $version -ge $minimumVersion) {
                    $qualified += [pscustomobject]@{ Home = $homePath; Version = $version }
                }
            }
        }
    }
    if ($qualified.Count) {
        return ($qualified | Sort-Object Version, Home -Descending | Select-Object -First 1).Home
    }
    $candidates = @($env:JAVA_HOME)
    $command = Get-Command java -ErrorAction SilentlyContinue
    if ($command) { $candidates += Split-Path -Parent (Split-Path -Parent $command.Source) }
    foreach ($candidate in $candidates) {
        $version = Get-AndroidJavaVersion $candidate
        if ($version -and $version -ge $minimumVersion) { return (Resolve-Path -LiteralPath $candidate).Path }
    }
    throw "Нужен полный JDK 17 не ниже $minimum. Подготовьте проверенный SDK в artifacts/tools; общая Java не изменяется."
}

function Resolve-JavaTool([ValidateSet('java', 'keytool', 'jarsigner')][string]$Name) {
    return Join-Path (Get-AndroidJavaHome) "bin\$Name.exe"
}

function Set-AndroidLocalProperties {
    $propertiesPath = Join-Path $script:AndroidMobileRoot "android\local.properties"
    $flutter = Resolve-FlutterCommand
    $flutterSdk = Split-Path -Parent (Split-Path -Parent $flutter)
    $sdk = Resolve-AndroidSdkPath
    $remaining = if (Test-Path -LiteralPath $propertiesPath) {
        @(Get-Content -LiteralPath $propertiesPath | Where-Object {
            $_ -notmatch '^(sdk\.dir|flutter\.sdk)='
        })
    } else {
        @()
    }
    $escapePath = {
        param([string]$Value)
        $Value.Replace('\', '/').Replace(':', '\:')
    }
    $content = @(
        "sdk.dir=$(& $escapePath $sdk)",
        "flutter.sdk=$(& $escapePath $flutterSdk)"
    ) + $remaining
    Write-Utf8NoBom -Path $propertiesPath -Content (($content -join "`n") + "`n")
}

function Resolve-BundletoolJar {
    $version = "1.18.3"
    $expectedSha256 = "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29" # pragma: allowlist secret
    $toolDirectory = Join-Path $script:AndroidProjectRoot "artifacts\tools\bundletool-$version"
    $jar = Join-Path $toolDirectory "bundletool-all-$version.jar"
    if (-not (Test-Path -LiteralPath $jar)) {
        New-Item -ItemType Directory -Force -Path $toolDirectory | Out-Null
        $gh = (Get-Command gh -ErrorAction Stop).Source
        & $gh release download $version --repo google/bundletool `
            --pattern "bundletool-all-$version.jar" --dir $toolDirectory --clobber
        if ($LASTEXITCODE -ne 0) { throw "Не удалось загрузить официальный bundletool." }
    }
    $actual = (Get-FileHash -LiteralPath $jar -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expectedSha256) {
        throw "bundletool не прошёл проверку опубликованного SHA-256."
    }
    return $jar
}

function New-PilotPassword([int]$Length = 48) {
    $alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!%+,-.:=@_"
    $bytes = New-Object byte[] $Length
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $generator.GetBytes($bytes) } finally { $generator.Dispose() }
    return -join ($bytes | ForEach-Object { $alphabet[$_ % $alphabet.Length] })
}

function Set-CurrentUserOnlyAcl([string]$Path) {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    & icacls.exe $Path /inheritance:r /grant:r "${identity}:(F)" /c *> $null
    if ($LASTEXITCODE -ne 0) { throw "Не удалось ограничить ACL файла $Path." }
}

function Protect-PilotSecret([string]$Value) {
    $secure = ConvertTo-SecureString -String $Value -AsPlainText -Force
    return ConvertFrom-SecureString -SecureString $secure
}

function Unprotect-PilotSecret([string]$Value) {
    $secure = ConvertTo-SecureString -String $Value
    $credential = [System.Management.Automation.PSCredential]::new("pilot", $secure)
    return $credential.GetNetworkCredential().Password
}

function Read-PilotSigningSecrets {
    if (-not (Test-Path -LiteralPath $script:PilotSecretPath)) {
        throw "Защищённые данные pilot-подписи не найдены."
    }
    $protected = Get-Content -Raw -LiteralPath $script:PilotSecretPath | ConvertFrom-Json
    if ($protected.schemaVersion -ne 1 -or -not $protected.storePassword -or -not $protected.keyPassword) {
        throw "Файл pilot-подписи имеет неверный формат."
    }
    return @{
        StorePassword = Unprotect-PilotSecret $protected.storePassword
        KeyPassword = Unprotect-PilotSecret $protected.keyPassword
    }
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Get-ResolvedAndroidPackageVersion {
    param(
        [Parameter(Mandatory = $true)][ValidatePattern('^[a-z][a-z0-9_]*$')][string]$Name,
        [string]$MobileRoot = $script:AndroidMobileRoot
    )
    $configPath = [IO.Path]::GetFullPath((Join-Path $MobileRoot '.dart_tool\package_config.json'))
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    $entries = @($config.packages | Where-Object name -CEQ $Name)
    if ($entries.Count -ne 1) { throw "Expected exactly one resolved package: $Name" }
    $root = [uri]::new([uri]::new($configPath), [string]$entries[0].rootUri)
    if (-not $root.IsFile) { throw "Resolved package must use a local file URI: $Name" }
    $pubspec = Get-Content -LiteralPath (Join-Path $root.LocalPath 'pubspec.yaml') -Raw
    $actualMatch = [regex]::Match($pubspec, '(?m)^version:\s*(?<version>[^\r\n#]+)')
    $actual = $actualMatch.Groups['version'].Value.Trim().Trim('"', "'")
    if ($actual -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$') {
        throw "Invalid resolved package version: $Name"
    }
    $lock = Get-Content -LiteralPath (Join-Path $MobileRoot 'pubspec.lock') -Raw
    $block = [regex]::Match($lock, ('(?ms)^  ' + [regex]::Escape($Name) + ':\r?\n(?<body>.*?)(?=^  [a-zA-Z_]|\z)'))
    $lockedMatch = [regex]::Match($block.Groups['body'].Value, '(?m)^    version:\s*(?<version>[^\r\n#]+)')
    $locked = $lockedMatch.Groups['version'].Value.Trim().Trim('"', "'")
    if ($actual -cne $locked) { throw "Resolved package version differs from pubspec.lock: $Name" }
    return $actual
}

function Get-RepositorySchemaHash {
    $schema = Join-Path $script:AndroidProjectRoot "docs\api\openapi-v1.json"
    if (-not (Test-Path -LiteralPath $schema)) { throw "OpenAPI snapshot не найден." }
    return (Get-FileHash -LiteralPath $schema -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-AndroidForegroundWindow([string]$WindowDump, [string]$ExpectedPackage) {
    if (-not $ExpectedPackage -or [string]::IsNullOrWhiteSpace($WindowDump)) {
        throw "Не удалось подтвердить окно Android-приложения."
    }
    if ($WindowDump -match '(?i)permissioncontroller|Application Error:|Application Not Responding:|AppNotRespondingDialog') {
        throw "Android показывает системную ошибку, зависание или запрос разрешений."
    }
    if ($WindowDump -notmatch [regex]::Escape($ExpectedPackage)) {
        throw "На переднем плане отсутствует проверяемое Android-приложение."
    }
}

function Get-AndroidSingleReadyDevice {
    param(
        [AllowEmptyCollection()][string[]]$AdbDevicesOutput,
        [switch]$AllowNoDevice,
        [switch]$AllowSingleOfflineAsNoDevice
    )

    $ready = @()
    $offline = @()
    foreach ($rawLine in @($AdbDevicesOutput)) {
        $line = $rawLine.Trim()
        if (-not $line -or $line -eq "List of devices attached" -or $line -match '^\* daemon ') {
            continue
        }
        if ($line -notmatch '^(\S+)\s+(\S+)(?:\s+.*)?$') {
            throw "adb devices вернул неоднозначный список устройств."
        }
        $deviceId = $Matches[1]
        $state = $Matches[2]
        switch ($state) {
            "device" { $ready += $deviceId }
            "unauthorized" { throw "Android-устройство не авторизовано для безопасной установки." }
            "offline" { $offline += $deviceId }
            default { throw "Android-устройство имеет неподдерживаемое состояние '$state'; установка остановлена." }
        }
    }
    if ($offline.Count -gt 0) {
        if ($AllowSingleOfflineAsNoDevice -and $offline.Count -eq 1 -and $ready.Count -eq 0) {
            return $null
        }
        throw "Android-устройство находится offline; установка остановлена."
    }
    if ($ready.Count -gt 1) {
        throw "Подключено несколько готовых Android-устройств; установка остановлена."
    }
    if ($ready.Count -eq 0) {
        if ($AllowNoDevice) { return $null }
        throw "Нет единственного готового Android-устройства."
    }
    return $ready[0]
}

function Test-AndroidPackagePresent([string]$PackagePathOutput, [int]$ExitCode) {
    if ([string]::IsNullOrWhiteSpace($PackagePathOutput)) {
        if ($ExitCode -in @(0, 1)) { return $false }
        throw "Не удалось проверить наличие Android package."
    }
    if ($ExitCode -ne 0) {
        throw "Не удалось проверить наличие Android package."
    }
    $lines = @($PackagePathOutput -split "`r?`n" | Where-Object { $_.Trim() })
    if ($lines.Count -gt 0 -and @($lines | Where-Object { $_ -notmatch '^package:\S+$' }).Count -eq 0) {
        return $true
    }
    throw "Не удалось надёжно определить наличие Android package через adb shell pm path."
}

function Get-AndroidPackageVersion([string]$PackageDump) {
    $versionCodeMatches = [regex]::Matches($PackageDump, '(?m)^\s*versionCode=(\d+)\b')
    $versionNameMatches = [regex]::Matches($PackageDump, '(?m)^\s*versionName=(.+?)\s*$')
    if ($versionCodeMatches.Count -ne 1 -or $versionNameMatches.Count -ne 1) {
        throw "Android package manager вернул неоднозначную версию package."
    }
    return [pscustomobject]@{
        VersionCode = [int]$versionCodeMatches[0].Groups[1].Value
        VersionName = $versionNameMatches[0].Groups[1].Value
    }
}

function Get-AndroidInstallPlan {
    param(
        [bool]$PackagePresent,
        [string]$InstalledPackageDump,
        [int]$TargetVersionCode,
        [string]$TargetVersionName
    )

    if (-not $PackagePresent) {
        return [pscustomobject]@{
            Mode = "CLEAN_INSTALL"
            Message = "Выполняется чистая установка"
            PackageWasInstalled = $false
            ExistingVersionCode = $null
            ExistingVersionName = $null
        }
    }
    $existing = Get-AndroidPackageVersion -PackageDump $InstalledPackageDump
    $oldLabel = "$($existing.VersionName)+$($existing.VersionCode)"
    $newLabel = "$TargetVersionName+$TargetVersionCode"
    if ($existing.VersionCode -lt $TargetVersionCode) {
        return [pscustomobject]@{
            Mode = "UPGRADE"
            Message = "Выполняется обновление $oldLabel → $newLabel"
            PackageWasInstalled = $true
            ExistingVersionCode = $existing.VersionCode
            ExistingVersionName = $existing.VersionName
        }
    }
    if ($existing.VersionCode -eq $TargetVersionCode -and $existing.VersionName -ceq $TargetVersionName) {
        return [pscustomobject]@{
            Mode = "REINSTALL"
            Message = "Выполняется переустановка $newLabel"
            PackageWasInstalled = $true
            ExistingVersionCode = $existing.VersionCode
            ExistingVersionName = $existing.VersionName
        }
    }
    if ($existing.VersionCode -gt $TargetVersionCode) {
        throw "На устройстве установлена более новая версия $oldLabel; downgrade запрещён."
    }
    throw "Version code совпадает, но version name отличается; установка остановлена."
}

function Get-AndroidApkIdentity([string]$BadgingOutput) {
    if ($BadgingOutput -notmatch "(?m)^package:\s+name='([^']+)'\s+versionCode='(\d+)'\s+versionName='([^']+)'") {
        throw "Не удалось надёжно прочитать package и версию APK."
    }
    return [pscustomobject]@{
        PackageName = $Matches[1]
        VersionCode = [int]$Matches[2]
        VersionName = $Matches[3]
    }
}

function Get-AndroidPackageUid([string]$PackageListOutput, [int]$ExitCode, [string]$PackageName) {
    if ($ExitCode -ne 0) {
        throw "Не удалось получить UID Android package."
    }
    $escapedPackage = [regex]::Escape($PackageName)
    if ($PackageListOutput -match "(?m)^package:${escapedPackage}\s+uid:(\d+)\s*$") {
        return $Matches[1]
    }
    throw "Android package manager вернул неоднозначный UID."
}

function Invoke-NativeText([string]$FilePath, [string[]]$Arguments) {
    $previousPreference = $ErrorActionPreference
    $previousJavaHome = $env:JAVA_HOME
    $javaWrapper = [IO.Path]::GetExtension($FilePath) -in @('.bat', '.cmd')
    try {
        # Android SDK wrappers also consult JAVA_HOME, independently of Gradle.
        if ($javaWrapper) { $env:JAVA_HOME = Get-AndroidJavaHome }
        $ErrorActionPreference = "Continue"
        $output = & $FilePath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
        if ($javaWrapper) { $env:JAVA_HOME = $previousJavaHome }
    }
    if ($exitCode -ne 0) {
        throw "$FilePath завершился с кодом $exitCode."
    }
    return ($output | ForEach-Object { $_.ToString() }) -join "`n"
}

function Assert-VerifiedJarSignature([string]$Report) {
    if ([string]::IsNullOrWhiteSpace($Report)) {
        throw "Отчёт проверки JAR-подписи пуст."
    }
    if ($Report -match '(?im)^\s*(?:jar is unsigned\.|no manifest\.)\s*$' -or
        $Report -match '(?m)^\s*\?\s+\d+\s+') {
        throw "AAB не имеет подтверждённой JAR-подписи."
    }
    if ($Report -notmatch '(?im)^\s*jar verified\.\s*$') {
        throw "jarsigner не подтвердил подпись AAB."
    }
    if ($Report -notmatch '(?m)^\s*s[mks]*\s+\d+\s+') {
        throw "jarsigner не показал ни одной проверенной signed entry AAB."
    }
}

function Protect-AndroidLogText([string]$Text) {
    $fieldPattern = '(?i)(["'']?(?:authorization|access[_-]?token|refresh[_-]?token|id[_-]?token|token|password|email)["'']?\s*[:=]\s*)(?:"[^"\r\n]*"|''[^''\r\n]*''|Bearer\s+[^\s,;}\]]+|[^\s,;}\]]+)'
    $sanitized = [regex]::Replace($Text, $fieldPattern, '$1[REDACTED]')
    $sanitized = [regex]::Replace(
        $sanitized,
        '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+',
        'Bearer [REDACTED]'
    )
    $sanitized = [regex]::Replace(
        $sanitized,
        '\beyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\b',
        '[JWT_REDACTED]'
    )
    return [regex]::Replace(
        $sanitized,
        '(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
        '[EMAIL_REDACTED]'
    )
}
