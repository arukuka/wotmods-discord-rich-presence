function Get-ProjectCache {
    param (
        [String] $cache_file
    )
    $cache = ConvertFrom-Json '{}' -AsHashtable
    if (Test-Path $cache_file) {
        $cache = Get-Content -Path $cache_file | ConvertFrom-Json -AsHashtable
    }
    return $cache
}

function Expand-Variables {
    param (
        [System.Collections.Hashtable] $dict,
        [System.Collections.Hashtable] $targets
    )

    $dst = @{}
    foreach ($target in $targets.GetEnumerator()) {
        $acc = $target.Value
        foreach ($token in $dict.GetEnumerator()) {
            $pattern = '@{0}@' -f $token.Key
            $acc = $acc -replace $pattern, $token.Value
        }
        $dst[$target.Key] = $acc
    }

    return $dst
}

function Get-ProjectRootDir {
    param (
        [String] $project_root_dir,
        [System.Collections.Hashtable] $config
    )
    Set-Variable -Name KEY -Value 'project_root_dir' -Option Constant
    if ($config.ContainsKey($KEY)) {
        return $config[$KEY]
    }
    function Get-FromScriptPath {
        $project_root_dir = $MyInvocation.ScriptName
        foreach ($i in [System.Linq.Enumerable]::Range(0, 2)) {
            $project_root_dir = Split-Path $project_root_dir -Parent
        }
        return $project_root_dir
    }
    if ($project_root_dir -eq '') {
        $project_root_dir = Get-FromScriptPath
        $config[$KEY] = $project_root_dir
        return $project_root_dir
    }
    if (Test-Path $project_root_dir) {
        $config[$KEY] = $project_root_dir
        return $project_root_dir
    }
    $project_root_dir = Get-FromScriptPath
    $config[$KEY] = $project_root_dir
    return $project_root_dir
}

function Get-ProjectConfig {
    param (
        [String] $ini_file,
        [System.Collections.Hashtable] $config,
        [String] $project_root_dir
    )
    if ($ini_file -eq '') {
        $project_root_dir = Get-ProjectRootDir $project_root_dir $config
        $ini_file = Join-Path $project_root_dir 'project.ini' -Resolve
    }

    $raw_config = Get-Content $ini_file `
        | Where-Object { $_ -match ".*=.*" }

    $project_config = @{}
    foreach ($raw in $raw_config) {
        $raw_dict = $raw | ConvertFrom-StringData
        $fixed = Expand-Variables $($project_config + $config) $raw_dict
        $project_config += $fixed
    }

    return $project_config
}
