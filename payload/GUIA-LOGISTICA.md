# Instalação, cadastro e chats

## Instalação

O pacote instala instruções e auxiliares somente na pasta escolhida. Execute o `Install.ps1` da cópia baixada com `-TargetRoot` apontando para a raiz existente do projeto. Ele cria `Operacoes/`, `Resumos/` e `.logistica/`, sem cadastrar processos. O manifesto limita os arquivos instalados. A reinstalação confere hashes e preserva instruções modificadas; resolva os conflitos com o usuário antes de substituir qualquer arquivo.

Leia o AGENTS.md e a skill instalados na própria sessão após instalar. Se o catálogo ainda não listar a skill, a leitura explícita permite aplicar o procedimento; uma nova conversa pode ser necessária para atualizar o catálogo. Não altere a configuração global do Codex.

## Cadastro guiado

Trate **um processo por vez**. Pergunte descrição e tipo (importação, exportação ou reimportação), situação atual, próximos marcos, pendências e materiais que o usuário tiver. Aceite lacunas. Pergunte PRC se houver nomes semelhantes; não invente código ou identidade. Antes de criar, enumere as pastas reais para evitar duplicação. Processo relacionado mantém pasta própria e vínculo.

Use o comando `Create` do auxiliar somente após o usuário identificar o processo que deseja cadastrar. Nome da pasta segue a descrição; caracteres inválidos para Windows são trocados por espaços. Confira e informe o nome real retornado. Se o caminho precisar ser encurtado, combine a descrição curta com o usuário antes de criar. Não renomeie automaticamente processo existente.

O comando cria as quatro notas com lacunas explícitas. Complete-as com os dados fornecidos usando o fluxo da memory-sync. Depois pergunte se deseja um chat próprio para o processo e se quer cadastrar outro. O pacote não traz lista de processos reais.

## Chat de processo

Se o usuário pedir a criação do chat, descubra a ferramenta disponível, consulte os projetos e selecione o projeto existente correspondente à raiz atual. Crie em ambiente local na mesma raiz; não crie worktree. Só confirme a criação depois de receber a identificação real do novo chat. Registre ID/link quando disponível em Visão geral. Sem ferramenta, entregue:

Título: `LOG · <descrição do processo>`

Mensagem inicial: “Este chat acompanha o processo <descrição>, pasta <caminho relativo>. Leia o AGENTS.md da raiz e aplique .agents/skills/memory-sync/SKILL.md. Recupere a visão geral e as pendências antes de responder. Toda atualização clara deve ser registrada e verificada nos arquivos compartilhados. A pasta existente é a memória; não crie outro processo.”

## Chat mestre

O usuário pode usar a conversa de instalação como mestre ou pedir outro chat. Título sugerido: `LOG · Acompanhamento e resumos`.

Mensagem inicial: “Este é o chat mestre de logística deste projeto. Leia o AGENTS.md e a memory-sync local. Para cada fechamento, enumere os processos reais e consulte suas memórias persistentes, inclusive as atualizações feitas em outros chats. Gere fechamento operacional e texto executivo conforme references/resumos.md. Registre primeiro qualquer atualização operacional recebida aqui e só depois sintetize. Não dependa do histórico das outras conversas.”

## Atualização e recuperação

Mantenha uma nova cópia do pacote separada dos dados e execute novamente o instalador. Preserve `Operacoes/`, `Resumos/`, fontes e estado local. Em conflito de hash de uma nota, releia a versão atual e incorpore a mudança antes de tentar novamente; não force a versão antiga.

O auxiliar serializa acessos cooperantes no mesmo computador. Edições externas e sincronização OneDrive não usam esse lock; hashes ajudam a detectar conflitos, mas não garantem coordenação entre máquinas. Se houver interrupção no meio de um commit, o comando Snapshot bloqueia uma síntese como se tudo estivesse consistente. Consulte references/persistencia.md para conferência e recuperação explícita.
