begin;

create table public.shopping_categories (
  space_id uuid not null references public.spaces(id) on delete cascade,
  id uuid not null default gen_random_uuid(),
  name text not null check (
    char_length(name) between 1 and 45
    and name = btrim(regexp_replace(name, '[[:space:]]+', ' ', 'g'))
    and lower(name) not in ('все', 'без категории')
  ),
  sort_order bigint generated always as identity,
  primary key (space_id, id)
);

create unique index shopping_categories_space_name_idx
  on public.shopping_categories (space_id, lower(name));

create table public.shopping_product_categories (
  space_id uuid not null references public.spaces(id) on delete cascade,
  product_key text not null check (char_length(product_key) between 1 and 120),
  category_id uuid,
  primary key (space_id, product_key),
  foreign key (space_id, category_id) references public.shopping_categories(space_id, id)
);

alter table public.shopping_categories enable row level security;
alter table public.shopping_product_categories enable row level security;
revoke all on public.shopping_categories, public.shopping_product_categories from public, anon, authenticated;
grant select, insert on public.shopping_categories to authenticated;
grant select, insert, update on public.shopping_product_categories to authenticated;

create policy "members read shopping categories" on public.shopping_categories
  for select to authenticated using (public.is_space_member(space_id));
create policy "members add shopping categories" on public.shopping_categories
  for insert to authenticated with check (public.is_space_member(space_id));

create policy "members read product categories" on public.shopping_product_categories
  for select to authenticated using (public.is_space_member(space_id));
create policy "members assign product categories" on public.shopping_product_categories
  for insert to authenticated with check (public.is_space_member(space_id));
create policy "members change product categories" on public.shopping_product_categories
  for update to authenticated using (public.is_space_member(space_id))
  with check (public.is_space_member(space_id));

insert into public.shopping_categories(space_id, name)
select space.id, starter.name
from public.spaces as space
cross join (values (1, 'Овощи'), (2, 'Фрукты'), (3, 'Напитки')) as starter(position, name)
order by space.id, starter.position;

alter publication supabase_realtime add table public.shopping_categories, public.shopping_product_categories;

commit;
