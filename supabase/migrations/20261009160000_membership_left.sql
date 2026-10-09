-- A resident can leave their building (e.g. moving apartments). Own migration: a new enum value
-- cannot be used in the transaction that adds it.
alter type public.membership_status add value if not exists 'left';
alter type public.membership_event_type add value if not exists 'left';
