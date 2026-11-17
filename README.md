# Memória logística no Codex

Memória persistente para acompanhar processos de importação, exportação e reimportação pelo chat. Inclui uma **memory-sync própria**, notas locais compartilhadas entre chats e fechamento operacional com texto executivo.

## Instalar no projeto existente

Abra uma conversa no projeto de logística do Codex e cole o texto de [INSTALAR-NO-CODEX.md](INSTALAR-NO-CODEX.md). A instalação confirma a pasta, preserva arquivos existentes e pergunta por **um processo de cada vez**. Nenhuma operação de exemplo é cadastrada.

O Codex precisa conseguir ler e escrever a pasta do projeto e executar PowerShell 5.1 ou superior. Git facilita baixar o pacote; baixar o ZIP do GitHub também funciona. A criação automática de chats depende das ferramentas disponíveis no Codex; há alternativa manual.

## Usar

- No chat de um processo, envie texto, transcrição, print ou arquivo: “Registre esta atualização”. A memory-sync recupera o contexto, atualiza as notas e verifica os arquivos antes de confirmar.
- Peça “Cadastre um novo processo” e informe sua descrição. O PRC só é necessário para distinguir processos parecidos.
- No chat mestre, peça “Faça o fechamento de hoje com as prioridades de amanhã e um texto para a diretoria” ou “Resuma o mês de novembro”.
- Para continuar em outro chat, diga qual é o processo. A memória está **nos arquivos do projeto**, não depende do histórico da conversa anterior.

## O que fica no computador

```text
AGENTS.md
.agents/skills/memory-sync/     # instruções e auxiliar de persistência
GUIA-LOGISTICA.md
Operacoes/
  Descrição do processo/
    Visão geral.md
    Registros.md
    Decisões.md
    Pendências.md
    Fontes/
Resumos/                       # fechamentos datados e versionados
.logistica/                    # estado de instalação e bloqueio de escrita
```

O repositório contém somente o pacote. Processos, fontes, resumos e estado local não devem ser publicados. A memória local depende da preservação dessa pasta; o pacote não configura backup nem garante sincronização do OneDrive. Chats devem usar a mesma pasta local, não worktrees ou cópias separadas.

## Atualizar e verificar

Baixe a nova versão em pasta separada e peça ao Codex para executar `Install.ps1 -TargetRoot <pasta do projeto>`. Arquivos operacionais são preservados. Se uma instrução instalada tiver sido editada, o instalador interrompe antes de sobrescrevê-la e mostra o conflito.

Para validar o pacote: `powershell -NoProfile -File tests/Run-Tests.ps1`. Para o teste de comportamento entre chats, siga [tests/ACEITE.md](tests/ACEITE.md). Os testes técnicos verificam arquivos e concorrência; a validação semântica entre chats exige uma sessão real do Codex.

Versão: 1.0.0. Sem agendamento ou envio automático de relatórios.
