-- Apply after meal-details.sql, before publishing the site.
begin;

alter table public.meals
  add column if not exists recipe_video_path text check (
    recipe_video_path is null or recipe_video_path ~ (
      '^' || space_id::text || '/' || id::text ||
      '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.](mp4|mov|webm)$'
    )
  );

grant update (recipe_video_path) on public.meals to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('meal-videos', 'meal-videos', false, 20000000, array['video/mp4', 'video/quicktime', 'video/webm'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "members read meal videos" on storage.objects;
create policy "members read meal videos" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'meal-videos'
    and public.is_space_member(
      case
        when (storage.foldername(name))[1] ~ '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
        then (storage.foldername(name))[1]::uuid
      end
    )
  );

drop policy if exists "members upload meal videos" on storage.objects;
create policy "members upload meal videos" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'meal-videos'
    and name ~ '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}/[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}/[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}[.](mp4|mov|webm)$'
    and exists (
      select 1 from public.meals as meal
      where meal.space_id::text = (storage.foldername(objects.name))[1]
        and meal.id::text = (storage.foldername(objects.name))[2]
        and public.is_space_member(meal.space_id)
    )
  );

drop policy if exists "members remove unused meal videos" on storage.objects;
create policy "members remove unused meal videos" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'meal-videos'
    and public.is_space_member(
      case
        when (storage.foldername(name))[1] ~ '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
        then (storage.foldername(name))[1]::uuid
      end
    )
    and not exists (
      select 1 from public.meals as meal where meal.recipe_video_path = objects.name
    )
  );

commit;
