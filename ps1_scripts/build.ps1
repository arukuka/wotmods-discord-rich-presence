Param(
    [String] $config_file = '.config.json'
)

. $(Join-Path $PSScriptRoot 'utils.ps1')

$config = Get-ProjectCache $config_file

$cmake = $config['cmake']

foreach ($build_dir in $config['build_dirs'])
{
    & $cmake --build $build_dir --config Release | Write-Verbose
}
