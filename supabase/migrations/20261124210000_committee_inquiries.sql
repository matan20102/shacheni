-- Private messages to the house committee (פניות לוועד).
--   * A resident opens an inquiry with a subject and a first message. Only its
--     author and the committee (building admins + is_committee) can read it.
--   * Both sides write back and forth in the same inquiry. The committee marks
--     it handled; a new message from the resident opens it again.
--   * Unread is tracked per side: the author, and the committee as a whole
--     (one committee member reading it clears it for the others).
--   * Account deletion removes the resident's own inquiries.
--   * Times use clock_timestamp(), so a question and its answer in one
--     transaction still come in order.

create table public.committee_inquiry (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references public.building(id),
  apartment_id uuid not null,
  author_id uuid not null references public.profile(id),
  subject text not null check (char_length(subject) between 1 and 80),
  status text not null default 'open' check (status in ('open', 'handled')),
  created_at timestamptz not null default clock_timestamp(),
  last_resident_at timestamptz not null default clock_timestamp(),
  last_committee_at timestamptz,
  resident_seen_at timestamptz,
  committee_seen_at timestamptz,
  handled_by uuid references public.profile(id),
  handled_at timestamptz,
  unique (id, building_id),
  foreign key (apartment_id, building_id) references public.apartment(id, building_id)
);
create index committee_inquiry_building_idx on public.committee_inquiry(building_id, last_resident_at desc);
create index committee_inquiry_author_idx on public.committee_inquiry(author_id, created_at desc);
create index committee_inquiry_apartment_idx on public.committee_inquiry(apartment_id);
create index committee_inquiry_handled_by_idx on public.committee_inquiry(handled_by);

create table public.committee_inquiry_message (
  id uuid primary key default gen_random_uuid(),
  inquiry_id uuid not null,
  building_id uuid not null,
  author_id uuid not null references public.profile(id),
  from_committee boolean not null,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default clock_timestamp(),
  foreign key (inquiry_id, building_id) references public.committee_inquiry(id, building_id) on delete cascade
);
create index committee_inquiry_message_thread_idx on public.committee_inquiry_message(inquiry_id, created_at);
create index committee_inquiry_message_author_idx on public.committee_inquiry_message(author_id);

-- RPC-only data, like the rest of the committee.
alter table public.committee_inquiry enable row level security;
alter table public.committee_inquiry_message enable row level security;
revoke all on public.committee_inquiry, public.committee_inquiry_message from public, anon, authenticated;

-- Who may read an inquiry, and from which side. Raises when neither.
create function app.ba_inquiry_side(i public.committee_inquiry) returns text
language plpgsql stable security definer set search_path = '' as $$
declare u uuid := app.require_user();
begin
  perform app.require_terms();
  if i.id is null or not app.ba_resident(i.building_id) then raise exception 'ACCESS_DENIED'; end if;
  if i.author_id = u then return 'resident'; end if;
  if app.ba_committee_member(i.building_id) then return 'committee'; end if;
  raise exception 'ACCESS_DENIED';
end $$;

create function app.ba_inquiry_preview(p_inquiry uuid) returns text
language sql stable security definer set search_path = '' as $$
  select left(m.body, 120) from public.committee_inquiry_message m
  where m.inquiry_id = p_inquiry order by m.created_at desc, m.id desc limit 1
$$;

-- The caller's own inquiries, and for the committee every inquiry of the building.
create function app.ba_inquiries(p_building uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u uuid := app.require_user(); boss boolean;
begin
  perform app.require_terms();
  if not app.ba_resident(p_building) then raise exception 'ACCESS_DENIED'; end if;
  boss := app.ba_committee_member(p_building);
  return jsonb_build_object(
    'is_committee', boss,
    'mine', coalesce((select jsonb_agg(x.data order by x.at desc) from (
      select greatest(i.last_resident_at, coalesce(i.last_committee_at, i.created_at)) at, jsonb_build_object(
        'id', i.id, 'subject', i.subject, 'status', i.status, 'created_at', i.created_at,
        'updated_at', greatest(i.last_resident_at, coalesce(i.last_committee_at, i.created_at)),
        'preview', app.ba_inquiry_preview(i.id),
        'unread', i.last_committee_at is not null and i.last_committee_at > coalesce(i.resident_seen_at, '-infinity')) data
      from public.committee_inquiry i where i.building_id = p_building and i.author_id = u
      order by 1 desc limit 50) x), '[]'),
    'inbox', case when boss then coalesce((select jsonb_agg(x.data order by x.open desc, x.at desc) from (
      select i.status = 'open' open, greatest(i.last_resident_at, coalesce(i.last_committee_at, i.created_at)) at,
        jsonb_build_object(
        'id', i.id, 'subject', i.subject, 'status', i.status, 'created_at', i.created_at,
        'updated_at', greatest(i.last_resident_at, coalesce(i.last_committee_at, i.created_at)),
        'preview', app.ba_inquiry_preview(i.id),
        'author', coalesce(nullif(p.full_name, ''), 'שכן'), 'apartment', coalesce(d.number, ap.number),
        'mine', i.author_id = u,
        'unread', i.author_id <> u and i.last_resident_at > coalesce(i.committee_seen_at, '-infinity')) data
      from public.committee_inquiry i join public.profile p on p.id = i.author_id
      join public.apartment ap on ap.id = i.apartment_id left join public.community_apartment d on d.apartment_id = ap.id
      where i.building_id = p_building
      order by 1 desc, 2 desc limit 100) x), '[]') else '[]'::jsonb end,
    'unread', (select count(*) from public.committee_inquiry i where i.building_id = p_building and (
      (i.author_id = u and i.last_committee_at is not null and i.last_committee_at > coalesce(i.resident_seen_at, '-infinity'))
      or (boss and i.author_id <> u and i.status = 'open' and i.last_resident_at > coalesce(i.committee_seen_at, '-infinity')))));
end $$;

-- One inquiry with its messages. Opening it marks it read for the caller's side.
create function app.ba_inquiry(p_inquiry uuid) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare i public.committee_inquiry; side text;
begin
  select * into i from public.committee_inquiry where id = p_inquiry;
  side := app.ba_inquiry_side(i);
  if side = 'resident' then
    update public.committee_inquiry set resident_seen_at = clock_timestamp() where id = i.id;
  else
    update public.committee_inquiry set committee_seen_at = clock_timestamp() where id = i.id;
  end if;
  update public.notification set read_at = clock_timestamp()
    where user_id = auth.uid() and type like 'committee.inquiry%' and entity_id = i.id and read_at is null;
  return jsonb_build_object(
    'id', i.id, 'subject', i.subject, 'status', i.status, 'created_at', i.created_at,
    'side', side,
    'author', case when side = 'committee' then (select coalesce(nullif(p.full_name, ''), 'שכן') from public.profile p where p.id = i.author_id) else '' end,
    'apartment', (select coalesce(d.number, ap.number) from public.apartment ap
      left join public.community_apartment d on d.apartment_id = ap.id where ap.id = i.apartment_id),
    'messages', coalesce((select jsonb_agg(jsonb_build_object(
        'id', m.id, 'body', m.body, 'from_committee', m.from_committee, 'created_at', m.created_at,
        'mine', m.author_id = auth.uid(),
        -- Residents see "הוועד"; the committee sees which member answered.
        'name', case when m.from_committee and side = 'resident' then 'הוועד'
          else coalesce(nullif(p.full_name, ''), 'שכן') end) order by m.created_at, m.id)
      from public.committee_inquiry_message m join public.profile p on p.id = m.author_id
      where m.inquiry_id = i.id), '[]'));
end $$;

create function app.ba_inquiry_notify_committee(i public.committee_inquiry) returns void
language sql volatile security definer set search_path = '' as $$
  select app.notify(m.user_id, i.building_id, 'committee.inquiry', '{}', '/committee', i.id,
    'committee.inquiry:' || i.id || ':' || extract(epoch from clock_timestamp()))
  from public.community_member m
  where m.building_id = i.building_id and m.status = 'approved' and (m.is_building_admin or m.is_committee)
    and m.user_id <> i.author_id
    and not exists(select 1 from public.notification n where n.user_id = m.user_id
      and n.type = 'committee.inquiry' and n.entity_id = i.id and n.read_at is null)
$$;

create function app.ba_inquiry_open(p_building uuid, p_subject text, p_body text) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); a uuid; i public.committee_inquiry;
  v_subject text := btrim(coalesce(p_subject, '')); v_body text := btrim(coalesce(p_body, ''));
begin
  a := app.ba_committee_actor(p_building, false);
  if char_length(v_subject) not between 1 and 80 or char_length(v_body) not between 1 and 2000
    then raise exception 'INVALID_ARGUMENT'; end if;
  -- A neighbour writing a lot is fine; a flood is not.
  if (select count(*) from public.committee_inquiry where author_id = u and building_id = p_building
      and created_at > now() - interval '1 day') >= 5 then raise exception 'TRY_LATER'; end if;
  insert into public.committee_inquiry(building_id, apartment_id, author_id, subject, resident_seen_at)
    values(p_building, a, u, v_subject, clock_timestamp()) returning * into i;
  insert into public.committee_inquiry_message(inquiry_id, building_id, author_id, from_committee, body)
    values(i.id, p_building, u, false, v_body);
  perform app.ba_inquiry_notify_committee(i);
  perform app.audit(p_building, 'committee.inquiry_open', 'committee_inquiry', i.id);
  return i.id;
end $$;

create function app.ba_inquiry_reply(p_inquiry uuid, p_body text) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); i public.committee_inquiry; side text;
  v_body text := btrim(coalesce(p_body, ''));
begin
  select * into i from public.committee_inquiry where id = p_inquiry for update;
  side := app.ba_inquiry_side(i);
  if char_length(v_body) not between 1 and 2000 then raise exception 'INVALID_ARGUMENT'; end if;
  if (select count(*) from public.committee_inquiry_message where inquiry_id = i.id and author_id = u
      and created_at > now() - interval '1 hour') >= 30 then raise exception 'TRY_LATER'; end if;
  insert into public.committee_inquiry_message(inquiry_id, building_id, author_id, from_committee, body)
    values(i.id, i.building_id, u, side = 'committee', v_body);
  if side = 'committee' then
    update public.committee_inquiry set last_committee_at = clock_timestamp(), committee_seen_at = clock_timestamp() where id = i.id;
    if not exists(select 1 from public.notification n where n.user_id = i.author_id
        and n.type = 'committee.inquiry_reply' and n.entity_id = i.id and n.read_at is null) then
      perform app.notify(i.author_id, i.building_id, 'committee.inquiry_reply', '{}', '/committee', i.id,
        'committee.inquiry_reply:' || i.id || ':' || extract(epoch from clock_timestamp()));
    end if;
  else
    -- The resident wrote again: back to the committee's open list.
    update public.committee_inquiry set last_resident_at = clock_timestamp(), resident_seen_at = clock_timestamp(),
      status = 'open', handled_by = null, handled_at = null where id = i.id returning * into i;
    perform app.ba_inquiry_notify_committee(i);
  end if;
end $$;

-- The committee marks an inquiry handled, or opens it again.
create function app.ba_inquiry_status(p_inquiry uuid, p_status text) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare i public.committee_inquiry;
begin
  select * into i from public.committee_inquiry where id = p_inquiry for update;
  if i.id is null or not app.ba_committee_member(i.building_id) then raise exception 'ACCESS_DENIED'; end if;
  perform app.require_terms();
  if p_status is null or p_status not in ('open', 'handled') then raise exception 'INVALID_ARGUMENT'; end if;
  if i.status = p_status then return; end if;
  update public.committee_inquiry set status = p_status,
    handled_by = case when p_status = 'handled' then auth.uid() end,
    handled_at = case when p_status = 'handled' then clock_timestamp() end,
    committee_seen_at = clock_timestamp() where id = i.id;
  perform app.audit(i.building_id, 'committee.inquiry_' || p_status, 'committee_inquiry', i.id);
end $$;

-- A deleted account takes its inquiries with it. ba_delete_account blanks the
-- profile and sets deleted_at; this runs on that update.
create function app.ba_inquiry_forget_author() returns trigger
language plpgsql volatile security definer set search_path = '' as $$
begin
  delete from public.committee_inquiry where author_id = new.id;
  return null;
end $$;
create trigger profile_forget_inquiries after update of deleted_at on public.profile
  for each row when (old.deleted_at is null and new.deleted_at is not null)
  execute function app.ba_inquiry_forget_author();

create function public.ba_inquiries(p_building uuid) returns jsonb
language sql stable security invoker set search_path = '' as $$ select app.ba_inquiries(p_building) $$;
create function public.ba_inquiry(p_inquiry uuid) returns jsonb
language sql volatile security invoker set search_path = '' as $$ select app.ba_inquiry(p_inquiry) $$;
create function public.ba_inquiry_open(p_building uuid, p_subject text, p_body text) returns uuid
language sql volatile security invoker set search_path = '' as $$ select app.ba_inquiry_open(p_building, p_subject, p_body) $$;
create function public.ba_inquiry_reply(p_inquiry uuid, p_body text) returns void
language sql volatile security invoker set search_path = '' as $$ select app.ba_inquiry_reply(p_inquiry, p_body) $$;
create function public.ba_inquiry_status(p_inquiry uuid, p_status text) returns void
language sql volatile security invoker set search_path = '' as $$ select app.ba_inquiry_status(p_inquiry, p_status) $$;

revoke all on function app.ba_inquiry_side(public.committee_inquiry), app.ba_inquiry_preview(uuid),
  app.ba_inquiries(uuid), app.ba_inquiry(uuid), app.ba_inquiry_notify_committee(public.committee_inquiry),
  app.ba_inquiry_open(uuid, text, text), app.ba_inquiry_reply(uuid, text), app.ba_inquiry_status(uuid, text),
  app.ba_inquiry_forget_author(),
  public.ba_inquiries(uuid), public.ba_inquiry(uuid), public.ba_inquiry_open(uuid, text, text),
  public.ba_inquiry_reply(uuid, text), public.ba_inquiry_status(uuid, text)
  from public, anon, authenticated;
grant execute on function
  app.ba_inquiries(uuid), app.ba_inquiry(uuid), app.ba_inquiry_open(uuid, text, text),
  app.ba_inquiry_reply(uuid, text), app.ba_inquiry_status(uuid, text),
  public.ba_inquiries(uuid), public.ba_inquiry(uuid), public.ba_inquiry_open(uuid, text, text),
  public.ba_inquiry_reply(uuid, text), public.ba_inquiry_status(uuid, text)
  to authenticated;
