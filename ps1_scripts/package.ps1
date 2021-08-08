Param(
    [String] $config_file = '.config.json',
    [String] $install_dir = 'release',
    [String] $project_root_dir,
    [String] $ini_file
)

. $(Join-Path $PSScriptRoot 'utils.ps1')

$config = Get-ProjectCache $config_file

$project_root_dir = Get-ProjectRootDir $project_root_dir -config $config

$project_config = Get-ProjectConfig $ini_file -config $config -project_root_dir $project_root_dir

$cmake = $config['cmake']

foreach ($build_dir in $config['build_dirs'])
{
    & $cmake --install $build_dir --prefix $install_dir | Write-Host
}

# Copy DLL of Discord Game SDK
Set-Variable -Name DISCORD_GAME_SDK_DLL_FILENAME -Value 'discord_game_sdk.dll' -Option Constant
Set-Variable -Name ARCHES -Value @('x86', 'x86_64') -Option Constant

foreach ($target in $ARCHES) {
    $dll_path = Join-Path $install_dir 'lib' "${target}" "${DISCORD_GAME_SDK_DLL_FILENAME}"
    $install_arch_dir = ''
    switch ($target) {
        'x86'    { $install_arch_dir = 'native_32bit' }
        'x86_64' { $install_arch_dir = 'native_64bit' }
    }
    $install_dll_path = Join-Path $install_dir 'res' 'mods' 'xfw_packages' 'discord_rich_presence' "${install_arch_dir}" "${DISCORD_GAME_SDK_DLL_FILENAME}"
    Copy-Item $dll_path $install_dll_path
}

# Manually copy LICENSE, NOTICE
Set-Variable -Name COPYRIGHT_FILES -Value @('LICENSE', 'NOTICE') -Option Constant
foreach ($filename in $COPYRIGHT_FILES) {
    $from = Join-Path $project_root_dir $filename
    Copy-Item -Force $from $(Join-Path $install_dir $filename)
    Copy-Item -Force $from $(Join-Path $install_dir 'package' 'readme' "${filename}.txt")
}

# Create wotmod

Set-Variable -Name WOTMOD_TARGETS_NAME -Value @('res', 'meta.xml', 'LICENSE', 'NOTICE') -Option Constant
$wotmod_targets = @()
foreach ($filename in $WOTMOD_TARGETS_NAME) {
    $wotmod_targets += Convert-Path $(Join-Path $install_dir $filename)
}

$wotmod_file_path = $(Join-Path $install_dir $project_config.wotmod_filename)
$wotmod_targets | Compress-Archive -DestinationPath $wotmod_file_path -CompressionLevel NoCompression -Force

# Create zip

## Copy wotmod files
$mods_dir = Join-Path $install_dir 'package' 'mods'
$wotmods_install_dir = Join-Path $mods_dir $config['tested_latest_wot_version']
New-Item -ItemType Directory $wotmods_install_dir -Force | Write-Verbose

foreach ($filepath in @($config['xfm_loader_wotmod'], $config['xfm_native_wotmod'], $wotmod_file_path)) {
    Copy-Item $filepath $(Join-Path $wotmods_install_dir ([System.IO.FileInfo]$filepath).Name)
}

## Copy config files
Copy-Item -Recurse $(Join-Path $project_root_dir 'mods' 'configs') $mods_dir

$zip_file_path = Join-Path $install_dir $project_config.zip_filename
Get-ChildItem $(Join-Path $install_dir 'package') | Compress-Archive -DestinationPath $zip_file_path -Force
