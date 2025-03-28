<#
.SYNOPSIS
    Adds a mudule to the project base structure.
.DESCRIPTION
    Creates a new module for my CMake project structure template.
    It will generate the folders src/<ModuleName> and include/<ModuleName>, with
    the respective <ModuleName>.cpp and <ModuleName>.h files. It will also add the
    new module to the CMake project by creating a CMakeLists.txt file in each folder
    and adding the subdirectory to the parent CMakeLists.txt file.
.NOTES
    Author: Vicente Javier Viera Guízar
    GitHub profile: https://github.com/VicenteVieraG
    Script repo: https://github.com/VicenteVieraG/scriptsPS
.LINK
    https://github.com/VicenteVieraG/CMake-Template
.PARAMETER ModuleName
    The name of the module to be created.
.INPUTS
    [string]
.EXAMPLE
    ./addModule.ps1 -ModuleName MyModule
#>
PARAM(
    [Parameter(Mandatory = $true)]
    [string]$ModuleName
);

$ModuleName = $ModuleName.Trim();
$ModuleName = $ModuleName -replace "\s+", "_";

New-Item -Name $ModuleName -Path src -ItemType Directory -Force;
New-Item -Name $ModuleName -Path include -ItemType Directory -Force;

New-Item -Name "$ModuleName.cpp" -Path src/$ModuleName -ItemType File -Force;
New-Item -Name "$ModuleName.hpp" -Path include/$ModuleName -ItemType File -Force;

New-Item -Name CMakeLists.txt -Path src/$ModuleName -ItemType File -Force;
New-Item -Name CMakeLists.txt -Path include/$ModuleName -ItemType File -Force;

[string]$CMakeListsSrcContent = Get-Content -Path src/CMakeLists.txt -Raw;
[string]$CMakeListsIncludeContent = Get-Content -Path include/CMakeLists.txt -Raw;

if(-not $CMakeListsSrcContent.endsWith("`r`n")){
    Add-Content -Path src/CMakeLists.txt -Value "`r`nadd_subdirectory($ModuleName)";
}else{
    Add-Content -Path src/CMakeLists.txt -Value "add_subdirectory($ModuleName)";
}
if(-not $CMakeListsIncludeContent.EndsWith("`r`n")){
    Add-Content -Path include/CMakeLists.txt -Value "`r`nadd_subdirectory($ModuleName)";
}else{
    Add-Content -Path include/CMakeLists.txt -Value "add_subdirectory($ModuleName)";
}