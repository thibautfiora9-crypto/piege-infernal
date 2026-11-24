-- ========== VILLE FOLLE 3D : classement en ligne ==========
-- Lit les sauvegardes (lecture seule) et renvoie les 20 meilleurs joueurs. Peut etre relance sans danger.
create or replace function public.vf_try_json(t text) returns jsonb
language plpgsql immutable as $$ begin return t::jsonb; exception when others then return null; end $$;

create or replace function public.vf_top()
returns jsonb language sql security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by (x->>'m')::numeric desc), '[]'::jsonb) from (
    select jsonb_build_object('p', p.pseudo,
      'm', greatest(0, least(99999999, coalesce((public.vf_try_json(s.data)->>'m')::numeric, 0)))::bigint,
      'k', greatest(0, coalesce((public.vf_try_json(s.data)->>'k')::numeric, 0))::bigint,
      'rb', greatest(0, coalesce((public.vf_try_json(s.data)->>'rb')::numeric, 0))::bigint,
      'mk', greatest(0, coalesce((public.vf_try_json(s.data)->>'mk')::numeric, 0))::bigint) as x
    from public.vf_saves s join public.players p on p.id = s.player_id
    where s.updated_at > now() - interval '60 days'
    order by coalesce((public.vf_try_json(s.data)->>'m')::numeric, 0) desc limit 20) q $$;
revoke all on function public.vf_try_json(text) from public, anon, authenticated;
grant execute on function public.vf_top() to anon, authenticated;
