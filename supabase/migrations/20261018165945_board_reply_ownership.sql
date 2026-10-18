-- Add viewer-relative reply ownership; preserve the invoker wrapper, grants,
-- membership checks, filtering and ordering. Older clients ignore the new field.
create or replace function app.ba_board(p_building uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u uuid := app.require_user();
begin
  if not app.ba_resident(p_building) then raise exception 'ACCESS_DENIED'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'id', p.id, 'building_id', p.building_id, 'author', coalesce(nullif(pr.full_name, ''), 'שכן'),
    'mine', p.author_id = u, 'apartment', p.apartment, 'text', p.body, 'kind', p.kind,
    'created_at', p.created_at, 'pinned', p.pinned, 'closed', p.closed,
    'replies', coalesce((select jsonb_agg(jsonb_build_object('author', coalesce(nullif(rp.full_name, ''), 'שכן'),
      'text', r.body, 'mine', r.author_id = u) order by r.created_at) from public.board_reply r join public.profile rp on rp.id = r.author_id where r.post_id = p.id), '[]'),
    'reactions', coalesce((select jsonb_object_agg(x.emoji, x.n) from (select emoji, count(*) n from public.board_reaction where post_id = p.id group by emoji) x), '{}'),
    'my_reactions', coalesce((select jsonb_agg(emoji) from public.board_reaction where post_id = p.id and user_id = u), '[]')
    ) order by p.pinned desc, p.created_at desc)
    from (select * from public.board_post where building_id = p_building and deleted_at is null order by pinned desc, created_at desc limit 100) p
    join public.profile pr on pr.id = p.author_id), '[]');
end $$;

