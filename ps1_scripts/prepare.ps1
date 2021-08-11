Param(
    [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String] $python2,
    [String] $python,
    [String] $project_root_dir,
    [String] $ini_file,
    [String] $config_file = '.config.json',
    [String] $download_dir = 'downloads',
    [String] $commit_sha
)


. $(Join-Path $PSScriptRoot 'utils.ps1')

$config = Get-ProjectCache $config_file

$config['python27_executable'] = $python2

$config['additional_version'] = Get-AdditionalVersion($commit_sha)

$project_root_dir = Get-ProjectRootDir $project_root_dir -config $config

$project_config = Get-ProjectConfig $ini_file -config $config -project_root_dir $project_root_dir

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
$xfm_native_wotmod = ''
$xfm_native_wotmod_url = ''

foreach ($match in $results)
{
    if ($match.Groups['name'] -match '-devel.zip$')
    {
        $xfm_native_devel_zip = $match.Groups['name']
        $xfm_native_devel_url = 'https://gitlab.com/xvm/xfw/xfw.native' + $match.Groups['path']
    }
    if ($match.Groups['name'] -match '.wotmod$')
    {
        $xfm_native_wotmod = $match.Groups['name']
        $xfm_native_wotmod_url = 'https://gitlab.com/xvm/xfw/xfw.native' + $match.Groups['path']
    }
}

New-Item -ItemType Directory $download_dir -Force

$xfm_native_devel_zip = Join-Path $download_dir $xfm_native_devel_zip
Invoke-WebRequest -Uri $xfm_native_devel_url -OutFile $xfm_native_devel_zip
$xfm_native_devel_zip_info = [System.IO.FileInfo]$xfm_native_devel_zip
$xfm_native_root = Join-Path $xfm_native_devel_zip_info.DirectoryName $xfm_native_devel_zip_info.BaseName
Expand-Archive -Path $xfm_native_devel_zip -DestinationPath $xfm_native_root -Force

$config['xfm_native_root'] = $xfm_native_root

$xfm_native_wotmod = $(Join-Path $download_dir $xfm_native_wotmod)
$xfm_native_wotmod = [System.IO.FileInfo]$xfm_native_wotmod
Invoke-WebRequest -Uri $xfm_native_wotmod_url -OutFile $xfm_native_wotmod

$config['xfm_native_wotmod'] = [System.IO.Path]::GetFullPath($xfm_native_wotmod)

# Download XVM for getting xfm.loader
$xvm_zip = "xvm-$($project_config.xfm_loader_version).zip"
$xvm_download_url = "https://dl1.modxvm.com/bin/${xvm_zip}"
$xvm_zip = Join-Path $download_dir $xvm_zip
Invoke-WebRequest -Uri $xvm_download_url -OutFile $xvm_zip
$xvm_zip_info = [System.IO.FileInfo]$xvm_zip
$xvm_root = Join-Path $xvm_zip_info.DirectoryName $xvm_zip_info.BaseName
Expand-Archive -Path $xvm_zip -DestinationPath $xvm_root -Force

$xfm_loader_wotmod = Get-ChildItem $xvm_root -Recurse | Where-Object {$_.BaseName -match 'xfw\.loader'}
# $xfm_loader_wotmod seems like `System.IO.FileInfo` not `System.Array` because number of filtered item is one...
$config['xfm_loader_wotmod'] = $xfm_loader_wotmod.FullName

ConvertTo-Json $config | Out-File $config_file
