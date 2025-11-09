function Test-ExternalToolInstalled {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ToolName
    )
    try {
        $null = Get-Command $ToolName -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

$JqIsReady = Test-ExternalToolInstalled -ToolName "jq"

if (-not $JqIsReady) {
    Write-Warning "not found jq command-line tool. Please install it first."
    exit 1
}

$checkverScriptLines = Get-Content "$PSScriptRoot/checkver-inner-script.ps1" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

$PSScriptRoot | Split-Path -Parent | Split-Path -Parent | Join-Path -ChildPath "bucket" | Get-ChildItem -File | 
    Where-Object { $_.Name -match "^blender(-latest|-lts-\d+\.\d+)\.json$" } |
    ForEach-Object {
        $json = $_ | Get-Content | ConvertFrom-Json -AsHashtable

        Write-Host "Updating $($_.Name)..."

        $url = if ($_.Name -match "blender-lts-(?<Version>\d+\.\d+)\.json") {
            $version = $Matches['Version']
            "https://download.blender.org/release/Blender$version/"
        } elseif ($_.Name -eq "blender-latest.json") {
            "https://download.blender.org/release/"
        } else {
            throw "Unexpected file name: $($_.Name)"
        }

        $json['checkver'] = [ordered]@{
            'url' = $url
            'regex' = "blender-([\w.]+)-windows-x64\.zip"
            'script' = $checkverScriptLines
        }

        $json | ConvertTo-Json -Depth 10 -Compress | jq --indent 4 '.' | Set-Content -Path $_.FullName -Encoding UTF8
    }