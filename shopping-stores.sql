begin;

create table public.shopping_stores (
  space_id uuid not null references public.spaces(id) on delete cascade,
  id uuid not null default gen_random_uuid(),
  name text not null check (
    char_length(name) between 1 and 45
    and name = btrim(regexp_replace(name, '[[:space:]]+', ' ', 'g'))
  ),
  icon_value text not null default '🛍️' check (
    char_length(icon_value) between 1 and 32
    or (char_length(icon_value) <= 70000 and icon_value ~ '^data:image/png;base64,[A-Za-z0-9+/]+=*$')
  ),
  primary key (space_id, id)
);

create unique index shopping_stores_space_name_idx
  on public.shopping_stores (space_id, lower(name));

alter table public.shopping_stores enable row level security;
revoke all on public.shopping_stores from public, anon, authenticated;
grant select, insert, update on public.shopping_stores to authenticated;

create policy "members read shopping stores" on public.shopping_stores
  for select to authenticated using (public.is_space_member(space_id));
create policy "members add shopping stores" on public.shopping_stores
  for insert to authenticated with check (public.is_space_member(space_id));
create policy "members change shopping stores" on public.shopping_stores
  for update to authenticated using (public.is_space_member(space_id))
  with check (public.is_space_member(space_id));

alter table public.shopping_items add column store_id uuid;
alter table public.shopping_items add constraint shopping_items_store_fk
  foreign key (space_id, store_id) references public.shopping_stores (space_id, id);
create index shopping_items_store_idx on public.shopping_items (space_id, store_id);

alter publication supabase_realtime add table public.shopping_stores;

commit;
