-- Run in Supabase SQL Editor. Creates a private shared workspace with RLS.
create extension if not exists pgcrypto;
create table if not exists public.spaces (id uuid primary key default gen_random_uuid(), name text not null default 'Новый год 2027', created_at timestamptz not null default now());
create table if not exists public.space_members (space_id uuid not null references public.spaces(id) on delete cascade, user_id uuid not null references auth.users(id) on delete cascade, display_name text not null, primary key(space_id,user_id));
create table if not exists public.meals (id uuid primary key default gen_random_uuid(), space_id uuid not null references public.spaces(id) on delete cascade, name text not null check(length(name) between 1 and 120), created_by uuid references auth.users(id), created_at timestamptz not null default now());
create table if not exists public.shopping_items (id uuid primary key default gen_random_uuid(), space_id uuid not null references public.spaces(id) on delete cascade, meal_id uuid references public.meals(id) on delete set null, name text not null check(length(name) between 1 and 120), quantity text, price numeric(12,2) check(price>=0), purchased boolean not null default false, purchased_by uuid references auth.users(id), purchased_at timestamptz, created_by uuid references auth.users(id), created_at timestamptz not null default now());
create index if not exists shopping_items_space_idx on public.shopping_items(space_id);
alter table public.spaces enable row level security;
alter table public.space_members enable row level security;
alter table public.meals enable row level security;
alter table public.shopping_items enable row level security;
create or replace function public.is_space_member(s uuid) returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.space_members where space_id=s and user_id=(select auth.uid())) $$;
revoke all on function public.is_space_member(uuid) from public;
grant execute on function public.is_space_member(uuid) to authenticated;
create policy "members read spaces" on public.spaces for select to authenticated using(public.is_space_member(id));
create policy "members read members" on public.space_members for select to authenticated using(public.is_space_member(space_id));
create policy "members read meals" on public.meals for select to authenticated using(public.is_space_member(space_id));
create policy "members add meals" on public.meals for insert to authenticated with check(public.is_space_member(space_id) and created_by=(select auth.uid()));
create policy "members delete meals" on public.meals for delete to authenticated using(public.is_space_member(space_id));
create policy "members read items" on public.shopping_items for select to authenticated using(public.is_space_member(space_id));
create policy "members add items" on public.shopping_items for insert to authenticated with check(public.is_space_member(space_id) and created_by=(select auth.uid()) and purchased=false and purchased_by is null);
create policy "members update items" on public.shopping_items for update to authenticated using(public.is_space_member(space_id)) with check(public.is_space_member(space_id) and (purchased_by is null or purchased_by=(select auth.uid())));
create policy "members delete items" on public.shopping_items for delete to authenticated using(public.is_space_member(space_id));
grant usage on schema public to authenticated;
grant select on public.spaces,public.space_members to authenticated;
grant select,insert,delete on public.meals to authenticated;
grant select,insert,update,delete on public.shopping_items to authenticated;
-- In Database > Publications > supabase_realtime, enable shopping_items and meals.
-- After creating TWO users in Authentication > Users, run ONCE with their real UUIDs:
-- with s as (insert into public.spaces(name) values ('Новый год 2027') returning id)
-- insert into public.space_members(space_id,user_id,display_name)
-- select s.id, v.user_id, v.display_name from s cross join
-- (values ('FIRST_USER_UUID'::uuid,'Эмик'),('SECOND_USER_UUID'::uuid,'❤️ Булка')) v(user_id,display_name);
