begin;

create or replace function public.validar_underdog_pronostico()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp as $$
declare lado_no_favorito text;
begin
  select underdog_lado into lado_no_favorito
  from public.juegos
  where id = new.underdog_juego_id
    and semana_id = new.semana_id
    and estado <> 'cancelado';

  if lado_no_favorito is null then
    raise exception 'El no favorito de ese partido todavía no está disponible';
  end if;
  if new.underdog_eleccion is distinct from lado_no_favorito then
    raise exception 'El pronóstico underdog debe ser el equipo no favorito';
  end if;
  return new;
end;
$$;

revoke execute on function public.validar_underdog_pronostico() from public, anon, authenticated;

drop trigger if exists validar_underdog_pronostico_trigger on public.pronosticos_semanales;
create trigger validar_underdog_pronostico_trigger
before insert or update of semana_id, underdog_juego_id, underdog_eleccion
on public.pronosticos_semanales
for each row execute function public.validar_underdog_pronostico();

commit;
