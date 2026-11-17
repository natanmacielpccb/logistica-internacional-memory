[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('Snapshot','Create','Commit','Source','Acknowledge')][string]$Command,
    [Parameter(Mandatory=$true)][string]$Root,
    [string]$Description,
    [string]$Prc,
    [string]$Manifest,
    [string]$Operation,
    [string]$InputFile
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false, $true)

function Assert-NoLink([string]$Path) {
    $cursor = $Path
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if ($item.LinkType -in @('SymbolicLink','Junction')) { throw "Link/junction fora do fluxo: $cursor" }
        }
        $parent = Split-Path -Parent $cursor
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}
if (-not (Test-Path -LiteralPath $Root -PathType Container)) { throw 'Raiz inexistente.' }
$rootPath = [IO.Path]::GetFullPath((Get-Item -LiteralPath $Root).FullName).TrimEnd([IO.Path]::DirectorySeparatorChar)
Assert-NoLink $rootPath
function Resolve-Local([string]$Relative) {
    if (-not $Relative -or [IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)|:') {
        throw "Caminho relativo invalido: $Relative"
    }
    $path = [IO.Path]::GetFullPath((Join-Path $rootPath $Relative))
    if (-not $path.StartsWith($rootPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Destino fora da raiz.' }
    Assert-NoLink $path
    return $path
}
function Hash([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return 'missing' }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Text-Hash([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes($Text)))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Write-Atomic([string]$Path, [string]$Text) {
    $temp = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($temp, $Text, $utf8)
        if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($temp, $Path, [System.Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($temp, $Path) }
    } finally { if (Test-Path -LiteralPath $temp) { [IO.File]::Delete($temp) } }
}
$state = Resolve-Local '.logistica'
if (-not (Test-Path -LiteralPath $state -PathType Container)) { throw 'Projeto nao instalado: falta .logistica.' }
$lockPath = Resolve-Local '.logistica/memory.lock'
try { $lock = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
catch { throw 'Memoria ocupada por outro chat; aguarde e releia antes de repetir.' }
$pendingPath = Resolve-Local '.logistica/pending.json'
$noteNames = @('Visão geral.md','Registros.md','Decisões.md','Pendências.md')
$result = $null
try {
    if ((Test-Path -LiteralPath $pendingPath) -and $Command -ne 'Acknowledge') {
        throw 'Transacao interrompida. Leia .logistica/pending.json e confira as notas antes de Acknowledge; nao gere resumo como se a memoria estivesse consistente.'
    }
    switch ($Command) {
        'Snapshot' {
            $opsPath = Resolve-Local 'Operacoes'
            $operations = @()
            foreach ($dir in @(Get-ChildItem -LiteralPath $opsPath -Directory | Sort-Object Name)) {
                $notes = @()
                foreach ($name in $noteNames) {
                    $relative = 'Operacoes/' + $dir.Name + '/' + $name
                    $path = Resolve-Local $relative
                    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Nota ausente: $relative" }
                    $notes += [ordered]@{ path=$relative; sha256=(Hash $path) }
                }
                $operations += [ordered]@{ description=$dir.Name; notes=$notes }
            }
            $result = [ordered]@{ status='ok'; root=$rootPath; operations=$operations }
        }
        'Create' {
            if ([string]::IsNullOrWhiteSpace($Description)) { throw 'Informe a descricao confirmada pelo usuario.' }
            $name = ($Description -replace '[<>:"/\\|?*\x00-\x1f]', ' ' -replace '\s+', ' ').Trim().TrimEnd('.')
            if ($Prc) { $name += ' - ' + ($Prc -replace '[^\p{L}\p{N}-]', '') }
            if (-not $name -or $name -in @('.','..') -or $name -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)') { throw 'Descricao invalida para pasta Windows.' }
            $relative = 'Operacoes/' + $name
            $destination = Resolve-Local $relative
            if (($destination.Length + 50) -gt 245) { throw 'Caminho longo. Combine uma descricao mais curta com o usuario.' }
            if (Test-Path -LiteralPath $destination) { throw 'Processo ja existe; recupere a memoria existente.' }
            $templates = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets'
            $stage = Resolve-Local ('.logistica/create-' + [guid]::NewGuid().ToString('N'))
            [void][IO.Directory]::CreateDirectory($stage)
            try {
                foreach ($note in $noteNames) {
                    $text = [IO.File]::ReadAllText((Join-Path $templates $note), $utf8).Replace('{{DESCRICAO}}',$Description)
                    [IO.File]::WriteAllText((Join-Path $stage $note), $text, $utf8)
                }
                [void][IO.Directory]::CreateDirectory((Join-Path $stage 'Fontes'))
                [IO.Directory]::Move($stage, $destination)
            } finally {
                if (Test-Path -LiteralPath $stage) {
                    foreach ($file in @(Get-ChildItem -LiteralPath $stage -File)) { [IO.File]::Delete($file.FullName) }
                    $emptySources = Join-Path $stage 'Fontes'
                    if (Test-Path -LiteralPath $emptySources) { [IO.Directory]::Delete($emptySources) }
                    [IO.Directory]::Delete($stage)
                }
            }
            $result = [ordered]@{ status='created'; path=$relative; description=$Description }
        }
        'Commit' {
            if (-not $Manifest) { throw 'Informe o manifesto JSON.' }
            $batch = [IO.File]::ReadAllText((Get-Item -LiteralPath $Manifest).FullName, $utf8) | ConvertFrom-Json
            $writes = @($batch.writes)
            if ($writes.Count -eq 0 -or $null -eq $writes[0]) { throw 'Manifesto sem alteracoes.' }
            $seen = @{}
            $prepared = @()
            foreach ($write in $writes) {
                $relative = ([string]$write.path).Replace('\','/')
                if ($seen.ContainsKey($relative)) { throw 'Caminho repetido no lote.' }
                $seen[$relative] = $true
                $path = Resolve-Local $relative
                $parts = $relative.Split('/')
                $validNote = $parts.Count -eq 3 -and $parts[0] -eq 'Operacoes' -and $parts[2] -in $noteNames
                $validReport = $parts.Count -eq 2 -and $parts[0] -eq 'Resumos' -and $parts[1] -match '^[0-9][\p{L}\p{N}_.-]*\.md$'
                if (-not ($validNote -or $validReport)) { throw "Destino de memoria nao permitido: $relative" }
                if (-not (Test-Path -LiteralPath (Split-Path -Parent $path) -PathType Container)) { throw 'Pasta de destino ausente.' }
                if ([string]$write.expected -notmatch '^(missing|[a-f0-9]{64})$') { throw 'Hash esperado obrigatorio.' }
                if ((Hash $path) -ne [string]$write.expected) { throw "Conflito de hash: $relative. Releia e incorpore a versao atual." }
                if ($validReport -and $write.expected -ne 'missing') { throw 'Resumo existente: crie nova versao.' }
                if ($write.content -isnot [string] -or [string]::IsNullOrWhiteSpace($write.content)) { throw 'Conteudo textual obrigatorio.' }
                $prepared += [ordered]@{ path=$relative; before=[string]$write.expected; after=(Text-Hash $write.content); content=$write.content }
            }
            $changes = @($prepared | Where-Object { $_.before -ne $_.after })
            if ($changes.Count -eq 0) { $result = [ordered]@{ status='no_change'; files=@() }; break }
            $journal = [ordered]@{ id=[guid]::NewGuid().ToString('N'); started=[DateTimeOffset]::UtcNow.ToString('o'); files=@($changes | ForEach-Object { [ordered]@{ path=$_.path; before=$_.before; after=$_.after } }) }
            Write-Atomic $pendingPath ($journal | ConvertTo-Json -Depth 8)
            $written = @()
            foreach ($change in $changes) {
                $path = Resolve-Local $change.path
                if ((Hash $path) -ne $change.before) { throw "Conflito durante gravacao: $($change.path); transacao pendente de conferencia." }
                Write-Atomic $path $change.content
                if ((Hash $path) -ne $change.after) { throw 'Falha na verificacao apos escrita.' }
                [void][IO.File]::ReadAllText($path, $utf8)
                $written += [ordered]@{ path=$change.path; sha256=$change.after }
            }
            [IO.File]::Delete($pendingPath)
            $result = [ordered]@{ status='verified'; files=$written }
        }
        'Source' {
            if (-not $Operation -or -not $InputFile) { throw 'Informe -Operation (nome da pasta) e -InputFile.' }
            if ($Operation -match '[/\\]' -or $Operation -in @('.','..')) { throw 'Operation deve ser o nome de uma pasta.' }
            $sources = Resolve-Local ('Operacoes/' + $Operation + '/Fontes')
            if (-not (Test-Path -LiteralPath $sources -PathType Container)) { throw 'Processo nao cadastrado.' }
            $inputItem = Get-Item -LiteralPath $InputFile
            if ($inputItem.PSIsContainer) { throw 'Fonte deve ser arquivo.' }
            $sourceHash = Hash $inputItem.FullName
            $prefix = $sourceHash.Substring(0,12)
            foreach ($dir in @(Get-ChildItem -LiteralPath (Resolve-Local 'Operacoes') -Directory)) {
                $folder = Resolve-Local ('Operacoes/' + $dir.Name + '/Fontes')
                if (-not (Test-Path -LiteralPath $folder -PathType Container)) { continue }
                foreach ($existing in @(Get-ChildItem -LiteralPath $folder -File -Filter ($prefix + '-*'))) {
                    Assert-NoLink $existing.FullName
                    if ((Hash $existing.FullName) -eq $sourceHash) {
                        $result = [ordered]@{ status='reused'; path=('Operacoes/' + $dir.Name + '/Fontes/' + $existing.Name); sha256=$sourceHash }
                        break
                    }
                }
                if ($null -ne $result) { break }
            }
            if ($null -eq $result) {
                $safeName = ($inputItem.Name -replace '[<>:"/\\|?*\x00-\x1f]', '_')
                if ($safeName.Length -gt 50) { $safeName = $safeName.Substring(0,35) + $inputItem.Extension }
                $relative = 'Operacoes/' + $Operation + '/Fontes/' + $prefix + '-' + $safeName
                $path = Resolve-Local $relative
                if ($path.Length -gt 245) { throw 'Nome de fonte longo; use um nome mais curto.' }
                if (Test-Path -LiteralPath $path) { throw 'Colisao no nome da fonte; original preservado.' }
                [IO.File]::Copy($inputItem.FullName, $path, $false)
                if ((Hash $path) -ne $sourceHash) { throw 'Falha ao verificar a fonte copiada.' }
                $result = [ordered]@{ status='archived'; path=$relative; sha256=$sourceHash }
            }
        }
        'Acknowledge' {
            if (-not (Test-Path -LiteralPath $pendingPath)) { throw 'Nao ha transacao interrompida.' }
            if (-not $Manifest) { throw 'Informe manifesto de conferencia dos arquivos da transacao.' }
            $journal = [IO.File]::ReadAllText($pendingPath, $utf8) | ConvertFrom-Json
            $review = [IO.File]::ReadAllText((Get-Item -LiteralPath $Manifest).FullName, $utf8) | ConvertFrom-Json
            if (-not $review.reviewed -or -not ($review.reviewed -is [string])) { throw 'Informe reviewed com a sintese da conferencia e o que falta reconciliar.' }
            $checks = @($review.files)
            if ($checks.Count -ne @($journal.files).Count) { throw 'Confira todos os arquivos da transacao.' }
            foreach ($file in $journal.files) {
                $match = @($checks | Where-Object { $_.path -ceq $file.path })
                if ($match.Count -ne 1 -or $match[0].sha256 -ne (Hash (Resolve-Local $file.path))) { throw 'Conferencia ausente ou hash divergente.' }
            }
            [IO.File]::Delete($pendingPath)
            $result = [ordered]@{ status='acknowledged'; next='Reconciliar as notas pendentes por novo Commit antes de resumir.' }
        }
    }
    $result | ConvertTo-Json -Depth 10
} finally { $lock.Dispose() }
