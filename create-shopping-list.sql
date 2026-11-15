-- Run once in the existing project's Supabase SQL Editor.
-- Create a separate list and give the current list's participants access atomically.
begin;

create or replace function public.create_shopping_list(source_space uuid, list_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_name text := pg_catalog.btrim(list_name);
  new_space uuid;
begin
  if not public.is_space_member(source_space) then
    raise exception 'Доступ к списку запрещён' using errcode = '42501';
  end if;

  if selected_name is null or pg_catalog.char_length(selected_name) not between 1 and 80 then
    raise exception 'Название списка должно содержать от 1 до 80 символов' using errcode = '22023';
  end if;

  insert into public.spaces (name)
  values (selected_name)
  returning id into new_space;

  insert into public.space_members (space_id, user_id, display_name)
  select new_space, user_id, display_name
  from public.space_members
  where space_id = source_space;

  return new_space;
end;
$$;

revoke all on function public.create_shopping_list(uuid, text) from public;
grant execute on function public.create_shopping_list(uuid, text) to authenticated;

commit;
