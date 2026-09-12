Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Test-986ResolutionRequest {
    param(
        [Parameter(Mandatory=$true)][int]$Width,
        [Parameter(Mandatory=$true)][int]$Height,
        [Parameter(Mandatory=$true)][int]$RefreshRate
    )
    if ($Width -lt 640 -or $Width -gt 16384) { return $false }
    if ($Height -lt 480 -or $Height -gt 16384) { return $false }
    if ($RefreshRate -lt 24 -or $RefreshRate -gt 1000) { return $false }
    return $true
}

function Get-986ResolutionProvider {
    param([string]$AdapterName,[string]$AdapterCompatibility)
    $text = (($AdapterName + ' ' + $AdapterCompatibility).Trim()).ToLowerInvariant()
    if ($text -match 'amd|advanced micro devices|radeon') { return 'AMD-ADLX' }
    if ($text -match 'nvidia|geforce|quadro') { return 'NVIDIA-NVAPI' }
    if ($text -match 'intel|iris|uhd') { return 'Intel-IGCL' }
    return 'Windows-ExistingMode'
}

function Get-986DisplayAdapters {
    $items = @()
    try {
        foreach ($gpu in @(Get-CimInstance Win32_VideoController -ErrorAction Stop)) {
            $provider = Get-986ResolutionProvider -AdapterName ([string]$gpu.Name) -AdapterCompatibility ([string]$gpu.AdapterCompatibility)
            $items += [pscustomobject]@{
                Name = [string]$gpu.Name
                Vendor = [string]$gpu.AdapterCompatibility
                DriverVersion = [string]$gpu.DriverVersion
                CurrentWidth = [int]$gpu.CurrentHorizontalResolution
                CurrentHeight = [int]$gpu.CurrentVerticalResolution
                CurrentRefreshRate = [int]$gpu.CurrentRefreshRate
                Provider = $provider
            }
        }
    } catch { }
    return @($items)
}

function Get-986ResolutionCapability {
    param([Parameter(Mandatory=$true)]$Adapter)
    $provider = [string]$Adapter.Provider
    $customCandidate = $provider -in @('AMD-ADLX','NVIDIA-NVAPI','Intel-IGCL')
    return [pscustomobject]@{
        Provider = $provider
        ExistingModesSupported = $true
        TrueCustomCandidate = $customCandidate
        TrueCustomReady = $false
        Status = if ($customCandidate) { 'PROVIDER_BINDING_REQUIRED' } else { 'EXISTING_MODES_ONLY' }
        Safety = 'TEST_CONFIRM_REVERT_REQUIRED'
    }
}

function New-986ResolutionPlan {
    param(
        [Parameter(Mandatory=$true)]$Adapter,
        [Parameter(Mandatory=$true)][int]$Width,
        [Parameter(Mandatory=$true)][int]$Height,
        [Parameter(Mandatory=$true)][int]$RefreshRate,
        [switch]$ExistingMode
    )
    if (-not (Test-986ResolutionRequest -Width $Width -Height $Height -RefreshRate $RefreshRate)) {
        throw 'Resolution request is outside 986 safety bounds.'
    }
    $cap = Get-986ResolutionCapability -Adapter $Adapter
    $canApply = [bool]$ExistingMode
    return [pscustomobject]@{
        Width = $Width
        Height = $Height
        RefreshRate = $RefreshRate
        Provider = $cap.Provider
        ModeKind = if ($ExistingMode) { 'Existing' } else { 'Custom' }
        CanApply = $canApply
        RequiresTrial = $true
        RequiresConfirmation = $true
        AutoRevertRequired = $true
        Reason = if ($ExistingMode) { 'Windows existing mode path.' } else { 'Custom provider binding and rollback validation are required before apply is enabled.' }
    }
}
