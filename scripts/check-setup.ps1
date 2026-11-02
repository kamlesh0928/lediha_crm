# LEDiHA CRM - setup checker for Windows.
# Run from the project folder:
#   powershell -ExecutionPolicy Bypass -File scripts\check-setup.ps1
# It only reads things; it never changes anything and never prints your keys.

$ErrorActionPreference = 'Continue'
function Ok($m)   { Write-Host "[ OK ] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Bad($m)  { Write-Host "[FAIL] $m" -ForegroundColor Red }

$root = Split-Path -Parent $PSScriptRoot
Write-Host ""
Write-Host "LEDiHA CRM - setup check ($root)"
Write-Host ""

# 1. Flutter
$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutter) { Ok "Flutter found: $($flutter.Source)" } else { Bad "Flutter is not on PATH. Add <flutter folder>\bin to PATH." }

# 2. Java that Gradle will use
$propsFile = Join-Path $root 'android\gradle.properties'
$javaHome = $null
if (Test-Path $propsFile) {
  $m = Select-String -Path $propsFile -Pattern '^\s*org\.gradle\.java\.home\s*=\s*(.+)$' | Select-Object -First 1
  if ($m) { $javaHome = $m.Matches[0].Groups[1].Value.Trim() }
}
if (-not $javaHome) { $javaHome = $env:JAVA_HOME; if ($javaHome) { Warn "No org.gradle.java.home in android\gradle.properties; Gradle will use JAVA_HOME." } }
if ($javaHome) {
  $javaExe = Join-Path ($javaHome -replace '/', '\') 'bin\java.exe'
  if (Test-Path $javaExe) {
    $ver = (& $javaExe -version 2>&1 | Select-Object -First 1).ToString()
    if ($ver -match '"(17|21)\.') { Ok "Gradle Java: $javaHome  [$ver]" }
    else { Bad "Gradle Java is not 17 or 21: $ver  -> this causes the build error '25.0.3'. Fix org.gradle.java.home in android\gradle.properties." }
  } else {
    Bad "Java folder does not exist: $javaHome  -> install JDK 17 or point org.gradle.java.home to Android Studio's 'jbr' folder."
  }
} else {
  Bad "No Java found for Gradle. Install JDK 17 and set org.gradle.java.home in android\gradle.properties."
}

# 3. Supabase settings file
$cfg = $null
foreach ($candidate in @('assets\config\env.json', 'env.json')) {
  $path = Join-Path $root $candidate
  if (Test-Path $path) { $cfg = $path; Ok "Config file found: $candidate"; break }
}
if (-not $cfg) {
  Bad "No config file. Create assets\config\env.json (see SETUP.md step 5)."
} else {
  try {
    $json = Get-Content $cfg -Raw | ConvertFrom-Json
    $url = [string]$json.SUPABASE_URL
    $key = [string]$json.SUPABASE_PUBLISHABLE_KEY
    if (-not $key) { $key = [string]$json.SUPABASE_ANON_KEY }
    if ($url -like 'https://*.supabase.co*' -and $url -notmatch 'YOUR') { Ok "SUPABASE_URL looks right" } else { Bad "SUPABASE_URL is missing or still the example value" }
    if ($key -like 'sb_publishable_*' -and $key -notmatch 'YOUR') { Ok "Publishable key looks right" }
    elseif ($key -like 'sb_secret_*') { Bad "That is a SECRET key. Use the publishable key (sb_publishable_...)." }
    elseif ($key -like 'eyJ*') { Warn "Old-style anon key detected. It may still work; the publishable key is preferred." }
    else { Bad "SUPABASE_PUBLISHABLE_KEY is missing or still the example value" }
  } catch { Bad "Config file is not valid JSON (check commas and quotes)." }
}

# 4. Git must ignore the config file
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git -and (Test-Path (Join-Path $root '.git'))) {
  Push-Location $root
  $tracked = git ls-files 'env.json' 'assets/config/env.json' 2>$null
  if ($tracked) { Bad "Git is tracking a secrets file ($tracked). Run: git rm --cached <file>" } else { Ok "Config files are not tracked by Git" }
  Pop-Location
} else { Warn "Git check skipped (no git or no repository)." }

# 5. Devices
if ($flutter) {
  Write-Host ""
  Write-Host "Connected devices / emulators:"
  flutter devices
}
Write-Host ""
Write-Host "Done. Fix every [FAIL] line first, then follow SETUP.md."
