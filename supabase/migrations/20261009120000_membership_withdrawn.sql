-- An applicant can withdraw a pending application (S09). Kept as its own migration: a new enum
-- value cannot be used in the same transaction that adds it.
alter type public.membership_status add value if not exists 'withdrawn';
alter type public.membership_event_type add value if not exists 'withdrawn';
