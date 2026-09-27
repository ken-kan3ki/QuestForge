# generate_ai_file_index.ps1
#
# Developer utility for QuestForge.
# Lists all Dart source files under lib/ with their sizes, to assist in
# manually updating AI_CONTEXT/FILE_INDEX.md after significant file additions.
#
# IMPORTANT: This script is READ-ONLY. It does NOT modify any application source files.
#
# Usage:
#   powershell -File tool/generate_ai_file_index.ps1
#   powershell -File tool/generate_ai_file_index.ps1 -OutputFile AI_CONTEXT\FILE_INDEX_RAW.txt
#
# Output: A grouped listing of .dart files under lib/ with byte sizes.
# After running, manually review and update AI_CONTEXT/FILE_INDEX.md with purpose descriptions.

param(
    [string]$RootPath = (Split-Path $PSScriptRoot -Parent),
    [string]$OutputFile = ""
)

$libPath = Join-Path $RootPath "lib"
$testPath = Join-Path $RootPath "test"

if (-not (Test-Path $libPath)) {
    Write-Error "lib/ directory not found at: $libPath"
    exit 1
}

$output = @()
$output += "# QuestForge — Raw File Listing"
$output += "# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$output += "# Use this as a reference to update AI_CONTEXT/FILE_INDEX.md"
$output += "# DO NOT commit this file — it is a scratch output."
$output += ""

# Group lib/ files by immediate parent folder
$libFiles = Get-ChildItem -Path $libPath -Recurse -Filter "*.dart" | Sort-Object FullName

$grouped = $libFiles | Group-Object { $_.DirectoryName }

foreach ($group in $grouped) {
    $relativeFolderPath = $group.Name.Replace($RootPath, "").TrimStart("\").TrimStart("/")
    $output += "## $relativeFolderPath/"
    foreach ($file in $group.Group | Sort-Object Name) {
        $sizeKb = [math]::Round($file.Length / 1024, 1)
        $output += "  $($file.Name)  ($sizeKb KB)"
    }
    $output += ""
}

# Test files
if (Test-Path $testPath) {
    $testFiles = Get-ChildItem -Path $testPath -Filter "*.dart" | Sort-Object Name
    $output += "## test/"
    foreach ($file in $testFiles) {
        $sizeKb = [math]::Round($file.Length / 1024, 1)
        $output += "  $($file.Name)  ($sizeKb KB)"
    }
    $output += ""
}

$output += "# End of listing"
$output += "# Total lib/ files: $($libFiles.Count)"
$output += "# Total test/ files: $(if (Test-Path $testPath) { (Get-ChildItem -Path $testPath -Filter '*.dart').Count } else { 0 })"

$outputText = $output -join "`n"

if ($OutputFile -ne "") {
    $resolvedOutput = if ([System.IO.Path]::IsPathRooted($OutputFile)) {
        $OutputFile
    } else {
        Join-Path $RootPath $OutputFile
    }
    $outputText | Out-File -FilePath $resolvedOutput -Encoding UTF8
    Write-Host "Output written to: $resolvedOutput"
} else {
    Write-Output $outputText
}
