# Gravar e verificar

Auxiliar: `.agents/skills/memory-sync/scripts/Memory.ps1`. Execute com PowerShell 5.1 ou superior. Use `-Root` como caminho real da raiz compartilhada. Os exemplos são sintéticos e não cadastram processos sem pedido do usuário.

```powershell
$helper = Join-Path $raiz '.agents/skills/memory-sync/scripts/Memory.ps1'
& $helper -Command Snapshot -Root $raiz
& $helper -Command Create -Root $raiz -Description 'Descrição informada'
& $helper -Command Source -Root $raiz -Operation 'Nome real da pasta' -InputFile $anexo
& $helper -Command Commit -Root $raiz -Manifest $manifesto
```

Snapshot enumera todos os processos e hashes das quatro notas, sem carregar conteúdo. Leia os arquivos pertinentes separadamente. Create gera as quatro notas sem fatos fictícios. Source copia o original, verifica SHA-256 e reutiliza arquivo idêntico já presente em qualquer processo. Referencie o caminho retornado com links relativos nas notas envolvidas.

## Commit

Crie o manifesto temporário em UTF-8 fora das pastas de fontes; use serialização JSON do PowerShell para preservar acentos, aspas e quebras reais. O conteúdo é a versão completa da nota, preservando informação alheia. O manifesto pode conter várias notas/processos relacionados:

```json
{
  "writes": [
    {
      "path": "Operacoes/Descrição informada/Registros.md",
      "expected": "SHA256_OBTIDO_ANTES_DA_EDICAO",
      "content": "Conteúdo completo da nota com a atualização"
    },
    {
      "path": "Resumos/2026-01-01_fechamento_v01.md",
      "expected": "missing",
      "content": "Conteúdo completo do novo relatório"
    }
  ]
}
```

Substitua o hash ilustrativo pelo SHA-256 real de 64 dígitos. `missing` só se o arquivo ainda não existir. Reutilize IDs semânticos estáveis; o auxiliar detecta conteúdo idêntico e conflito de versão, mas o agente é responsável por reconhecer eventos equivalentes.

O auxiliar valida todo o lote antes de gravar, serializa acessos cooperantes e substitui cada arquivo atomicamente. A atomicidade é **por arquivo**, não do lote completo. Conflito de hash interrompe sem forçar a versão antiga; releia os arquivos e reconcilie. Resultados `verified` trazem caminhos e hashes efetivamente conferidos; releia o conteúdo para validar o sentido. Resumos existentes exigem nova versão.

## Interrupção e falha

Uma interrupção pode deixar `.logistica/pending.json`, com os caminhos e hashes anteriores/propostos. Os próximos comandos bloqueiam para evitar resumo de um lote incompleto. Leia o journal e cada arquivo listado, confira quais mudanças entraram e quais faltam. Preserve dados alheios. Gere manifesto de conferência:

```json
{
  "reviewed": "Síntese real da conferência e alterações que ainda serão reconciliadas",
  "files": [{"path": "caminho listado no journal", "sha256": "HASH_ATUAL_OU_missing"}]
}
```

Inclua todos os arquivos, com os hashes reais. Execute `-Command Acknowledge -Manifest <conferência>`, faça novo Snapshot e Commit reconciliado. Acknowledge apenas libera a trava de recuperação após conferência; não conclui a atualização e não prova correção semântica. Só retome os resumos depois de reconciliar e verificar as notas. Relate falha e cobertura parcial enquanto isso.

O lock não coordena outros editores ou computadores. Não altere políticas globais de execução. Se o ambiente bloquear scripts, apresente o erro e use edição autorizada com releitura e hashes, sem alegar proteção do auxiliar. Remova o manifesto temporário depois de sucesso para não deixar cópias desnecessárias de dados.
