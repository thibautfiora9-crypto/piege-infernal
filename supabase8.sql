-- ========== SITE : sauvegarde en ligne des jeux d'arcade ==========
-- Meme compte que Piege Infernal / Cubia / Ville Folle (pseudo + PIN). Peut etre relance sans danger.
create table if not exists public.site_saves (
  player_id bigint primary key references public.players(id) on delete cascade,
  data text not null default '{}',
  updated_at timestamptz not null default now()
);
alter table public.site_saves enable row level security;
revoke all on public.site_saves from anon, authenticated;

create or replace function public.site_save(p_pseudo text, p_pin text, p_data text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare v bigint;
begin
  v := public.gp_check(p_pseudo, p_pin);
  if v is null or v = -1 then return jsonb_build_object('ok', false, 'err', 'bad'); end if;
  if length(coalesce(p_data, '')) > 60000 then return jsonb_build_object('ok', false, 'err', 'toobig'); end if;
  insert into public.site_saves(player_id, data, updated_at) values (v, coalesce(p_data, '{}'), now())
  on conflict (player_id) do update set data = excluded.data, updated_at = now();
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.site_load(p_pseudo text, p_pin text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare v bigint; r public.site_saves%rowtype;
begin
  v := public.gp_check(p_pseudo, p_pin);
  if v is null or v = -1 then return jsonb_build_object('ok', false, 'err', 'bad'); end if;
  select * into r from public.site_saves where player_id = v;
  if not found then return jsonb_build_object('ok', true, 'data', null); end if;
  return jsonb_build_object('ok', true, 'data', r.data);
end $$;

grant execute on function public.site_save(text, text, text) to anon, authenticated;
grant execute on function public.site_load(text, text) to anon, authenticated;
