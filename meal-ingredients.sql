-- Run in Supabase before publishing the updated OurShopping site.
begin;

alter table public.shopping_items
  add column if not exists recipe_quantity text
    check (char_length(btrim(recipe_quantity)) between 1 and 120),
  add column if not exists recipe_only boolean not null default false;

alter table public.shopping_items
  drop constraint if exists shopping_items_recipe_only_check;
alter table public.shopping_items
  add constraint shopping_items_recipe_only_check check (
    not recipe_only or (
      meal_id is not null and recipe_quantity is not null
      and quantity is null and not purchased
    )
  );

-- A deleted meal keeps its purchases through the existing ON DELETE SET NULL.
-- Ingredients that only belong to its recipe are removed in the same transaction.
create or replace function public.remove_recipe_only_ingredients()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  delete from public.shopping_items
  where space_id = old.space_id and meal_id = old.id and recipe_only;
  return old;
end;
$$;

drop trigger if exists remove_recipe_only_ingredients on public.meals;
create trigger remove_recipe_only_ingredients
  before delete on public.meals
  for each row execute function public.remove_recipe_only_ingredients();

commit;
