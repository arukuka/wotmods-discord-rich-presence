Param(
    [String] $config_file = '.config.json',
    [String] $install_dir = 'release',
    [String] $project_root_dir,
    [String] $ini_file
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
$wotmod_filename = $project_config.filename
foreach ($dict in $project_config.GetEnumerator()) {
    foreach ($token in $dict.GetEnumerator()) {
        $pattern = '@{0}@' -f $token.Key
        $wotmod_filename = $wotmod_filename -replace $pattern, $token.Value
    }
}

Set-Variable -Name WOTMOD_TARGETS_NAME -Value @('res', 'meta.xml', 'LICENSE', 'NOTICE') -Option Constant
$wotmod_targets = @()
foreach ($filename in $WOTMOD_TARGETS_NAME) {
    $wotmod_targets += Convert-Path $(Join-Path $install_dir $filename)
}

$wotmod_file_path = $(Join-Path $install_dir $wotmod_filename)
Remove-Item -Force $wotmod_file_path -ErrorAction Ignore
$wotmod_targets | Compress-Archive -DestinationPath $wotmod_file_path -CompressionLevel NoCompression
