-- ========== VILLE FOLLE 3D : sauvegarde en ligne anti-écrasement ==========
-- A lancer APRES supabase5.sql. Peut etre relance sans danger.
-- 1) chaque sauvegarde a un numero de version : un appareil ne peut remplacer la sauvegarde
--    en ligne que s'il est parti de la DERNIERE version (sinon : conflit, le jeu choisit la meilleure).
-- 2) historique : une copie toutes les 15 min (60 copies gardees par joueur) pour pouvoir tout restaurer.
-- 3) les vieilles versions du jeu (encore ouvertes sur un appareil) ne peuvent plus rien ecraser.

alter table public.vf_saves add column if not exists ver bigint not null default 0;

create table if not exists public.vf_history (
  id bigserial primary key,
  player_id bigint not null references public.players(id) on delete cascade,
  data text not null,
  ver bigint not null default 0,
  saved_at timestamptz not null default now()
);
create index if not exists vf_history_player on public.vf_history(player_id, id desc);
alter table public.vf_history enable row level security;
revoke all on public.vf_history from anon, authenticated;

create or replace function public.vf_keep(v bigint, d text, ver bigint)
returns void language plpgsql security definer set search_path = public as $$
begin
  if d is null or d = '' then return; end if;
  if not exists (select 1 from public.vf_history where player_id = v and saved_at > now() - interval '15 minutes') then
    insert into public.vf_history(player_id, data, ver) values (v, d, ver);
    delete from public.vf_history where player_id = v and id not in
      (select id from public.vf_history where player_id = v order by id desc limit 60);
  end if;
end $$;
revoke all on function public.vf_keep(bigint, text, bigint) from public, anon, authenticated;

-- ancienne fonction : refusee des que le nouveau systeme a servi une fois
create or replace function public.vf_save(p_pseudo text, p_pin text, p_data text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare v bigint; r public.vf_saves%rowtype;
begin
  v := public.gp_check(p_pseudo, p_pin);
  if v is null or v = -1 then return jsonb_build_object('ok', false, 'err', 'bad'); end if;
  select * into r from public.vf_saves where player_id = v;
  if found and r.ver <> 0 then return jsonb_build_object('ok', false, 'err', 'old'); end if;
  if length(coalesce(p_data, '')) > 200000 then return jsonb_build_object('ok', false, 'err', 'toobig'); end if;
  if found then perform public.vf_keep(v, r.data, r.ver); end if;
  insert into public.vf_saves(player_id, data, updated_at) values (v, coalesce(p_data, ''), now())
  on conflict (player_id) do update set data = excluded.data, updated_at = now();
  return jsonb_build_object('ok', true, 'ts', extract(epoch from now()) * 1000);
end $$;

create or replace function public.vf_save2(p_pseudo text, p_pin text, p_data text, p_base bigint, p_ver bigint)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare v bigint; r public.vf_saves%rowtype;
begin
  v := public.gp_check(p_pseudo, p_pin);
  if v is null or v = -1 then return jsonb_build_object('ok', false, 'err', 'bad'); end if;
  if length(coalesce(p_data, '')) > 200000 then return jsonb_build_object('ok', false, 'err', 'toobig'); end if;
  if p_ver is null or p_ver <= 0 then return jsonb_build_object('ok', false, 'err', 'badver'); end if;
  select * into r from public.vf_saves where player_id = v for update;
  if found and r.ver <> coalesce(p_base, -1) then
    return jsonb_build_object('ok', false, 'err', 'conflict', 'ver', r.ver, 'data', r.data);
  end if;
  if found then perform public.vf_keep(v, r.data, r.ver); end if;
  insert into public.vf_saves(player_id, data, ver, updated_at) values (v, coalesce(p_data, ''), p_ver, now())
  on conflict (player_id) do update set data = excluded.data, ver = excluded.ver, updated_at = now();
  return jsonb_build_object('ok', true, 'ver', p_ver);
end $$;

create or replace function public.vf_load(p_pseudo text, p_pin text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare v bigint; r public.vf_saves%rowtype;
begin
  v := public.gp_check(p_pseudo, p_pin);
  if v is null or v = -1 then return jsonb_build_object('ok', false, 'err', 'bad'); end if;
  select * into r from public.vf_saves where player_id = v;
  if not found then return jsonb_build_object('ok', true, 'data', null, 'ver', 0); end if;
  return jsonb_build_object('ok', true, 'data', r.data, 'ver', r.ver, 'ts', extract(epoch from r.updated_at) * 1000);
end $$;

grant execute on function public.vf_save(text, text, text) to anon, authenticated;
grant execute on function public.vf_save2(text, text, text, bigint, bigint) to anon, authenticated;
grant execute on function public.vf_load(text, text) to anon, authenticated;
