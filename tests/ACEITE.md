# Aceite em dois chats do projeto instalado

Execute com processos sintéticos descartáveis, separados dos processos reais. Os testes abaixo avaliam comportamento do agente, além dos testes técnicos de Run-Tests.ps1. Não cadastre dados reais sem o usuário informá-los.

1. **Instalação:** numa pasta de teste existente, instale e confirme que Operacoes está vazia. Reinstale após criar notas de teste; os arquivos operacionais devem manter seus hashes. Modifique uma instrução instalada e confirme que a atualização bloqueia sem sobrescrevê-la.
2. **Chat A:** peça cadastrar “Importação teste de carros”. Informe que o booking foi confirmado, mas a entrada no terminal não; forneça texto como fonte. Confira o registro persistido e pendências distintas.
3. **Chat B:** abra outro chat no mesmo projeto/local. Sem colar o histórico do chat A, peça o estado e fechamento. Deve recuperar o booking dos arquivos e manter entrada no terminal/embarque pendentes. Confira as referências e o resumo salvo.
4. **Reenvio:** reenvie a mesma fonte no chat A. O mesmo acontecimento e suas tarefas não devem se duplicar. Novo conteúdo deve virar complemento vinculado.
5. **Decisão substituída:** informe uma decisão de rota e depois sua substituição confirmada. Histórico deve preservar ambas e resumo deve usar a vigente.
6. **Conclusão:** confirme explicitamente que uma tarefa foi executada. Deve passar a concluída com origem e data. Uma atualização antiga recebida depois não deve reabri-la.
7. **Conflito:** forneça duas ETAs incompatíveis, sem definição de qual se aplica. Deve preservar as duas, criar esclarecimento e não anunciar chegada confirmada.
8. **Vários processos:** cadastre “Exportação teste de estruturas”. Envie uma ligação sobre estruturas e carros. Deve atualizar os destinos claros, arquivar uma só fonte e vincular o risco cruzado. Trecho de destino incerto exige pergunta.
9. **Cobertura:** peça resumo mensal e diário, incluindo processo sem atualização recente. Deve indicar período, corte, última atualização, pendências carregadas e falta de confirmação, sem inventar avanços.
10. **Falha:** simule conflito de hash e interrupção com journal. Não pode confirmar memória salva integralmente ou gerar resumo como consistente antes da reconciliação.

Registre o que foi realmente testado. Teste técnico aprovado não significa aceite semântico aprovado nem instalação no PC de destino concluída.
