[CmdletBinding()]
param(
    [string]$addModule,
    [string]$removeModule
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$script:NewLine = [Environment]::NewLine
$script:ProjectRoot = Split-Path -Parent $PSCommandPath

function Write-UsageError {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    throw "$Message Usage: ./ctl.ps1 -addModule <Module_Name> | -removeModule <Module_Name>"
}

function Get-RequestedAction {
    $requests = [System.Collections.Generic.List[object]]::new()

    if (-not [string]::IsNullOrWhiteSpace($addModule)) {
        $requests.Add([pscustomobject]@{
                Action = 'Add'
                Module = $addModule.Trim()
            })
    }

    if (-not [string]::IsNullOrWhiteSpace($removeModule)) {
        $requests.Add([pscustomobject]@{
                Action = 'Remove'
                Module = $removeModule.Trim()
            })
    }

    if ($requests.Count -eq 0) {
        Write-UsageError 'You must provide exactly one action.'
    }

    if ($requests.Count -gt 1) {
        Write-UsageError 'Parameters -addModule and -removeModule are mutually exclusive.'
    }

    return $requests[0]
}

function Assert-ValidModuleName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    if ([string]::IsNullOrWhiteSpace($ModuleName)) {
        Write-UsageError 'Module name cannot be empty.'
    }

    if ($ModuleName -notmatch '^[A-Za-z0-9_]+$') {
        throw "Invalid module name '$ModuleName'. Only letters, digits, and underscores are allowed."
    }
}

function Get-ModulePaths {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    $srcRoot = Join-Path $script:ProjectRoot 'src'
    $includeRoot = Join-Path $script:ProjectRoot 'include'
    $srcDir = Join-Path $srcRoot $ModuleName
    $includeDir = Join-Path $includeRoot $ModuleName

    return [pscustomobject]@{
        SourceRoot         = $srcRoot
        IncludeRoot        = $includeRoot
        SourceTopLevelCMake = Join-Path $srcRoot 'CMakeLists.txt'
        IncludeTopLevelCMake = Join-Path $includeRoot 'CMakeLists.txt'
        SourceDir          = $srcDir
        IncludeDir         = $includeDir
        SourceCMake        = Join-Path $srcDir 'CMakeLists.txt'
        IncludeCMake       = Join-Path $includeDir 'CMakeLists.txt'
        SourceFile         = Join-Path $srcDir "$ModuleName.cpp"
        IncludeFile        = Join-Path $includeDir "$ModuleName.hpp"
    }
}

function Get-FileSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $exists = Test-Path -LiteralPath $Path -PathType Leaf
    $content = ''

    if ($exists) {
        $content = [System.IO.File]::ReadAllText($Path)
    }

    return [pscustomobject]@{
        Path    = $Path
        Exists  = $exists
        Content = $content
    }
}

function Restore-FileSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Snapshot
    )

    if ($Snapshot.Exists) {
        [System.IO.File]::WriteAllText($Snapshot.Path, $Snapshot.Content, $script:Utf8NoBom)
        return
    }

    if (Test-Path -LiteralPath $Snapshot.Path -PathType Leaf) {
        Remove-Item -LiteralPath $Snapshot.Path -Force
    }
}

function Get-FileLines {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @()
    }

    return [System.IO.File]::ReadAllLines($Path)
}

function Write-FileLines {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Lines
    )

    $normalized = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $Lines) {
        $normalized.Add($line)
    }

    while ($normalized.Count -gt 0 -and [string]::IsNullOrWhiteSpace($normalized[$normalized.Count - 1])) {
        $normalized.RemoveAt($normalized.Count - 1)
    }

    $content = ''

    if ($normalized.Count -gt 0) {
        $content = ($normalized -join $script:NewLine) + $script:NewLine
    }

    [System.IO.File]::WriteAllText($Path, $content, $script:Utf8NoBom)
}

function Test-ContainsExactLine {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Lines,
        [Parameter(Mandatory = $true)]
        [string]$Line
    )

    foreach ($existingLine in $Lines) {
        if ([string]::Equals($existingLine, $Line, [System.StringComparison]::Ordinal)) {
            return $true
        }
    }

    return $false
}

function Update-ManagedLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Line,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Add', 'Remove')]
        [string]$Mode
    )

    $currentLines = Get-FileLines -Path $Path
    $updatedLines = [System.Collections.Generic.List[string]]::new()

    foreach ($currentLine in $currentLines) {
        $updatedLines.Add($currentLine)
    }

    if ($Mode -eq 'Add') {
        if (-not (Test-ContainsExactLine -Lines $updatedLines.ToArray() -Line $Line)) {
            $updatedLines.Add($Line)
        }
    }
    else {
        for ($index = $updatedLines.Count - 1; $index -ge 0; $index--) {
            if ([string]::Equals($updatedLines[$index], $Line, [System.StringComparison]::Ordinal)) {
                $updatedLines.RemoveAt($index)
            }
        }
    }

    Write-FileLines -Path $Path -Lines $updatedLines.ToArray()
}

function New-ModuleStructure {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    $paths = Get-ModulePaths -ModuleName $ModuleName
    $srcExists = Test-Path -LiteralPath $paths.SourceDir -PathType Container
    $includeExists = Test-Path -LiteralPath $paths.IncludeDir -PathType Container

    if ($srcExists -or $includeExists) {
        if ($srcExists -and $includeExists) {
            throw "Module '$ModuleName' already exists."
        }

        throw "Module '$ModuleName' is in a partial state. Expected both '$($paths.SourceDir)' and '$($paths.IncludeDir)' to be absent before adding."
    }

    $sourceTopLevelSnapshot = Get-FileSnapshot -Path $paths.SourceTopLevelCMake
    $includeTopLevelSnapshot = Get-FileSnapshot -Path $paths.IncludeTopLevelCMake

    try {
        New-Item -ItemType Directory -Path $paths.SourceDir -Force | Out-Null
        New-Item -ItemType Directory -Path $paths.IncludeDir -Force | Out-Null

        [System.IO.File]::WriteAllText(
            $paths.SourceCMake,
            ('add_library({0} STATIC {0}.cpp){1}' -f $ModuleName, $script:NewLine),
            $script:Utf8NoBom
        )

        [System.IO.File]::WriteAllText(
            $paths.IncludeCMake,
            ('target_include_directories({0} PUBLIC ${{CMAKE_CURRENT_SOURCE_DIR}}){1}' -f $ModuleName, $script:NewLine),
            $script:Utf8NoBom
        )

        [System.IO.File]::WriteAllText($paths.SourceFile, '', $script:Utf8NoBom)
        [System.IO.File]::WriteAllText($paths.IncludeFile, '', $script:Utf8NoBom)

        $subdirectoryLine = 'add_subdirectory({0})' -f $ModuleName
        Update-ManagedLine -Path $paths.SourceTopLevelCMake -Line $subdirectoryLine -Mode Add
        Update-ManagedLine -Path $paths.IncludeTopLevelCMake -Line $subdirectoryLine -Mode Add
    }
    catch {
        Restore-FileSnapshot -Snapshot $sourceTopLevelSnapshot
        Restore-FileSnapshot -Snapshot $includeTopLevelSnapshot

        if (Test-Path -LiteralPath $paths.SourceDir -PathType Container) {
            Remove-Item -LiteralPath $paths.SourceDir -Recurse -Force
        }

        if (Test-Path -LiteralPath $paths.IncludeDir -PathType Container) {
            Remove-Item -LiteralPath $paths.IncludeDir -Recurse -Force
        }

        throw
    }
}

function Remove-ModuleStructure {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    $paths = Get-ModulePaths -ModuleName $ModuleName
    $srcExists = Test-Path -LiteralPath $paths.SourceDir -PathType Container
    $includeExists = Test-Path -LiteralPath $paths.IncludeDir -PathType Container

    if (-not ($srcExists -and $includeExists)) {
        if (-not $srcExists -and -not $includeExists) {
            throw "Module '$ModuleName' does not exist."
        }

        throw "Module '$ModuleName' is in a partial state. Expected both '$($paths.SourceDir)' and '$($paths.IncludeDir)' to exist before removing."
    }

    Remove-Item -LiteralPath $paths.SourceDir -Recurse -Force
    Remove-Item -LiteralPath $paths.IncludeDir -Recurse -Force

    $subdirectoryLine = 'add_subdirectory({0})' -f $ModuleName
    Update-ManagedLine -Path $paths.SourceTopLevelCMake -Line $subdirectoryLine -Mode Remove
    Update-ManagedLine -Path $paths.IncludeTopLevelCMake -Line $subdirectoryLine -Mode Remove
}

try {
    $request = Get-RequestedAction
    Assert-ValidModuleName -ModuleName $request.Module

    if ($request.Action -eq 'Add') {
        New-ModuleStructure -ModuleName $request.Module
        Write-Output ("Created module '{0}'." -f $request.Module)
    }
    else {
        Remove-ModuleStructure -ModuleName $request.Module
        Write-Output ("Removed module '{0}'." -f $request.Module)
    }
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
