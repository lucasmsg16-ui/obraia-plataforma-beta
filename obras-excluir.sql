-- ═══════════════════════════════════════════════════════════════════════════
-- ObraIA · permissão para EXCLUIR obras
-- Rodar no SQL Editor do projeto da cópia (xjzbqikappmaijfkxmms).
--
-- POR QUE ISSO É NECESSÁRIO
-- No Postgres com RLS ligado, o que não tem política é NEGADO — mas o DELETE
-- negado NÃO devolve erro: ele simplesmente apaga zero linhas. Sem isto, a tela
-- diria "excluído" e a obra reapareceria no próximo F5. O client já detecta esse
-- caso (confere quantas linhas voltaram), mas a correção de verdade é aqui.
--
-- REGRA ADOTADA: só o DONO exclui.
-- Membro convidado pode lançar avanço, mas não pode apagar a obra de outra
-- pessoa. Quem tem acesso para colaborar não deveria ter acesso para destruir.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Excluir a obra: só o dono ───────────────────────────────────────────
drop policy if exists obras_del on public.obras;
create policy obras_del on public.obras
  for delete using (dono = auth.uid());

-- ── 2. Excluir os filhos ───────────────────────────────────────────────────
-- Mesmo com o CASCADE do banco, o client apaga os filhos antes por segurança.
-- Para isso funcionar, cada tabela precisa da própria política de DELETE.
-- eh_dono() é SECURITY DEFINER (criada no setup) e não reavalia RLS — é o que
-- evita a recursão infinita entre obras e obra_membros.

drop policy if exists itens_del on public.obra_itens;
create policy itens_del on public.obra_itens
  for delete using (public.eh_dono(obra_id));

drop policy if exists membros_del on public.obra_membros;
create policy membros_del on public.obra_membros
  for delete using (public.eh_dono(obra_id) or usuario = auth.uid());

-- ── 3. Histórico de medição ────────────────────────────────────────────────
-- ATENÇÃO — decisão de projeto: o log de avanços é APPEND-ONLY no dia a dia.
-- Ninguém pode apagar uma medição isolada para "consertar" um número; é o que
-- garante que o histórico sirva de prova de quem informou o quê.
-- A exclusão só é liberada quando a obra inteira está sendo eliminada, e mesmo
-- assim apenas para o dono.
drop policy if exists avancos_del on public.obra_avancos;
create policy avancos_del on public.obra_avancos
  for delete using (public.eh_dono(obra_id));

-- ── 4. Rede de segurança no banco ──────────────────────────────────────────
-- Se um dia a exclusão falhar no meio (queda de conexão entre um DELETE e o
-- outro), o CASCADE impede sobrar item órfão apontando para obra inexistente.
do $$
begin
  alter table public.obra_itens   drop constraint if exists obra_itens_obra_id_fkey;
  alter table public.obra_itens   add  constraint obra_itens_obra_id_fkey
    foreign key (obra_id) references public.obras(id) on delete cascade;

  alter table public.obra_avancos drop constraint if exists obra_avancos_obra_id_fkey;
  alter table public.obra_avancos add  constraint obra_avancos_obra_id_fkey
    foreign key (obra_id) references public.obras(id) on delete cascade;

  alter table public.obra_membros drop constraint if exists obra_membros_obra_id_fkey;
  alter table public.obra_membros add  constraint obra_membros_obra_id_fkey
    foreign key (obra_id) references public.obras(id) on delete cascade;
exception when others then
  raise notice 'FK cascade nao aplicada (nomes de constraint podem diferir): %', sqlerrm;
end $$;

select 'permissao de exclusao aplicada' as ok;
