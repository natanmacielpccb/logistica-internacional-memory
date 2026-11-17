[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$TargetRoot)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false, $true)
if (-not (Test-Path -LiteralPath $TargetRoot -PathType Container)) { throw 'Abra/crie o projeto primeiro e informe sua pasta existente.' }
$target = [IO.Path]::GetFullPath((Get-Item -LiteralPath $TargetRoot).FullName).TrimEnd([IO.Path]::DirectorySeparatorChar)
$source = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
if ($target -eq $source -or $target.StartsWith($source + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Use uma copia do pacote separada da pasta do projeto.'
}
function Check-Link([string]$Path) {
    $cursor = $Path
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if ($item.LinkType -in @('SymbolicLink','Junction')) { throw "Link/junction no destino: $cursor" }
        }
        $parent = Split-Path -Parent $cursor
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}
function Destination([string]$Relative) {
    if (-not $Relative -or [IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)|:') { throw 'Caminho de pacote invalido.' }
    $path = [IO.Path]::GetFullPath((Join-Path $target $Relative))
    if (-not $path.StartsWith($target + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Destino fora do projeto.' }
    Check-Link $path
    return $path
}
function Hash([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return 'missing' }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Replace-Bytes([string]$Path, [byte[]]$Bytes) {
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    $temp = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllBytes($temp, $Bytes)
        if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($temp, $Path, [System.Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($temp, $Path) }
    } finally { if (Test-Path -LiteralPath $temp) { [IO.File]::Delete($temp) } }
}
Check-Link $target
$manifestPath = Join-Path $source 'package-files.json'
$package = [IO.File]::ReadAllText($manifestPath, $utf8) | ConvertFrom-Json
$statePath = Destination '.logistica/package-state.json'
$previous = @{}
if (Test-Path -LiteralPath $statePath) {
    $state = [IO.File]::ReadAllText($statePath, $utf8) | ConvertFrom-Json
    foreach ($file in @($state.files)) { $previous[[string]$file.path] = [string]$file.sha256 }
}
$conflicts = @()
$planned = @()
$seen = @{}
foreach ($file in @($package.files)) {
    $relative = [string]$file.path
    if ($seen.ContainsKey($relative)) { throw 'Arquivo repetido no pacote.' }
    $seen[$relative] = $true
    if ($relative -match '^(Operacoes|Resumos|\.logistica)(/|\\|$)') { throw 'Pacote tenta incluir dados operacionais.' }
    $destination = Destination $relative
    $origin = [IO.Path]::GetFullPath((Join-Path (Join-Path $source 'payload') $relative))
    $payloadRoot = [IO.Path]::GetFullPath((Join-Path $source 'payload'))
    if (-not $origin.StartsWith($payloadRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Origem fora de payload.' }
    Check-Link $origin
    if (-not (Test-Path -LiteralPath $origin -PathType Leaf) -or (Hash $origin) -ne $file.sha256) { throw "Integridade invalida no pacote: $relative" }
    if (Test-Path -LiteralPath $destination -PathType Container) { $conflicts += $relative; continue }
    $parent = Split-Path -Parent $destination
    while ($parent -and $parent -ne $target) {
        if (Test-Path -LiteralPath $parent -PathType Leaf) { $conflicts += $relative; break }
        $parent = Split-Path -Parent $parent
    }
    $actual = Hash $destination
    if ($actual -ne 'missing' -and $actual -ne $file.sha256 -and (-not $previous.ContainsKey($relative) -or $previous[$relative] -ne $actual)) {
        $conflicts += $relative
    }
    $planned += [ordered]@{ path=$relative; destination=$destination; origin=$origin; before=$actual; after=[string]$file.sha256 }
}
foreach ($folder in @('Operacoes','Resumos','.logistica')) {
    $path = Destination $folder
    if (Test-Path -LiteralPath $path -PathType Leaf) { $conflicts += $folder }
}
if ($conflicts.Count -gt 0) { throw ('Arquivos existentes preservados. Resolva conflitos antes de instalar: ' + (($conflicts | Select-Object -Unique) -join ', ')) }
[void][IO.Directory]::CreateDirectory((Destination '.logistica'))
$lockPath = Destination '.logistica/memory.lock'
try { $lock = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
catch { throw 'Projeto em uso; repita a instalacao quando terminar a gravacao atual.' }
try {
    if (Test-Path -LiteralPath (Destination '.logistica/pending.json')) { throw 'Reconcile a transacao interrompida antes de atualizar.' }
    foreach ($file in $planned) {
        if ((Hash $file.destination) -ne $file.before) { throw ('Arquivo mudou durante instalacao: ' + $file.path) }
    }
    foreach ($file in $planned) {
        if ($file.before -ne $file.after) { Replace-Bytes $file.destination ([IO.File]::ReadAllBytes($file.origin)) }
        if ((Hash $file.destination) -ne $file.after) { throw ('Falha de verificacao: ' + $file.path) }
    }
    foreach ($folder in @('Operacoes','Resumos')) { [void][IO.Directory]::CreateDirectory((Destination $folder)) }
    $installed = [ordered]@{ version=[string]$package.version; installed=[DateTimeOffset]::UtcNow.ToString('o'); files=@($planned | ForEach-Object { [ordered]@{ path=$_.path; sha256=$_.after } }) }
    Replace-Bytes $statePath ($utf8.GetBytes(($installed | ConvertTo-Json -Depth 8)))
    [ordered]@{ status='installed'; version=$package.version; root=$target; operationsCreated=0; files=@($installed.files) } | ConvertTo-Json -Depth 8
} finally { $lock.Dispose() }
