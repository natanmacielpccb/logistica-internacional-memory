[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('logistica-tests-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$script:passed = 0
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Check([string]$Name, [scriptblock]$Body) { & $Body; $script:passed++; Write-Output ('PASS ' + $Name) }
function Reject([scriptblock]$Body) {
    $rejected = $false
    try { $null = & $Body } catch { $rejected = $true }
    Assert $rejected 'Esperava rejeicao.'
}
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Save-Json($Object, [string]$Name='batch.json') {
    $path = Join-Path $testRoot $Name
    [IO.File]::WriteAllText($path, ($Object | ConvertTo-Json -Depth 10), $utf8)
    return $path
}
function Call-Memory([string]$Action, [hashtable]$Arguments=@{}) {
    (& $script:helper -Command $Action -Root $script:project @Arguments) | ConvertFrom-Json
}
$script:project = Join-Path $testRoot 'projeto'
[void][IO.Directory]::CreateDirectory($script:project)
$script:helper = Join-Path $script:project '.agents/skills/memory-sync/scripts/Memory.ps1'
Check 'skill valida e referencias locais acessiveis' {
    $skillRoot = Join-Path $packageRoot 'payload/.agents/skills/memory-sync'
    $skillText = [IO.File]::ReadAllText((Join-Path $skillRoot 'SKILL.md'))
    Assert ($skillText -match '(?s)^---\r?\nname: memory-sync\r?\ndescription: ([^\r\n]+)\r?\n---') 'Frontmatter invalido.'
    Assert ($Matches[1].Length -le 1024 -and $Matches[1] -notmatch '[<>]') 'Descricao invalida.'
    Assert ($skillText -notmatch '\[TODO:') 'Scaffold incompleto.'
    foreach ($match in [regex]::Matches($skillText, '\[[^\]]+\]\(([^)]+)\)')) {
        Assert (Test-Path -LiteralPath (Join-Path $skillRoot $match.Groups[1].Value) -PathType Leaf) 'Referencia da skill ausente.'
    }
}
Check 'instalacao sem processos e integridade do payload' {
    $result = (& (Join-Path $packageRoot 'Install.ps1') -TargetRoot $script:project) | ConvertFrom-Json
    Assert ($result.status -eq 'installed') 'Nao instalou.'
    Assert (@((Call-Memory 'Snapshot').operations).Count -eq 0) 'Criou operacao automaticamente.'
}
Check 'cadastro explicito, quatro notas e rejeicao de duplicata' {
    $null = Call-Memory 'Create' @{ Description='Importação teste carros' }
    $null = Call-Memory 'Create' @{ Description='Exportação teste Hs' }
    Assert (@((Call-Memory 'Snapshot').operations).Count -eq 2) 'Faltam operacoes.'
    Assert (@((Call-Memory 'Snapshot').operations[0].notes).Count -eq 4) 'Faltam notas.'
    Reject { Call-Memory 'Create' @{ Description='Importação teste carros' } }
}
$script:relative = 'Operacoes/Importação teste carros/Registros.md'
$script:notePath = Join-Path $script:project $script:relative
Check 'gravacao e recuperacao por novo processo PowerShell' {
    $manifest = Save-Json @{ writes=@(@{ path=$script:relative; expected=(Sha $script:notePath); content="# Registros`n`nR-001: Booking confirmado. Entrada no terminal pendente.`n" }) }
    $result = Call-Memory 'Commit' @{ Manifest=$manifest }
    Assert ($result.status -eq 'verified') 'Nao verificou.'
    $shell = (Get-Process -Id $PID).Path
    $snapshotText = & $shell -NoProfile -File $script:helper -Command Snapshot -Root $script:project
    Assert ($LASTEXITCODE -eq 0) 'Outro processo nao leu a memoria.'
    $snapshot = ($snapshotText -join "`n") | ConvertFrom-Json
    $car = @($snapshot.operations | Where-Object { $_.description -eq 'Importação teste carros' })[0]
    $record = @($car.notes | Where-Object { $_.path -eq $script:relative })[0]
    Assert ($record.sha256 -eq (Sha $script:notePath)) 'Hash divergiu entre sessoes.'
    Assert ([IO.File]::ReadAllText($script:notePath).Contains('Entrada no terminal pendente')) 'Conteudo perdido.'
}
Check 'conteudo repetido nao regrava e versao antiga nao sobrescreve' {
    $oldHash = Sha $script:notePath
    $manifest = Save-Json @{ writes=@(@{ path=$script:relative; expected=$oldHash; content=[IO.File]::ReadAllText($script:notePath) }) }
    Assert ((Call-Memory 'Commit' @{ Manifest=$manifest }).status -eq 'no_change') 'Regravou igual.'
    $manifest = Save-Json @{ writes=@(@{ path=$script:relative; expected=$oldHash; content="# Registros`nR-001: Complemento confirmado.`n" }) }
    $null = Call-Memory 'Commit' @{ Manifest=$manifest }
    Reject { Call-Memory 'Commit' @{ Manifest=$manifest } }
    Assert ([IO.File]::ReadAllText($script:notePath).Contains('Complemento confirmado')) 'Perdeu versao atual.'
}
Check 'conflito no lote nao grava a primeira nota' {
    $before = Sha $script:notePath
    $other = 'Operacoes/Exportação teste Hs/Pendências.md'
    $manifest = Save-Json @{ writes=@(@{ path=$script:relative; expected=$before; content='# Nao deve entrar' }, @{ path=$other; expected=('0' * 64); content='# Conflito' }) }
    Reject { Call-Memory 'Commit' @{ Manifest=$manifest } }
    Assert ((Sha $script:notePath) -eq $before) 'Gravou parcialmente apesar do preflight.'
}
Check 'fontes identicas sao reutilizadas entre processos' {
    $sourceFile = Join-Path $testRoot 'ligacao.txt'
    [IO.File]::WriteAllText($sourceFile, 'Texto sintetico de uma ligacao sobre dois processos.', $utf8)
    $a = Call-Memory 'Source' @{ Operation='Importação teste carros'; InputFile=$sourceFile }
    $b = Call-Memory 'Source' @{ Operation='Exportação teste Hs'; InputFile=$sourceFile }
    Assert ($a.status -eq 'archived' -and $b.status -eq 'reused' -and $a.path -eq $b.path) 'Duplicou fonte.'
    Assert ($a.sha256 -eq (Sha $sourceFile)) 'Fonte alterada.'
}
Check 'resumo versionado sem sobrescrever o anterior' {
    $manifest = Save-Json @{ writes=@(@{ path='Resumos/2026-01-01_fechamento_v01.md'; expected='missing'; content='# Fechamento sintetico' }) }
    $null = Call-Memory 'Commit' @{ Manifest=$manifest }
    Reject { Call-Memory 'Commit' @{ Manifest=$manifest } }
}
Check 'traversal e alteracao de instrucoes pelo helper sao rejeitados' {
    foreach ($path in @('../fora.md','Operacoes/../fora.md','AGENTS.md','.agents/skills/memory-sync/SKILL.md')) {
        $manifest = Save-Json @{ writes=@(@{ path=$path; expected='missing'; content='# Indevido' }) }
        Reject { Call-Memory 'Commit' @{ Manifest=$manifest } }
    }
}
Check 'lock exclusivo impede gravacoes concorrentes' {
    $stream = [IO.File]::Open((Join-Path $script:project '.logistica/memory.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try { Reject { Call-Memory 'Snapshot' } } finally { $stream.Dispose() }
}
Check 'interrupcao bloqueia leitura e exige conferencia completa' {
    $journal = Join-Path $script:project '.logistica/pending.json'
    [IO.File]::WriteAllText($journal, (@{ files=@(@{path=$script:relative;before='missing';after=(Sha $script:notePath)}) } | ConvertTo-Json -Depth 5), $utf8)
    Reject { Call-Memory 'Snapshot' }
    $bad = Save-Json @{ reviewed='Conferencia sintetica';files=@() }
    Reject { Call-Memory 'Acknowledge' @{ Manifest=$bad } }
    $good = Save-Json @{ reviewed='Nota sintetica conferida; nenhuma reconciliacao restante.';files=@(@{path=$script:relative;sha256=(Sha $script:notePath)}) }
    Assert ((Call-Memory 'Acknowledge' @{ Manifest=$good }).status -eq 'acknowledged') 'Nao liberou apos conferencia.'
    Assert ((Call-Memory 'Snapshot').status -eq 'ok') 'Continuou bloqueado.'
}
Check 'reinstalacao preserva notas e bloqueia instrucoes modificadas' {
    $before = Sha $script:notePath
    $null = & (Join-Path $packageRoot 'Install.ps1') -TargetRoot $script:project
    Assert ((Sha $script:notePath) -eq $before) 'Reinstalacao alterou memoria.'
    $agents = Join-Path $script:project 'AGENTS.md'
    [IO.File]::AppendAllText($agents, "`nRegra local do usuario.`n", $utf8)
    $agentsHash = Sha $agents
    Reject { & (Join-Path $packageRoot 'Install.ps1') -TargetRoot $script:project }
    Assert ((Sha $agents) -eq $agentsHash) 'Apagou regra local.'
}
Check 'pasta existente com instrucoes alheias fica intocada' {
    $existing = Join-Path $testRoot 'existente'
    [void][IO.Directory]::CreateDirectory($existing)
    $agents = Join-Path $existing 'AGENTS.md'
    [IO.File]::WriteAllText($agents, '# Regras preexistentes', $utf8)
    $before = Sha $agents
    Reject { & (Join-Path $packageRoot 'Install.ps1') -TargetRoot $existing }
    Assert ((Sha $agents) -eq $before) 'Sobrescreveu instrucoes preexistentes.'
    Assert (-not (Test-Path -LiteralPath (Join-Path $existing '.logistica'))) 'Criou estado apesar do conflito.'
}
Check 'nomes Windows invalidos e caminhos longos exigem correcao' {
    Reject { Call-Memory 'Create' @{ Description='CON' } }
    Reject { Call-Memory 'Create' @{ Description=('Descricao muito longa ' * 20) } }
    $created = Call-Memory 'Create' @{ Description='Teste: sanear / nome?' }
    Assert ($created.path -eq 'Operacoes/Teste sanear nome') 'Nome inesperado.'
}
Check 'arquivo ausente causa cobertura parcial em vez de ignorar processo' {
    $missingPath = Join-Path $script:project 'Operacoes/Teste sanear nome/Pendências.md'
    $bytes = [IO.File]::ReadAllBytes($missingPath)
    [IO.File]::Delete($missingPath)
    try { Reject { Call-Memory 'Snapshot' } } finally { [IO.File]::WriteAllBytes($missingPath, $bytes) }
}
Write-Output ("RESULT: $script:passed checks passed. Artefatos sinteticos: $testRoot")
