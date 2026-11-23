-- ========== VILLE FOLLE 3D : sauvegarde en ligne de la progression ==========
-- A coller dans Supabase > SQL Editor > New query > Run.
-- Il faut d'abord avoir deja lance supabase.sql (comptes). Ce fichier peut etre relance sans danger.
-- Meme compte que Piege Infernal et Cubia (pseudo + PIN). Une sauvegarde par compte,
-- separee de celle de Cubia (rien n'est ecrase).

create table if not exists public.vf_saves (
  player_id bigint primary key references public.players(id) on delete cascade,
  data text not null default '',
  updated_at timestamptz not null default now()
);
alter table public.vf_saves enable row level security;
revoke all on public.vf_saves from anon, authenticated;

create or replace function public.vf_save(p_pseudo text, p_pin text, p_data text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare v bigint;
begin
  v := public.gp_check(p_pseudo, p_pin);
  if v is null or v = -1 then return jsonb_build_object('ok', false, 'err', 'bad'); end if;
  if length(coalesce(p_data, '')) > 200000 then return jsonb_build_object('ok', false, 'err', 'toobig'); end if;
  insert into public.vf_saves(player_id, data, updated_at) values (v, coalesce(p_data, ''), now())
  on conflict (player_id) do update set data = excluded.data, updated_at = now();
  return jsonb_build_object('ok', true, 'ts', extract(epoch from now()) * 1000);
end $$;

create or replace function public.vf_load(p_pseudo text, p_pin text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare v bigint; r public.vf_saves%rowtype;
begin
  v := public.gp_check(p_pseudo, p_pin);
  if v is null or v = -1 then return jsonb_build_object('ok', false, 'err', 'bad'); end if;
  select * into r from public.vf_saves where player_id = v;
  if not found then return jsonb_build_object('ok', true, 'data', null); end if;
  return jsonb_build_object('ok', true, 'data', r.data, 'ts', extract(epoch from r.updated_at) * 1000);
end $$;

grant execute on function public.vf_save(text, text, text) to anon, authenticated;
grant execute on function public.vf_load(text, text) to anon, authenticated;
