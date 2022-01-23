Param(
    [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String] $tested_latest_wot_version,
    [String] $xfm_native_root,
    [String] $pybind11_dir,
    [String] $config_file = '.config.json',
    [String] $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
    [String] $project_root_dir,
    [String] $ini_file,
    [String] $build_root_dir = 'build',
    [Switch] $use_short_path
)

. $(Join-Path $PSScriptRoot 'utils.ps1')

$config = Get-ProjectCache $config_file

if ($xfm_native_root -ne '') {
    $config['xfm_native_root'] = Convert-Path $xfm_native_root
}
if ($pybind11_dir -ne '') {
    $config['pybind11_dir'] = Convert-Path $pybind11_dir
}

$project_root_dir = Get-ProjectRootDir $project_root_dir -config $config

$project_config = Get-ProjectConfig $ini_file -config $config -project_root_dir $project_root_dir

$visual_studio = & "$vswhere" -utf8 -prerelease -latest -products * -requires Microsoft.VisualStudio.Component.VC.CMake.Project -format json
| ConvertFrom-Json

# I'd like to unify build dirs between this and Visual Studio Code
# https://github.com/microsoft/vscode-cmake-tools/blob/e86a553ec2712642ce5e44547e8e3d172537f029/src/kit.ts#L492
function GetDisplayNameVS {
    param (
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [PSCustomObject] $inst
    )
    if ($inst.displayName) {
        if ($inst.channelId) {
            $index = $inst.channelId.LastIndexOf('.')
            if ($index -gt 0) {
                return "$($inst.displayName) $($inst.channelId.Substring($index + 1))"
            }
        }
        return $inst.displayName;
    }
    return $inst.instanceId;
}

function CMakePath {
    param (
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [PSCustomObject] $visual_studio
    )
    $cmake = Join-Path `
                $visual_studio.installationPath `
                'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'`
                -Resolve
    return $cmake
}

$cmake = CMakePath($visual_studio)

function ConfigureEngine {
    param (
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String] $project_root_dir,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String] $xfm_native_root,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String] $pybind11_dir,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String] $build_root_dir,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String] $cmake,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [PSCustomObject] $visual_studio,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String] $build_target,
        [bool] $use_short_path
    )

    $tool_name = GetDisplayNameVS($visual_studio)
    $buildKit = "$tool_name - $build_target"
    $build_dir = Join-Path $build_root_dir "${buildKit}\Release"
    if ($use_short_path)
    {
        $build_dir = Join-Path $build_root_dir $build_target
    }
    New-Item -ItemType Directory $build_dir -Force | Write-Verbose

    # XFM Native libpython_DIR
    $xfm_target = ''
    switch ($build_target) {
        'x86'   { $xfm_target = 'Win32' }
        'amd64' { $xfm_target = 'x64' }
    }
    $libpython_DIR = Join-Path $xfm_native_root "${xfm_target}\lib\libpython" -Resolve

    $cmake_discord_game_sdk_arch = ''
    switch ($build_target) {
        'x86'   { $cmake_discord_game_sdk_arch = 'x86' }
        'amd64' { $cmake_discord_game_sdk_arch = 'x86_64' }
    }

    $vs_target = @()
    switch ($build_target) {
        'x86'   { $vs_target = @('-T', 'host=x86', '-A', 'Win32') }
        'amd64' { $vs_target = @('-T', 'host=x64', '-A', 'x64') }
    }

    & $cmake `
        -D ARCH="$cmake_discord_game_sdk_arch" `
        -D PYBIND11_NOPYTHON=ON                `
        -D pybind11_DIR="$pybind11_dir"        `
        -D libpython_DIR="$libpython_DIR"      `
        -S "$project_root_dir\engine"          `
        -B "$build_dir"                        `
        @vs_target                             `
        | Write-Verbose

    return Convert-Path $build_dir
}

Set-Variable -Name BUILD_TARGETS -Value @('x86', 'amd64') -Option Constant
$build_dirs = @()

foreach ($target in $BUILD_TARGETS) {
    $dir = ConfigureEngine -project_root_dir $project_root_dir -build_root_dir $build_root_dir `
                           -xfm_native_root $config['xfm_native_root'] -pybind11_dir $config['pybind11_dir'] `
                           -cmake $cmake -visual_studio $visual_studio -build_target $target `
                           -use_short_path $use_short_path
    $build_dirs += $dir
}

function ConfigurePackage {
    param (
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String] $project_root_dir,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String] $build_root_dir,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String] $cmake,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String] $python27
    )

    $build_dir = Join-Path $build_root_dir "package"
    New-Item -ItemType Directory $build_dir -Force | Write-Verbose

    & $cmake `
        -D PYTHON27_EXECUTABLE="$python27"          `
        -D MOD_VERSION="$($project_config.version)" `
        -S "$project_root_dir\package"              `
        -B "$build_dir"                             `
        | Write-Verbose

    return Convert-Path $build_dir
}

$build_dirs += & {
    $dir = ConfigurePackage -project_root_dir $project_root_dir -build_root_dir $build_root_dir `
                            -cmake $cmake -python27 $config['python27_executable']
    return $dir
}

# for readme files

$build_dirs += & {
    $build_dir = Join-Path $build_root_dir "distribution"
    New-Item -ItemType Directory $build_dir -Force | Write-Verbose

    & $cmake `
        -S "$project_root_dir\distribution" `
        -B "$build_dir"                     `
        -D WOTMOD_FILENAME=$($project_config.wotmod_filename) `
        -D TESTED_LATEST_WOT_VERSION=$tested_latest_wot_version `
        -D XFM_NATIVE_WOTMOD_FILENAME=$(([System.IO.FileInfo]$config['xfm_native_wotmod']).Name) `
        -D XFM_LOADER_WOTMOD_FILENAME=$(([System.IO.FileInfo]$config['xfm_loader_wotmod']).Name)
        | Write-Verbose

    $build_dir = Convert-Path $build_dir
    return $build_dir
}

$config['project_root_dir'] = $project_root_dir
$config['build_dirs'] = $build_dirs
$config['cmake'] = CMakePath($visual_studio)
$config['tested_latest_wot_version'] = $tested_latest_wot_version

ConvertTo-Json $config | Out-File $config_file
