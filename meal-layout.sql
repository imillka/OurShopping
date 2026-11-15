-- Optional: run after meal-details.sql to enable shared preparation facts.
begin;

alter table public.meals
  add column if not exists prep_minutes integer check (prep_minutes between 1 and 1440),
  add column if not exists servings integer check (servings between 1 and 999),
  add column if not exists difficulty text check (difficulty in ('easy', 'medium', 'hard'));

grant update (prep_minutes, servings, difficulty) on public.meals to authenticated;

commit;
