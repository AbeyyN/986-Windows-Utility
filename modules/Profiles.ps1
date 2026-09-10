# 986 Profiles - selection metadata only. This module never applies Windows changes.
# PowerShell 5.1 compatible.

$script:BuiltIn986Profiles = @(
    [pscustomobject]@{
        Name='986 Balanced'
        Description='General-purpose Windows preference tweaks; no Policy enforcement.'
        TweakIds=@(
            'show-ext','open-thispc','disable-adid','disable-tailored','disable-feedback',
            'disable-tips','disable-silentapps','disable-pane-suggestions','disable-subscribed',
            'startup-delay','taskbar-end-task','hide-task-view','hide-taskbar-search',
            'disable-start-recommendations'
        )
    },
    [pscustomobject]@{
        Name='986 Performance'
        Description='Balanced plus user-editable gaming and visual performance preferences.'
        TweakIds=@(
            'show-ext','open-thispc','disable-adid','disable-tailored','disable-feedback','disable-tips',
            'disable-silentapps','disable-pane-suggestions','disable-subscribed','startup-delay',
            'taskbar-end-task','hide-task-view','hide-taskbar-search',
            'disable-start-recommendations','disable-game-capture','enable-game-mode','disable-transparency'
        )
    },

    [pscustomobject]@{
        Name='986 Laptop'
        Description='Conservative laptop preferences; avoids forced policies and persistent enforcement.'
        TweakIds=@(
            'show-ext','open-thispc','disable-adid','disable-tailored','disable-feedback','disable-tips',
            'disable-silentapps','disable-pane-suggestions','disable-subscribed','taskbar-end-task',
            'hide-task-view','hide-taskbar-search','disable-start-recommendations',
            'disable-transparency'
        )
    },
    [pscustomobject]@{
        Name='986 Technician'
        Description='Windows visibility and troubleshooting preferences; tools remain secondary.'
        TweakIds=@(
            'show-ext','show-hidden','open-thispc','hide-recent','hide-frequent','disable-tips',
            'disable-silentapps','disable-pane-suggestions','disable-subscribed','startup-delay',
            'taskbar-end-task','hide-task-view','hide-taskbar-search','show-clock-seconds',
            'start-more-pins','disable-start-recommendations'
        )
    }
)

function Get-986ProfileStorePath {
    if (-not $StateDir) { throw 'StateDir is not initialized.' }
    return (Join-Path $StateDir 'profiles.json')
}

function Get-986BuiltInProfiles {
    return @($script:BuiltIn986Profiles)
}

function Test-986BuiltInProfileName([string]$Name) {
    return [bool](@($script:BuiltIn986Profiles | Where-Object { $_.Name -eq $Name }).Count)
}

function Get-986CustomProfiles {
    $path = Get-986ProfileStorePath
    if (-not (Test-Path $path)) { return @() }
    try {
        $raw = Get-Content -Path $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $raw) { return @() }
        return @($raw | ForEach-Object {
            [pscustomobject]@{
                Name=[string]$_.Name
                Description=[string]$_.Description
                TweakIds=@($_.TweakIds | ForEach-Object { [string]$_ })
                Created=[string]$_.Created
                Updated=[string]$_.Updated
                Custom=$true
            }
        })
    } catch {
        Write-AppLog "PROFILE WARN store unreadable: $($_.Exception.Message)"
        return @()
    }
}

function Save-986CustomProfiles([object[]]$Profiles) {
    $path = Get-986ProfileStorePath
    New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
    $json = @($Profiles) | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText($path,$json,[Text.UTF8Encoding]::new($false))
}

function Test-986CustomProfileName([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    if ($Name.Length -gt 40) { return $false }
    if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9 _.-]*$') { return $false }
    if (Test-986BuiltInProfileName $Name) { return $false }
    return $true
}

function Save-986CustomProfile([string]$Name,[string[]]$TweakIds) {
    $Name = $Name.Trim()
    if (-not (Test-986CustomProfileName $Name)) {
        throw 'Profile name must be 1-40 characters, start with a letter/number, use only letters, numbers, spaces, dot, underscore or dash, and must not match a built-in profile.'
    }
    $ids = @($TweakIds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    if ($ids.Count -eq 0) { throw 'A custom profile must contain at least one tweak.' }

    $profiles = New-Object System.Collections.Generic.List[object]
    $now = (Get-Date).ToString('o')
    $existingCreated = $null
    foreach ($p in @(Get-986CustomProfiles)) {
        if ($p.Name -eq $Name) { $existingCreated = $p.Created; continue }
        $profiles.Add($p)
    }
    if (-not $existingCreated) { $existingCreated = $now }
    $profiles.Add([pscustomobject]@{
        Name=$Name
        Description='User-defined profile.'
        TweakIds=$ids
        Created=$existingCreated
        Updated=$now
        Custom=$true
    })
    Save-986CustomProfiles $profiles.ToArray()
    Write-AppLog "PROFILE SAVE '$Name' | tweaks=$($ids.Count)"
    return $Name
}

function Remove-986CustomProfile([string]$Name) {
    if (Test-986BuiltInProfileName $Name) { throw 'Built-in profiles cannot be deleted.' }
    $all = @(Get-986CustomProfiles)
    $remaining = @($all | Where-Object { $_.Name -ne $Name })
    if ($remaining.Count -eq $all.Count) { return $false }
    Save-986CustomProfiles $remaining
    Write-AppLog "PROFILE DELETE '$Name'"
    return $true
}

function Get-986ProfileNames {
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($p in @(Get-986BuiltInProfiles)) { $names.Add($p.Name) }
    foreach ($p in @(Get-986CustomProfiles | Sort-Object Name)) { $names.Add($p.Name) }
    return $names.ToArray()
}

function Get-986Profile([string]$Name) {
    $builtIn = @($script:BuiltIn986Profiles | Where-Object { $_.Name -eq $Name } | Select-Object -First 1)
    if ($builtIn.Count) { return $builtIn[0] }
    $custom = @(Get-986CustomProfiles | Where-Object { $_.Name -eq $Name } | Select-Object -First 1)
    if ($custom.Count) { return $custom[0] }
    return $null
}

function Get-986ProfileTweakIds([string]$Name) {
    $profile = Get-986Profile $Name
    if (-not $profile) { throw "Unknown profile: $Name" }
    return @($profile.TweakIds | ForEach-Object { [string]$_ })
}
