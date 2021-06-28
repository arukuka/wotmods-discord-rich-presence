Param(
    [String] $xfm_native_root,
    [String] $pybind11_dir,
    [String] $config_file = '.config.json',
    [String] $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
)

$config = ConvertFrom-Json '{}' -AsHashtable
if (Test-Path $config_file) {
    $config = Get-Content -Path $config_file | ConvertFrom-Json -AsHashtable
}
if ($xfm_native_root -ne '') {
    $config['xfm_native_root'] = $xfm_native_root
}
if ($pybind11_dir -ne '') {
    $config['pybind11_dir'] = $pybind11_dir
}

$visual_studio = & "$vswhere" -prerelease -latest -products * -requires Microsoft.VisualStudio.Component.VC.CMake.Project -format json
| ConvertFrom-Json

# $test = pip show pybind11 | ForEach-Object{ "$_" -replace ": ","="} | ForEach-Object{ [Regex]::Escape(($_))} | ConvertFrom-StringData
# Write-Host $test.Location
# $pybind11_dir =  Join-Path $test.Location 'pybind11\share\cmake\pybind11' -Resolve

function Configure {
    param (
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String] $project_root_dir,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String] $xfm_native_root,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String] $pybind11_dir,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String] $build_root_dir,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [PSCustomObject] $visual_studio,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String] $build_target
    )

    $cmake = Join-Path $visual_studio.installationPath 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe' -Resolve

    $tool_name = $visual_studio.displayName
    # https://github.com/microsoft/vscode-cmake-tools/blob/e86a553ec2712642ce5e44547e8e3d172537f029/src/kit.ts#L492
    $buildKit = "$tool_name - $build_target"
    $build_dir = Join-Path $build_root_dir "${buildKit}\Release"
    New-Item -ItemType Directory $build_dir -Force

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
        -S "$project_root_dir"                 `
        -B "$build_dir"                        `
        @vs_target                             `
        | Write-Host

    return "$build_dir"
}

Set-Variable -Name BUILD_TARGETS -Value @('x86', 'amd64') -Option Constant
$build_dirs = @()

foreach ($target in $BUILD_TARGETS) {
    $dir = Configure -project_root_dir "." -build_root_dir "build"                                     `
                     -xfm_native_root $config['xfm_native_root'] -pybind11_dir $config['pybind11_dir'] `
                     -visual_studio $visual_studio -build_target $target
    $build_dirs += $dir
}
