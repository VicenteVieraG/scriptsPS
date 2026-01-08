<#
.SYNOPSIS
    Adds or removes a module from the project base structure.
.DESCRIPTION
    Creates or removes a module for my CMake project structure template.
    When adding, it will generate the folders src/<ModuleName> and include/<ModuleName>, with
    the respective <ModuleName>.cpp and <ModuleName>.h files. It will also add the
    new module to the CMake project by creating a CMakeLists.txt file in each folder
    and adding the subdirectory to the parent CMakeLists.txt file. When removing, it
    will delete the module folders and remove the subdirectory entries from the parent
    CMakeLists.txt files.
.NOTES
    Author: Vicente Javier Viera Guízar
    GitHub profile: https://github.com/VicenteVieraG
    Script repo: https://github.com/VicenteVieraG/scriptsPS
.LINK
    https://github.com/VicenteVieraG/CMake-Template
.PARAMETER AddModule
    The name of the module to be created.
.PARAMETER RemoveModule
    The name of the module to be removed.
.INPUTS
    [string]
.EXAMPLE
    ./ctl.ps1 -AddModule MyModule
.EXAMPLE
    ./ctl.ps1 -RemoveModule MyModule
#>
[CmdletBinding(DefaultParameterSetName = "Add")]
PARAM(
    [Parameter(Mandatory = $true, ParameterSetName = "Add")]
    [string]$AddModule,
    [Parameter(Mandatory = $true, ParameterSetName = "Remove")]
    [string]$RemoveModule
);

function Write-ModuleError {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage,
        [Parameter(Mandatory = $true)]
        [string]$DetailsMessage
    );

    Write-Error -Message $ErrorMessage;
    Write-Debug -Message $DetailsMessage;
}

function New-ModuleItems {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage,
        [Parameter(Mandatory = $true)]
        [hashtable[]]$Items
    );

    try {
        foreach ($item in $Items) {
            New-Item -Name $item.Name -Path $item.Path -ItemType $item.Type -ErrorAction Stop | Out-Null;
        }
    }
    catch {
        Write-ModuleError -ErrorMessage $ErrorMessage -DetailsMessage "Error: $($_.Exception.Message)";
    }
}

function Remove-ModuleItems {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage,
        [Parameter(Mandatory = $true)]
        [string[]]$Items
    );

    try {
        foreach ($item in $Items) {
            if (Test-Path -Path $item) {
                Remove-Item -Path $item -Recurse -Force -ErrorAction Stop | Out-Null;
            }
        }
    }
    catch {
        Write-ModuleError -ErrorMessage $ErrorMessage -DetailsMessage "Error: $($_.Exception.Message)";
    }
}

function Add-CMakeSubdirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    );

    $content = Get-Content -Path $Path -Raw;
    $line = "add_subdirectory($ModuleName)";
    $needsLeadingNewline = $content.Length -gt 0 -and -not $content.EndsWith("`r`n");
    $prefix = if ($needsLeadingNewline) { "`r`n" } else { "" };

    Add-Content -Path $Path -Value "$prefix$line`r`n";
}

function Remove-CMakeSubdirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    );

    if (-not (Test-Path -Path $Path)) {
        Write-ModuleError -ErrorMessage "Failed to update $Path." -DetailsMessage "File does not exist.";
        return;
    }

    $content = Get-Content -Path $Path -Raw;
    $endsWithNewline = $content.EndsWith("`r`n");
    $escaped = [regex]::Escape($ModuleName);
    $pattern = "(?m)^\s*add_subdirectory\(\s*$escaped\s*\)\s*(\r?\n)?";
    $updated = [regex]::Replace($content, $pattern, "");

    if ($updated -ne $content) {
        if ($endsWithNewline -and -not $updated.EndsWith("`r`n")) {
            $updated += "`r`n";
        }
        Set-Content -Path $Path -Value $updated -NoNewline;
    }
}

function Add-Module {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    );

    New-ModuleItems -ErrorMessage "Failed to create $ModuleName's module directories." -Items @(
        @{ Name = $ModuleName; Path = "src"; Type = "Directory" },
        @{ Name = $ModuleName; Path = "include"; Type = "Directory" }
    );
    Write-Host "Created directories for module: '$ModuleName'." -ForegroundColor Green;

    New-ModuleItems -ErrorMessage "Failed to create $ModuleName's source files." -Items @(
        @{ Name = "$ModuleName.cpp"; Path = "src/$ModuleName"; Type = "File" },
        @{ Name = "$ModuleName.hpp"; Path = "include/$ModuleName"; Type = "File" }
    );
    Write-Host "Created source files for module: '$ModuleName'." -ForegroundColor Green;

    New-ModuleItems -ErrorMessage "Failed to create $ModuleName's CMakeLists.txt files." -Items @(
        @{ Name = "CMakeLists.txt"; Path = "src/$ModuleName"; Type = "File" },
        @{ Name = "CMakeLists.txt"; Path = "include/$ModuleName"; Type = "File" }
    );
    Write-Host "Created CMakeLists.txt files for module: '$ModuleName'." -ForegroundColor Green;

    Add-CMakeSubdirectory -Path "src/CMakeLists.txt" -ModuleName $ModuleName;
    Add-CMakeSubdirectory -Path "include/CMakeLists.txt" -ModuleName $ModuleName;
    Write-Host "Added subdirectory entries to CMakeLists.txt files for module: '$ModuleName'." -ForegroundColor Green;
}

function Remove-Module {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    );

    Remove-CMakeSubdirectory -Path "src/CMakeLists.txt" -ModuleName $ModuleName;
    Remove-CMakeSubdirectory -Path "include/CMakeLists.txt" -ModuleName $ModuleName;
    Write-Host "Removed subdirectory entries from CMakeLists.txt files for module: '$ModuleName'." -ForegroundColor Green;

    Remove-ModuleItems -ErrorMessage "Failed to remove $ModuleName's module directories." -Items @(
        "src/$ModuleName",
        "include/$ModuleName"
    );
    Write-Host "Removed directories for module: '$ModuleName'." -ForegroundColor Green;
}

$ModuleName = if ($PSCmdlet.ParameterSetName -eq "Add") { $AddModule } else { $RemoveModule };
$ModuleName = $ModuleName.Trim();
$ModuleName = $ModuleName -replace "\s+", "_";

if ([string]::IsNullOrWhiteSpace($ModuleName)) {
    Write-ModuleError -ErrorMessage "Module name cannot be empty." -DetailsMessage "Provided module name is blank.";
    exit 1;
}

switch ($PSCmdlet.ParameterSetName) {
    "Add" { Add-Module -ModuleName $ModuleName; break }
    "Remove" { Remove-Module -ModuleName $ModuleName; break }
}
