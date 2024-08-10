[string]$vcpkgList = & vcpkg list;

$regex = "boost-[\w-]+:x64-windows";
$boostLibs = [regex]::Matches($vcpkgList, $regex);

# Get available threads
[Int32]$threads = [Environment]::ProcessorCount;

$boostLibs | Foreach-Object -ThrottleLimit $threads -Parallel {
    & vcpkg remove $_ --recurse | Write-Output;
}