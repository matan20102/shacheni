-- Board: paging and search, editable replies, and resident reports that managers resolve.
-- ba_board keeps its signature for installed clients; new clients read ba_board_page.

alter table public.board_post add column edited_at timestamptz;
alter table public.board_reply add column edited_at timestamptz, add column deleted_at timestamptz;

create table public.board_report (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null,
  post_id uuid not null,
  reply_id uuid references public.board_reply(id),
  reporter_id uuid not null references public.profile(id),
  reason text not null default '' check (char_length(reason) <= 300),
  status text not null default 'open' check (status in ('open', 'dismissed', 'removed')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references public.profile(id),
  foreign key (post_id, building_id) references public.board_post(id, building_id),
  check ((status = 'open') = (resolved_at is null))
);
-- One report per resident and target; it also hides the target from that resident.
create unique index board_report_once_idx on public.board_report
  (reporter_id, post_id, coalesce(reply_id, '00000000-0000-0000-0000-000000000000'::uuid));
create index board_report_open_idx on public.board_report(building_id, created_at) where status = 'open';
create index board_report_post_idx on public.board_report(post_id, building_id);
create index board_report_reply_idx on public.board_report(reply_id);
create index board_report_resolver_idx on public.board_report(resolved_by);
alter table public.board_report enable row level security;
revoke all on public.board_report from public, anon, authenticated;

create function app.ba_post_json(p public.board_post, u uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', p.id, 'building_id', p.building_id, 'author', coalesce(nullif(pr.full_name, ''), 'שכן'),
    'mine', p.author_id = u, 'apartment', p.apartment, 'text', p.body, 'kind', p.kind,
    'created_at', p.created_at, 'pinned', p.pinned, 'closed', p.closed, 'edited', p.edited_at is not null,
    'replies', coalesce((select jsonb_agg(jsonb_build_object('id', r.id,
        'author', coalesce(nullif(rp.full_name, ''), 'שכן'), 'text', r.body, 'mine', r.author_id = u,
        'edited', r.edited_at is not null, 'created_at', r.created_at) order by r.created_at, r.id)
      from public.board_reply r join public.profile rp on rp.id = r.author_id
      where r.post_id = p.id and r.deleted_at is null
        and not exists(select 1 from public.board_report x where x.reply_id = r.id and x.reporter_id = u)), '[]'),
    'reactions', coalesce((select jsonb_object_agg(x.emoji, x.n)
      from (select emoji, count(*) n from public.board_reaction where post_id = p.id group by emoji) x), '{}'),
    'my_reactions', coalesce((select jsonb_agg(emoji) from public.board_reaction where post_id = p.id and user_id = u), '[]'))
  from public.profile pr where pr.id = p.author_id
$$;

-- Posts the caller may see: not deleted, not reported by the caller, matching the search.
create function app.ba_visible_posts(p_building uuid, u uuid, p_pattern text) returns setof public.board_post
language sql stable security definer set search_path = '' as $$
  select bp.* from public.board_post bp
  where bp.building_id = p_building and bp.deleted_at is null
    and not exists(select 1 from public.board_report x
      where x.post_id = bp.id and x.reply_id is null and x.reporter_id = u)
    and (p_pattern is null or bp.body ilike p_pattern or exists(select 1 from public.board_reply r
      where r.post_id = bp.id and r.deleted_at is null and r.body ilike p_pattern))
$$;

create or replace function app.ba_board(p_building uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u uuid := app.require_user();
begin
  if not app.ba_resident(p_building) then raise exception 'ACCESS_DENIED'; end if;
  return coalesce((select jsonb_agg(app.ba_post_json(v, u) order by v.pinned desc, v.created_at desc)
    from app.ba_visible_posts(p_building, u, null) v
    where v.id in (select w.id from app.ba_visible_posts(p_building, u, null) w
      order by w.pinned desc, w.created_at desc limit 100)), '[]');
end $$;

-- Newest first. The first unfiltered page also carries every pinned post.
create function app.ba_board_page(p_building uuid, p_before timestamptz, p_query text, p_limit integer) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u uuid := app.require_user(); n integer := coalesce(p_limit, 30);
  q text := nullif(btrim(coalesce(p_query, '')), ''); pattern text; rows jsonb; more boolean;
begin
  if not app.ba_resident(p_building) then raise exception 'ACCESS_DENIED'; end if;
  if n not between 1 and 50 or char_length(coalesce(q, '')) > 60 then raise exception 'INVALID_ARGUMENT'; end if;
  if q is not null then
    pattern := '%' || replace(replace(replace(q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  end if;
  select count(*) > n into more from (select 1 from app.ba_visible_posts(p_building, u, pattern) w
    where p_before is null or w.created_at < p_before limit n + 1) c;
  select coalesce(jsonb_agg(app.ba_post_json(v, u) order by v.created_at desc, v.id desc), '[]') into rows
    from app.ba_visible_posts(p_building, u, pattern) v
    where v.id in (
      (select w.id from app.ba_visible_posts(p_building, u, pattern) w
        where p_before is null or w.created_at < p_before order by w.created_at desc, w.id desc limit n)
      union all
      (select w.id from app.ba_visible_posts(p_building, u, pattern) w
        where w.pinned and p_before is null and pattern is null order by w.created_at desc limit 20));
  return jsonb_build_object('posts', rows, 'has_more', more);
end $$;

create or replace function app.ba_post_action(p_post uuid, p_action text, p_text text, p_emoji text) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); p public.board_post;
begin
  select * into p from public.board_post where id = p_post and deleted_at is null for update;
  if p.id is null or not app.ba_resident(p.building_id) then raise exception 'ACCESS_DENIED'; end if;
  if p_action in ('edit', 'close') and p.author_id <> u then raise exception 'ACCESS_DENIED'; end if;
  if p_action = 'pin' and not app.ba_admin(p.building_id) then raise exception 'ACCESS_DENIED'; end if;
  if p_action = 'delete' and p.author_id <> u and not app.ba_admin(p.building_id) then raise exception 'ACCESS_DENIED'; end if;
  case p_action
    when 'edit' then
      if coalesce(char_length(btrim(p_text)), 0) not between 1 and 2000 then raise exception 'INVALID_ARGUMENT'; end if;
      update public.board_post set body = btrim(p_text), edited_at = now(), updated_at = now() where id = p_post;
    when 'close' then update public.board_post set closed = not closed, updated_at = now() where id = p_post;
    when 'pin' then update public.board_post set pinned = not pinned, updated_at = now() where id = p_post;
    when 'delete' then
      update public.board_post set deleted_at = now(), updated_at = now() where id = p_post;
      update public.board_report set status = 'removed', resolved_at = now(), resolved_by = u
        where post_id = p_post and status = 'open';
    when 'reply' then
      if p.closed then raise exception 'POST_CLOSED'; end if;
      if coalesce(char_length(btrim(p_text)), 0) not between 1 and 1000 then raise exception 'INVALID_ARGUMENT'; end if;
      insert into public.board_reply(building_id, post_id, author_id, body) values(p.building_id, p_post, u, btrim(p_text));
      -- One unread update per post, however many neighbours answer.
      if p.author_id <> u and not exists(select 1 from public.notification n where n.user_id = p.author_id
          and n.type = 'board.reply' and n.entity_id = p_post and n.read_at is null) then
        perform app.notify(p.author_id, p.building_id, 'board.reply', '{}', '/board', p_post);
      end if;
    when 'react' then
      if p_emoji is null or p_emoji not in ('💚', '🙌', '😊') then raise exception 'INVALID_ARGUMENT'; end if;
      delete from public.board_reaction where post_id = p_post and user_id = u and emoji = p_emoji;
      if not found then insert into public.board_reaction(building_id, post_id, user_id, emoji) values(p.building_id, p_post, u, p_emoji); end if;
    else raise exception 'INVALID_ARGUMENT';
  end case;
  if p_action in ('edit', 'close', 'pin', 'delete') then perform app.audit(p.building_id, 'board.' || p_action, 'board_post', p_post); end if;
end $$;

create function app.ba_reply_action(p_reply uuid, p_action text, p_text text) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); r public.board_reply;
begin
  select * into r from public.board_reply where id = p_reply and deleted_at is null for update;
  if r.id is null or not app.ba_read_post(r.post_id) then raise exception 'ACCESS_DENIED'; end if;
  if p_action = 'edit' then
    if r.author_id <> u then raise exception 'ACCESS_DENIED'; end if;
    if coalesce(char_length(btrim(p_text)), 0) not between 1 and 1000 then raise exception 'INVALID_ARGUMENT'; end if;
    update public.board_reply set body = btrim(p_text), edited_at = now() where id = p_reply;
  elsif p_action = 'delete' then
    if r.author_id <> u and not app.ba_admin(r.building_id) then raise exception 'ACCESS_DENIED'; end if;
    update public.board_reply set deleted_at = now() where id = p_reply;
    update public.board_report set status = 'removed', resolved_at = now(), resolved_by = u
      where reply_id = p_reply and status = 'open';
    perform app.audit(r.building_id, 'board.reply_delete', 'board_reply', p_reply);
  else raise exception 'INVALID_ARGUMENT';
  end if;
end $$;

create function app.ba_report(p_post uuid, p_reply uuid, p_reason text) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); p public.board_post; r public.board_reply; report uuid;
  reason text := btrim(coalesce(p_reason, ''));
begin
  select * into p from public.board_post where id = p_post and deleted_at is null;
  if p.id is null or not app.ba_resident(p.building_id) then raise exception 'ACCESS_DENIED'; end if;
  if char_length(reason) > 300 then raise exception 'INVALID_ARGUMENT'; end if;
  if p_reply is not null then
    select * into r from public.board_reply where id = p_reply and post_id = p_post and deleted_at is null;
    if r.id is null then raise exception 'ACCESS_DENIED'; end if;
    if r.author_id = u then raise exception 'INVALID_ARGUMENT'; end if;
  elsif p.author_id = u then raise exception 'INVALID_ARGUMENT';
  end if;
  if (select count(*) from public.board_report where reporter_id = u and created_at > now() - interval '1 day') >= 20
    then raise exception 'RATE_LIMITED'; end if;
  insert into public.board_report(building_id, post_id, reply_id, reporter_id, reason)
    values(p.building_id, p_post, p_reply, u, reason) on conflict do nothing returning id into report;
  if report is null then
    select id into report from public.board_report
      where reporter_id = u and post_id = p_post and reply_id is not distinct from p_reply;
    return report;
  end if;
  -- Managers hear about a target once, on its first report.
  perform app.notify(cm.user_id, p.building_id, 'board.report', '{}', '/board', p_post,
      'board.report:' || p_post || ':' || coalesce(p_reply::text, 'post'))
    from public.community_member cm
    where cm.building_id = p.building_id and cm.status = 'approved' and cm.is_building_admin and cm.user_id <> u;
  perform app.audit(p.building_id, 'board.report', 'board_report', report);
  return report;
end $$;

create function app.ba_reports(p_building uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform app.require_user();
  if not app.ba_admin(p_building) then raise exception 'ACCESS_DENIED'; end if;
  return coalesce((select jsonb_agg(x.data order by x.first_at, x.post_id, x.reply_id) from (
    select rp.post_id, rp.reply_id, min(rp.created_at) first_at, jsonb_build_object(
      'post_id', rp.post_id, 'reply_id', rp.reply_id, 'count', count(*),
      'reasons', coalesce(jsonb_agg(rp.reason order by rp.created_at) filter (where rp.reason <> ''), '[]'),
      'text', coalesce(r.body, p.body), 'post_text', left(p.body, 120),
      'author', coalesce(nullif(pr.full_name, ''), 'שכן'), 'apartment', p.apartment) data
    from public.board_report rp
    join public.board_post p on p.id = rp.post_id and p.deleted_at is null
    left join public.board_reply r on r.id = rp.reply_id
    join public.profile pr on pr.id = coalesce(r.author_id, p.author_id)
    where rp.building_id = p_building and rp.status = 'open' and (rp.reply_id is null or r.deleted_at is null)
    group by rp.post_id, rp.reply_id, r.body, p.body, pr.full_name, p.apartment
    order by min(rp.created_at) limit 100) x), '[]');
end $$;

create function app.ba_report_resolve(p_post uuid, p_reply uuid, p_remove boolean) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); b uuid;
begin
  select building_id into b from public.board_post where id = p_post for update;
  if b is null or not app.ba_admin(b) then raise exception 'ACCESS_DENIED'; end if;
  if p_remove is null then raise exception 'INVALID_ARGUMENT'; end if;
  if not exists(select 1 from public.board_report
    where post_id = p_post and reply_id is not distinct from p_reply and status = 'open')
    then raise exception 'INVALID_STATE'; end if;
  if p_remove and p_reply is null then
    update public.board_post set deleted_at = now(), updated_at = now() where id = p_post and deleted_at is null;
  elsif p_remove then
    update public.board_reply set deleted_at = now() where id = p_reply and post_id = p_post and deleted_at is null;
  end if;
  update public.board_report set status = case when p_remove then 'removed' else 'dismissed' end,
    resolved_at = now(), resolved_by = u
    where post_id = p_post and status = 'open'
      and (reply_id is not distinct from p_reply or (p_remove and p_reply is null));
  perform app.audit(b, case when p_remove then 'board.report_removed' else 'board.report_dismissed' end,
    case when p_reply is null then 'board_post' else 'board_reply' end, coalesce(p_reply, p_post));
end $$;

create function public.ba_board_page(p_building uuid, p_before timestamptz default null, p_query text default null, p_limit integer default 30)
  returns jsonb language sql stable security invoker set search_path = '' as $$ select app.ba_board_page(p_building, p_before, p_query, p_limit) $$;
create function public.ba_reply_action(p_reply uuid, p_action text, p_text text default null)
  returns void language sql volatile security invoker set search_path = '' as $$ select app.ba_reply_action(p_reply, p_action, p_text) $$;
create function public.ba_report(p_post uuid, p_reply uuid default null, p_reason text default '')
  returns uuid language sql volatile security invoker set search_path = '' as $$ select app.ba_report(p_post, p_reply, p_reason) $$;
create function public.ba_reports(p_building uuid)
  returns jsonb language sql stable security invoker set search_path = '' as $$ select app.ba_reports(p_building) $$;
create function public.ba_report_resolve(p_post uuid, p_reply uuid, p_remove boolean)
  returns void language sql volatile security invoker set search_path = '' as $$ select app.ba_report_resolve(p_post, p_reply, p_remove) $$;

revoke all on function app.ba_post_json(public.board_post, uuid), app.ba_visible_posts(uuid, uuid, text),
  app.ba_board_page(uuid, timestamptz, text, integer), public.ba_board_page(uuid, timestamptz, text, integer),
  app.ba_reply_action(uuid, text, text), public.ba_reply_action(uuid, text, text),
  app.ba_report(uuid, uuid, text), public.ba_report(uuid, uuid, text),
  app.ba_reports(uuid), public.ba_reports(uuid),
  app.ba_report_resolve(uuid, uuid, boolean), public.ba_report_resolve(uuid, uuid, boolean)
  from public, anon, authenticated;
grant execute on function
  app.ba_board_page(uuid, timestamptz, text, integer), public.ba_board_page(uuid, timestamptz, text, integer),
  app.ba_reply_action(uuid, text, text), public.ba_reply_action(uuid, text, text),
  app.ba_report(uuid, uuid, text), public.ba_report(uuid, uuid, text),
  app.ba_reports(uuid), public.ba_reports(uuid),
  app.ba_report_resolve(uuid, uuid, boolean), public.ba_report_resolve(uuid, uuid, boolean)
  to authenticated;
