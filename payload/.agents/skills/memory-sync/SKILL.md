---
name: memory-sync
description: Registrar e recuperar memória persistente dos processos logísticos deste projeto, atualizar decisões e pendências a partir do chat e consolidar resumos entre processos. Use também em retomadas e fechamentos.
---

# Memory-sync logística

## Fluxo obrigatório

**Identificar → Recuperar → Interpretar → Persistir → Verificar → Confirmar.** A memória vive nos arquivos da raiz do projeto. Uma informação que ficou apenas na resposta do chat ainda não foi registrada.

1. Identifique o processo pela descrição e pelo vínculo do chat, conferindo as pastas em `Operacoes/`. Use PRC quando distinguir nomes semelhantes. Em caso de ambiguidade, pergunte; para cadastro, consulte `GUIA-LOGISTICA.md`.
2. Leia `Visão geral.md` e `Pendências.md` do processo. Leia `Decisões.md` quando decisões forem pertinentes; busque trechos em `Registros.md` e fontes apenas para lacunas, conflitos e reconstruções temporais. Expanda a recuperação até sustentar o pedido; não carregue todos os anexos por padrão.
3. Interprete cada entrada conforme [references/registro.md](references/registro.md). Preserve a fonte, a data do fato e a data do registro; diferencie relato, proposta, decisão, confirmação e execução. Extraia mudanças de estado, decisões e ações sem inventar responsável ou prazo.
4. Arquive anexos e transcrições fornecidos e atualize as notas pertinentes. Uma entrada pode afetar vários processos: distribua trechos identificados, referencie a mesma fonte e pergunte sobre trechos ambíguos. Conflitos relevantes ficam explícitos, sem eleger silenciosamente uma versão.
5. Use `scripts/Memory.ps1` conforme [references/persistencia.md](references/persistencia.md): obtenha hashes antes de editar, envie as mudanças relacionadas juntas e releia todos os arquivos escritos. Reutilize identificadores de eventos, decisões e tarefas já existentes. Confira equivalência na memória para não repetir uma entrada.
6. Confirme brevemente o que foi salvo, quais pendências mudaram e quais dúvidas restam. Em falha, informe exatamente o que ficou pendente de gravação. Nunca declare sucesso só porque produziu texto no chat.

Tarefa somente leitura não grava notas, fontes ou resumos. Informação clara pode ser registrada automaticamente; ambiguidades de processo, conflitos relevantes ou decisões sem confirmação exigem esclarecimento. Registre a parte inequívoca sem dar como resolvida a parte incerta.

## Notas por processo

- **Visão geral:** identificação, estado atual, última atualização, marcos, vínculos com outros processos e chat de referência. Atualize junto das notas afetadas.
- **Registros:** acontecimentos cronológicos com IDs locais estáveis `R-001`, fonte e origem. Correções ficam atribuídas e preservam o histórico anterior.
- **Decisões:** `D-001`, conteúdo, autor quando conhecido, data, fonte e estado vigente/substituída. Relacione a nova decisão à anterior. Sugestões do agente permanecem propostas.
- **Pendências:** `P-001`, ação, responsável ou “a definir”, prazo/fuso ou “não informado”, estado, dependências, criticidade justificada, última atualização e fonte. Preserve concluídas e evidência de conclusão; cancelar é diferente de concluir.

Confirmar booking não confirma entrada no terminal ou embarque. Solicitar pagamento não comprova crédito. Notícia antiga recebida depois não reabre automaticamente tarefa concluída por evidência posterior.

## Fechamentos e retomada entre chats

Para gerar fechamento diário, mensal ou de período solicitado, leia [references/resumos.md](references/resumos.md). Comece pelos arquivos de todos os processos cadastrados; histórico e fontes entram quando necessários ao período. Consulte concluídos quando houver atividade no período ou dependência relevante. O chat mestre não depende de histórico de outros chats.

Não configure agendamento nem envio externo por consequência de um pedido de resumo. O usuário revisa e copia o texto executivo.
