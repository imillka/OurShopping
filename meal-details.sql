-- Run once in the existing OurShopping project's Supabase SQL Editor.
begin;

alter table public.meals
  add column if not exists description text not null default '',
  add column if not exists recipe_url text,
  add column if not exists photo_path text,
  add column if not exists details_revision integer not null default 0;

alter table public.meals
  drop constraint if exists meals_description_length,
  drop constraint if exists meals_recipe_url_format,
  drop constraint if exists meals_photo_path_format;

alter table public.meals
  add constraint meals_description_length check (char_length(description) <= 2000),
  add constraint meals_recipe_url_format check (
    recipe_url is null or (
      char_length(recipe_url) <= 2000 and recipe_url ~* '^https?://[^[:space:]]+$'
    )
  ),
  add constraint meals_photo_path_format check (
    photo_path is null or photo_path ~ (
      '^' || space_id::text || '/' || id::text ||
      '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.]jpg$'
    )
  );

grant update (description, recipe_url, photo_path, details_revision)
  on public.meals to authenticated;

drop policy if exists "members edit meal details" on public.meals;
create policy "members edit meal details" on public.meals
  for update to authenticated
  using (public.is_space_member(space_id))
  with check (public.is_space_member(space_id));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('meal-photos', 'meal-photos', false, 3145728, array['image/jpeg'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "members read meal photos" on storage.objects;
create policy "members read meal photos" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'meal-photos'
    and public.is_space_member(
      case
        when (storage.foldername(name))[1] ~ '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
        then (storage.foldername(name))[1]::uuid
      end
    )
  );

drop policy if exists "members upload meal photos" on storage.objects;
create policy "members upload meal photos" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'meal-photos'
    and name ~ '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}/[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}/[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}[.]jpg$'
    and exists (
      select 1 from public.meals as meal
      where meal.space_id::text = (storage.foldername(objects.name))[1]
        and meal.id::text = (storage.foldername(objects.name))[2]
        and public.is_space_member(meal.space_id)
    )
  );

drop policy if exists "members remove unused meal photos" on storage.objects;
create policy "members remove unused meal photos" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'meal-photos'
    and public.is_space_member(
      case
        when (storage.foldername(name))[1] ~ '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
        then (storage.foldername(name))[1]::uuid
      end
    )
    and not exists (
      select 1 from public.meals as meal where meal.photo_path = objects.name
    )
  );

commit;
