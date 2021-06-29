Param(
    [String] $config_file = '.config.json'
)

$config = ConvertFrom-Json '{}' -AsHashtable
if (Test-Path $config_file) {
    $config = Get-Content -Path $config_file | ConvertFrom-Json -AsHashtable
}

$cmake = $config['cmake']

foreach ($build_dir in $config['build_dirs'])
{
    & $cmake --build $build_dir --config Release | Write-Host
}
