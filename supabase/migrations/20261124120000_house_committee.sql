-- House committee (ועד בית): building payments.
--   * The committee is every building admin plus residents they add (is_committee).
--   * Charges are per apartment: a monthly fee that opens itself each month, and
--     one-off collections such as a repair. Amounts are whole shekels.
--   * A resident reports "paid" for their apartment; the committee confirms it,
--     or marks cash payments itself. Residents see only their own apartment's
--     status and the building totals; the committee sees every apartment.
--   * Paying happens outside the app, through the committee's bit / PayBox links.

create table public.committee_settings (
  building_id uuid primary key references public.building(id),
  monthly_amount integer not null default 0 check (monthly_amount between 0 and 100000),
  monthly_due_day smallint not null default 10 check (monthly_due_day between 1 and 28),
  bit_link text not null default '' check (char_length(bit_link) <= 300),
  paybox_link text not null default '' check (char_length(paybox_link) <= 300),
  cash_note text not null default '' check (char_length(cash_note) <= 200),
  updated_by uuid references public.profile(id),
  updated_at timestamptz not null default now()
);
create index committee_settings_updated_by_idx on public.committee_settings(updated_by);

create table public.committee_charge (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references public.building(id),
  kind text not null check (kind in ('monthly', 'once')),
  title text not null check (char_length(title) between 1 and 80),
  notes text not null default '' check (char_length(notes) <= 500),
  amount integer not null check (amount between 1 and 100000),
  due_on date not null,
  -- First day of the month a monthly fee belongs to; null for one-off charges.
  period date check (period is null or extract(day from period) = 1),
  created_by uuid references public.profile(id),
  created_at timestamptz not null default now(),
  cancelled_at timestamptz,
  unique (id, building_id),
  check ((kind = 'monthly') = (period is not null))
);
create unique index committee_charge_month_idx on public.committee_charge(building_id, period) where kind = 'monthly';
create index committee_charge_feed_idx on public.committee_charge(building_id, due_on desc);
create index committee_charge_creator_idx on public.committee_charge(created_by);

create table public.committee_payment (
  charge_id uuid not null,
  building_id uuid not null,
  apartment_id uuid not null,
  status text not null check (status in ('reported', 'confirmed')),
  method text not null check (method in ('bit', 'paybox', 'cash', 'other')),
  reported_by uuid references public.profile(id),
  reported_at timestamptz,
  confirmed_by uuid references public.profile(id),
  confirmed_at timestamptz,
  primary key (charge_id, apartment_id),
  foreign key (charge_id, building_id) references public.committee_charge(id, building_id),
  foreign key (apartment_id, building_id) references public.apartment(id, building_id),
  check ((status = 'confirmed') = (confirmed_at is not null))
);
create index committee_payment_apartment_idx on public.committee_payment(apartment_id);
create index committee_payment_reported_by_idx on public.committee_payment(reported_by);
create index committee_payment_confirmed_by_idx on public.committee_payment(confirmed_by);

-- RPC-only data, like parking.
alter table public.committee_settings enable row level security;
alter table public.committee_charge enable row level security;
alter table public.committee_payment enable row level security;
revoke all on public.committee_settings, public.committee_charge, public.committee_payment from public, anon, authenticated;

create function app.ba_committee_member(b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select app.ba_resident(b) and exists(select 1 from public.community_member
    where building_id = b and user_id = (select auth.uid()) and status = 'approved'
      and (is_building_admin or is_committee))
$$;

-- Locks the building, checks the caller lives there and returns their apartment.
create function app.ba_committee_actor(b uuid, committee boolean) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); a uuid;
begin
  perform app.require_terms();
  perform 1 from public.building where id = b and status = 'active' for update;
  if not found or not app.ba_resident(b) or (committee and not app.ba_committee_member(b))
    then raise exception 'ACCESS_DENIED'; end if;
  select apartment_id into strict a from public.community_member where building_id = b and user_id = u and status = 'approved';
  return a;
end $$;

create function app.ba_committee_link_ok(link text) returns boolean
language sql immutable set search_path = '' as $$
  select link = '' or (char_length(link) <= 300 and link ~ '^https://[^\s]+$')
$$;

create function app.ba_committee(p_building uuid) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare a uuid := app.ba_committee_actor(p_building, false);
  boss boolean := app.ba_committee_member(p_building);
  s public.committee_settings; today date := (now() at time zone 'Asia/Jerusalem')::date;
  month date := date_trunc('month', (now() at time zone 'Asia/Jerusalem'))::date;
begin
  select * into s from public.committee_settings where building_id = p_building;
  -- The monthly fee opens itself the first time anyone looks in a new month.
  -- Opened after its usual day (say, set up mid-month), it gets a week to pay.
  if s.monthly_amount > 0 then
    insert into public.committee_charge(building_id, kind, title, amount, due_on, period)
      values(p_building, 'monthly', 'דמי ועד', s.monthly_amount,
        greatest(month + (s.monthly_due_day - 1), today + 7), month)
      on conflict (building_id, period) where kind = 'monthly' do nothing;
  end if;
  return jsonb_build_object(
    'is_committee', boss,
    'committee', coalesce((select jsonb_agg(coalesce(nullif(p.full_name, ''), 'שכן') order by m.created_at)
      from public.community_member m join public.profile p on p.id = m.user_id
      where m.building_id = p_building and m.status = 'approved' and (m.is_building_admin or m.is_committee)), '[]'),
    -- Residents the committee can add or remove; only for the committee.
    'members', case when boss then coalesce((select jsonb_agg(jsonb_build_object(
        'id', m.id, 'name', coalesce(nullif(p.full_name, ''), 'שכן'), 'apartment', coalesce(d.number, ap.number),
        'is_admin', m.is_building_admin, 'is_committee', m.is_building_admin or m.is_committee)
        order by coalesce(d.number, ap.number), m.created_at)
      from public.community_member m join public.profile p on p.id = m.user_id
      join public.apartment ap on ap.id = m.apartment_id left join public.community_apartment d on d.apartment_id = ap.id
      where m.building_id = p_building and m.status = 'approved'), '[]') else '[]'::jsonb end,
    'settings', jsonb_build_object(
      'monthly_amount', coalesce(s.monthly_amount, 0), 'monthly_due_day', coalesce(s.monthly_due_day, 10),
      'bit_link', coalesce(s.bit_link, ''), 'paybox_link', coalesce(s.paybox_link, ''), 'cash_note', coalesce(s.cash_note, '')),
    'charges', coalesce((select jsonb_agg(x.data order by x.due_on desc, x.created_at desc) from (
      select c.due_on, c.created_at, jsonb_build_object(
        'id', c.id, 'kind', c.kind, 'title', c.title, 'notes', c.notes, 'amount', c.amount,
        'due_on', c.due_on, 'period', c.period, 'created_at', c.created_at,
        'my_status', coalesce((select p.status from public.committee_payment p where p.charge_id = c.id and p.apartment_id = a), ''),
        'households', h.n,
        'paid', (select count(*) from public.committee_payment p where p.charge_id = c.id and p.status = 'confirmed'
          and p.apartment_id in (select apartment_id from public.community_member where building_id = p_building and status = 'approved')),
        'apartments', case when boss then coalesce((select jsonb_agg(jsonb_build_object(
            'apartment_id', ap.id, 'apartment', coalesce(d.number, ap.number),
            'status', coalesce(p.status, ''), 'method', coalesce(p.method, '')) order by coalesce(d.number, ap.number))
          from public.apartment ap left join public.community_apartment d on d.apartment_id = ap.id
          left join public.committee_payment p on p.charge_id = c.id and p.apartment_id = ap.id
          where ap.id in (select apartment_id from public.community_member where building_id = p_building and status = 'approved')), '[]')
          else '[]'::jsonb end) data
      from public.committee_charge c
      cross join lateral (select count(distinct apartment_id) n from public.community_member
        where building_id = p_building and status = 'approved') h
      where c.building_id = p_building and c.cancelled_at is null
        and (c.due_on >= today - 180 or not exists(select 1 from public.committee_payment p
          where p.charge_id = c.id and p.apartment_id = a and p.status = 'confirmed'))
      order by c.due_on desc, c.created_at desc limit 60) x), '[]'));
end $$;

create function app.ba_committee_settings(p_building uuid, p_monthly_amount integer, p_monthly_due_day integer,
  p_bit_link text, p_paybox_link text, p_cash_note text) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare bit text := btrim(coalesce(p_bit_link, '')); paybox text := btrim(coalesce(p_paybox_link, ''));
  month date := date_trunc('month', (now() at time zone 'Asia/Jerusalem'))::date;
begin
  perform app.ba_committee_actor(p_building, true);
  if p_monthly_amount is null or p_monthly_amount not between 0 and 100000
    or p_monthly_due_day is null or p_monthly_due_day not between 1 and 28
    or not app.ba_committee_link_ok(bit) or not app.ba_committee_link_ok(paybox)
    or char_length(coalesce(p_cash_note, '')) > 200 then raise exception 'INVALID_ARGUMENT'; end if;
  insert into public.committee_settings(building_id, monthly_amount, monthly_due_day, bit_link, paybox_link, cash_note, updated_by, updated_at)
    values(p_building, p_monthly_amount, p_monthly_due_day, bit, paybox, btrim(coalesce(p_cash_note, '')), auth.uid(), now())
    on conflict (building_id) do update set monthly_amount = excluded.monthly_amount, monthly_due_day = excluded.monthly_due_day,
      bit_link = excluded.bit_link, paybox_link = excluded.paybox_link, cash_note = excluded.cash_note,
      updated_by = excluded.updated_by, updated_at = excluded.updated_at;
  -- This month's fee follows the new amount until somebody has paid it.
  update public.committee_charge c set amount = p_monthly_amount,
    due_on = greatest(month + (p_monthly_due_day - 1), (now() at time zone 'Asia/Jerusalem')::date + 7)
    where c.building_id = p_building and c.kind = 'monthly' and c.period = month and c.cancelled_at is null
      and p_monthly_amount > 0 and not exists(select 1 from public.committee_payment p where p.charge_id = c.id);
  perform app.audit(p_building, 'committee.settings', 'building', p_building);
end $$;

create function app.ba_committee_charge(p_building uuid, p_title text, p_notes text, p_amount integer, p_due date) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare c uuid; v_title text := btrim(coalesce(p_title, ''));
  today date := (now() at time zone 'Asia/Jerusalem')::date;
begin
  perform app.ba_committee_actor(p_building, true);
  if char_length(v_title) not between 1 and 80 or char_length(coalesce(p_notes, '')) > 500
    or p_amount is null or p_amount not between 1 and 100000
    or p_due is null or p_due < today or p_due > today + 366 then raise exception 'INVALID_ARGUMENT'; end if;
  insert into public.committee_charge(building_id, kind, title, notes, amount, due_on, created_by)
    values(p_building, 'once', v_title, btrim(coalesce(p_notes, '')), p_amount, p_due, auth.uid()) returning id into c;
  perform app.audit(p_building, 'committee.charge', 'committee_charge', c);
  return c;
end $$;

-- Cancelled charges disappear from the page; their payments stay for the record.
create function app.ba_committee_cancel(p_charge uuid) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare b uuid;
begin
  select building_id into b from public.committee_charge where id = p_charge;
  perform app.ba_committee_actor(b, true);
  update public.committee_charge set cancelled_at = now() where id = p_charge and cancelled_at is null;
  perform app.audit(b, 'committee.cancel', 'committee_charge', p_charge);
end $$;

-- "I paid": reported for the caller's own apartment, waiting for the committee.
create function app.ba_committee_report(p_charge uuid, p_method text) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare c public.committee_charge; a uuid;
begin
  select * into c from public.committee_charge where id = p_charge;
  a := app.ba_committee_actor(c.building_id, false);
  if c.cancelled_at is not null then raise exception 'COMMITTEE_CHARGE_CLOSED'; end if;
  if p_method is null or p_method not in ('bit', 'paybox', 'cash', 'other') then raise exception 'INVALID_ARGUMENT'; end if;
  insert into public.committee_payment(charge_id, building_id, apartment_id, status, method, reported_by, reported_at)
    values(p_charge, c.building_id, a, 'reported', p_method, auth.uid(), now())
    on conflict (charge_id, apartment_id) do update set method = excluded.method,
      reported_by = excluded.reported_by, reported_at = excluded.reported_at
      where public.committee_payment.status = 'reported';
  perform app.audit(c.building_id, 'committee.report', 'committee_charge', p_charge);
end $$;

-- The committee marks an apartment paid (confirming a report, or cash) or unpaid.
create function app.ba_committee_mark(p_charge uuid, p_apartment uuid, p_paid boolean, p_method text) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare c public.committee_charge;
begin
  select * into c from public.committee_charge where id = p_charge;
  perform app.ba_committee_actor(c.building_id, true);
  if c.cancelled_at is not null then raise exception 'COMMITTEE_CHARGE_CLOSED'; end if;
  if p_paid is null or not exists(select 1 from public.community_member
    where building_id = c.building_id and apartment_id = p_apartment and status = 'approved') then raise exception 'INVALID_ARGUMENT'; end if;
  if p_paid then
    if p_method is not null and p_method not in ('bit', 'paybox', 'cash', 'other') then raise exception 'INVALID_ARGUMENT'; end if;
    insert into public.committee_payment(charge_id, building_id, apartment_id, status, method, confirmed_by, confirmed_at)
      values(p_charge, c.building_id, p_apartment, 'confirmed', coalesce(p_method, 'cash'), auth.uid(), now())
      on conflict (charge_id, apartment_id) do update set status = 'confirmed',
        method = coalesce(p_method, public.committee_payment.method), confirmed_by = excluded.confirmed_by,
        confirmed_at = excluded.confirmed_at;
  else
    delete from public.committee_payment where charge_id = p_charge and apartment_id = p_apartment;
  end if;
  perform app.audit(c.building_id, case when p_paid then 'committee.confirm' else 'committee.unmark' end,
    'committee_charge', p_charge);
end $$;

-- Adds or removes a resident from the committee. Building admins are always on it.
create function app.ba_committee_set_member(p_member uuid, p_on boolean) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare m public.community_member;
begin
  select * into m from public.community_member where id = p_member;
  perform app.ba_committee_actor(m.building_id, true);
  if p_on is null then raise exception 'INVALID_ARGUMENT'; end if;
  select * into m from public.community_member where id = p_member for update;
  if m.status <> 'approved' then raise exception 'INVALID_STATE'; end if;
  if not p_on and m.is_building_admin then raise exception 'COMMITTEE_ADMIN'; end if;
  if m.is_committee = p_on then return; end if;
  update public.community_member set is_committee = p_on, updated_at = now() where id = m.id;
  perform app.audit(m.building_id, case when p_on then 'committee.member_added' else 'committee.member_removed' end,
    'community_member', m.id);
end $$;

create function public.ba_committee(p_building uuid) returns jsonb
language sql volatile security invoker set search_path = '' as $$ select app.ba_committee(p_building) $$;
create function public.ba_committee_settings(p_building uuid, p_monthly_amount integer, p_monthly_due_day integer,
  p_bit_link text default '', p_paybox_link text default '', p_cash_note text default '') returns void
language sql volatile security invoker set search_path = '' as $$
  select app.ba_committee_settings(p_building, p_monthly_amount, p_monthly_due_day, p_bit_link, p_paybox_link, p_cash_note) $$;
create function public.ba_committee_charge(p_building uuid, p_title text, p_notes text, p_amount integer, p_due date) returns uuid
language sql volatile security invoker set search_path = '' as $$ select app.ba_committee_charge(p_building, p_title, p_notes, p_amount, p_due) $$;
create function public.ba_committee_cancel(p_charge uuid) returns void
language sql volatile security invoker set search_path = '' as $$ select app.ba_committee_cancel(p_charge) $$;
create function public.ba_committee_report(p_charge uuid, p_method text) returns void
language sql volatile security invoker set search_path = '' as $$ select app.ba_committee_report(p_charge, p_method) $$;
create function public.ba_committee_mark(p_charge uuid, p_apartment uuid, p_paid boolean, p_method text default null) returns void
language sql volatile security invoker set search_path = '' as $$ select app.ba_committee_mark(p_charge, p_apartment, p_paid, p_method) $$;
create function public.ba_committee_set_member(p_member uuid, p_on boolean) returns void
language sql volatile security invoker set search_path = '' as $$ select app.ba_committee_set_member(p_member, p_on) $$;

revoke all on function app.ba_committee_member(uuid), app.ba_committee_actor(uuid, boolean), app.ba_committee_link_ok(text),
  app.ba_committee(uuid), app.ba_committee_settings(uuid, integer, integer, text, text, text),
  app.ba_committee_charge(uuid, text, text, integer, date), app.ba_committee_cancel(uuid),
  app.ba_committee_report(uuid, text), app.ba_committee_mark(uuid, uuid, boolean, text), app.ba_committee_set_member(uuid, boolean),
  public.ba_committee(uuid), public.ba_committee_settings(uuid, integer, integer, text, text, text),
  public.ba_committee_charge(uuid, text, text, integer, date), public.ba_committee_cancel(uuid),
  public.ba_committee_report(uuid, text), public.ba_committee_mark(uuid, uuid, boolean, text), public.ba_committee_set_member(uuid, boolean)
  from public, anon, authenticated;
grant execute on function
  app.ba_committee(uuid), app.ba_committee_settings(uuid, integer, integer, text, text, text),
  app.ba_committee_charge(uuid, text, text, integer, date), app.ba_committee_cancel(uuid),
  app.ba_committee_report(uuid, text), app.ba_committee_mark(uuid, uuid, boolean, text), app.ba_committee_set_member(uuid, boolean),
  public.ba_committee(uuid), public.ba_committee_settings(uuid, integer, integer, text, text, text),
  public.ba_committee_charge(uuid, text, text, integer, date), public.ba_committee_cancel(uuid),
  public.ba_committee_report(uuid, text), public.ba_committee_mark(uuid, uuid, boolean, text), public.ba_committee_set_member(uuid, boolean)
  to authenticated;
