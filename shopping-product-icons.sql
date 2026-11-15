begin;

create table public.shopping_product_icons (
  space_id uuid not null references public.spaces(id) on delete cascade,
  product_key text not null check (char_length(product_key) between 1 and 120),
  icon_value text not null check (
    (char_length(icon_value) between 1 and 16 and icon_value !~ '^data:')
    or (char_length(icon_value) <= 70000 and icon_value ~ '^data:image/png;base64,[A-Za-z0-9+/]+={0,2}$')
  ),
  primary key (space_id, product_key)
);

alter table public.shopping_product_icons enable row level security;
revoke all on public.shopping_product_icons from public, anon, authenticated;
grant select, insert, update on public.shopping_product_icons to authenticated;

create policy "members read product icons" on public.shopping_product_icons
for select to authenticated using (public.is_space_member(space_id));
create policy "members add product icons" on public.shopping_product_icons
for insert to authenticated with check (public.is_space_member(space_id));
create policy "members change product icons" on public.shopping_product_icons
for update to authenticated using (public.is_space_member(space_id))
with check (public.is_space_member(space_id));

alter publication supabase_realtime add table public.shopping_product_icons;

commit;
