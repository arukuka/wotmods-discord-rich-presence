Param(
    [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String] $python2,
    [String] $python,
    [String] $project_root_dir,
    [String] $ini_file,
    [String] $config_file = '.config.json',
    [String] $download_dir = 'downloads'
)

$config = ConvertFrom-Json '{}' -AsHashtable
if (Test-Path $config_file) {
    $config = Get-Content -Path $config_file | ConvertFrom-Json -AsHashtable
}

if ($project_root_dir -eq '') {
    $project_root_dir = $MyInvocation.MyCommand.Path
    foreach ($i in [System.Linq.Enumerable]::Range(0, 2)) {
        $project_root_dir = Split-Path $project_root_dir -Parent
    }
}
$project_root_dir = Convert-Path $project_root_dir

if ($ini_file -eq '') {
    $ini_file = Join-Path $project_root_dir 'project.ini' -Resolve
}

$project_config = Get-Content $ini_file | Where-Object { $_ -match ".*=.*" } | ConvertFrom-StringData

function pip()
{
    & $python2 -m pip $args
}
if ($python -ne '')
{
    # weird overriding
    function pip()
    {
        & $python -m pip $args
    }
}

# install pybind11
& pip install pybind11 | Write-Host
$pybind11_info = & pip show pybind11 | ForEach-Object{ "$_" -replace ": ","="} | ForEach-Object{ [Regex]::Escape(($_))} | ConvertFrom-StringData
$pybind11_dir = Join-Path $pybind11_info.Location 'pybind11\share\cmake\pybind11' -Resolve

$config['pybind11_dir'] = $pybind11_dir

# download XFM.Native
$response = Invoke-RestMethod -Uri "https://gitlab.com/api/v4/projects/xvm%2Fxfw%2Fxfw.native/releases/$($project_config.xfm_native_version)"
# use regex because a path to devel package is in description written by Markdown
$regex = [regex]'\[(?<name>.+?)\]\((?<path>.+?)\)'
$results = $regex.Matches($response.description)
$xfm_native_devel_zip = ''
$xfm_native_devel_url = ''

foreach ($match in $results)
{
    if ($match.Groups['name'] -match '-devel.zip$')
    {
        $xfm_native_devel_zip = $match.Groups['name']
        $xfm_native_devel_url = 'https://gitlab.com/xvm/xfw/xfw.native' + $match.Groups['path']
    }
}

New-Item -ItemType Directory $download_dir -Force
$xfm_native_devel_zip = Join-Path $download_dir $xfm_native_devel_zip
Invoke-WebRequest -Uri $xfm_native_devel_url -OutFile $xfm_native_devel_zip
$xfm_native_devel_zip_info = [System.IO.FileInfo]$xfm_native_devel_zip
$xfm_native_root = Join-Path $xfm_native_devel_zip_info.DirectoryName $xfm_native_devel_zip_info.BaseName
Expand-Archive -Path $xfm_native_devel_zip -DestinationPath $xfm_native_root -Force

$config['xfm_native_root'] = $xfm_native_root

ConvertTo-Json $config | Out-File $config_file
