-- ═══════════════════════════════════════════════════════════════════════════
-- ObraIA · permissões de exclusão de obra — ESTADO VERIFICADO EM 06/08/2026
--
-- NÃO É PRECISO RODAR NADA. Este arquivo é a conferência do que já existe no
-- banco da cópia (xjzbqikappmaijfkxmms), guardada porque a exclusão de obra
-- depende dela e ninguém deveria descobrir isso de novo do zero.
--
-- O QUE FOI ENCONTRADO
--   obras         · obra_del  (DELETE) → dono = auth.uid()          ✔ correto
--   obra_itens    · item_all  (ALL)    → pode_editar_obra(obra_id)   ⚠ ver abaixo
--   obra_membros  · memb_del  (DELETE) → eh_dono(obra_id)            ✔ correto
--   obra_avancos  ·            só INSERT e SELECT                    ✔ de propósito
--
--   FKs (todas com ON DELETE CASCADE):
--     obra_itens.obra_id    → obras
--     obra_avancos.obra_id  → obras
--     obra_avancos.item_id  → obra_itens
--     obra_membros.obra_id  → obras
--
-- ⚠ A ARMADILHA QUE ISSO ESCONDE
-- obra_itens libera para QUEM PODE EDITAR — o que inclui membro convidado —
-- enquanto obras exige ser o DONO. Um cliente que apagasse "os filhos primeiro,
-- depois a obra" deixaria um membro limpar todos os serviços de uma obra alheia
-- e só então ser barrado: a obra do dono ficaria destruída pela metade, sem
-- volta. Por isso obras.html faz UM ÚNICO delete, na tabela obras: a permissão
-- é avaliada uma vez, no lugar certo, e o CASCADE limpa o resto.
--
-- ⚠ obra_avancos NÃO TEM DELETE — E DEVE CONTINUAR ASSIM
-- É o que torna a medição uma prova: ninguém apaga um lançamento isolado para
-- "consertar" um número. Quando a obra inteira é excluída, o CASCADE remove os
-- avanços junto, sem precisar de permissão de DELETE no cliente.
-- ═══════════════════════════════════════════════════════════════════════════

-- Para reconferir tudo isto a qualquer momento, rode só o SELECT abaixo:

select 'POLITICA '||cmd||': '||tablename||' · '||policyname||' · '||coalesce(qual,'(sem condicao)') as estado
  from pg_policies
 where schemaname='public'
   and tablename in ('obras','obra_itens','obra_avancos','obra_membros')
union all
select 'FK: '||tc.table_name||'.'||kcu.column_name||' -> '||ccu.table_name
       ||' · ON DELETE '||rc.delete_rule
  from information_schema.table_constraints tc
  join information_schema.key_column_usage       kcu on kcu.constraint_name = tc.constraint_name
  join information_schema.constraint_column_usage ccu on ccu.constraint_name = tc.constraint_name
  join information_schema.referential_constraints rc  on rc.constraint_name  = tc.constraint_name
 where tc.constraint_type = 'FOREIGN KEY'
   and tc.table_schema = 'public'
   and tc.table_name in ('obra_itens','obra_avancos','obra_membros')
 order by 1;

-- ───────────────────────────────────────────────────────────────────────────
-- SE ALGUM DIA O CASCADE SUMIR (a exclusão passaria a falhar por violação de
-- chave estrangeira), este é o conserto — só rodar se o SELECT acima mostrar
-- algo diferente de "ON DELETE CASCADE":
--
--   alter table public.obra_itens   drop constraint obra_itens_obra_id_fkey;
--   alter table public.obra_itens   add  constraint obra_itens_obra_id_fkey
--     foreign key (obra_id) references public.obras(id) on delete cascade;
--   (idem para obra_avancos.obra_id e obra_membros.obra_id)
-- ───────────────────────────────────────────────────────────────────────────
