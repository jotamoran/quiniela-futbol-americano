begin;

alter table public.juegos
  add column provider text,
  add column external_event_id text,
  add column logo_visitante text,
  add column logo_local text;

create unique index juegos_semana_provider_evento
  on public.juegos(semana_id, provider, external_event_id)
  where provider is not null and external_event_id is not null;

create or replace function public.nfl_crear_semana(p_datos jsonb, p_juegos jsonb) returns uuid language plpgsql security definer
set search_path = public, pg_temp as $$
declare resultado uuid; juego jsonb; cierre timestamptz := (p_datos->>'fecha_cierre')::timestamptz;
begin
  if not es_admin() then raise exception 'Requiere administrador'; end if;
  perform 1 from temporadas where id=(p_datos->>'temporada_id')::uuid and estado='activa' for share;
  if not found then raise exception 'La temporada no está activa'; end if;
  if jsonb_typeof(p_juegos) is distinct from 'array' or jsonb_array_length(p_juegos) not between 1 and 16 then
    raise exception 'Incluye de 1 a 16 partidos';
  end if;
  if (select count(*) from jsonb_array_elements(p_juegos) j where coalesce((j->>'desempate')::boolean,false)) <> 1 then
    raise exception 'Selecciona un partido de desempate';
  end if;
  if cierre <= now() then raise exception 'El cierre debe estar en el futuro'; end if;
  insert into semanas(temporada_id,numero,nombre,fecha_cierre)
  values((p_datos->>'temporada_id')::uuid,(p_datos->>'numero')::integer,p_datos->>'nombre',cierre) returning id into resultado;
  for juego in select value from jsonb_array_elements(p_juegos) loop
    if (juego->>'fecha_partido')::timestamptz < cierre then raise exception 'El cierre debe ser anterior o igual al primer partido'; end if;
    insert into juegos(semana_id,equipo_visitante,equipo_local,fecha_partido,desempate,provider,external_event_id,logo_visitante,logo_local)
    values(resultado,trim(juego->>'equipo_visitante'),trim(juego->>'equipo_local'),(juego->>'fecha_partido')::timestamptz,
      coalesce((juego->>'desempate')::boolean,false),nullif(juego->>'provider',''),nullif(juego->>'external_event_id',''),
      nullif(juego->>'logo_visitante',''),nullif(juego->>'logo_local',''));
  end loop;
  if exists(select equipo from (
    select equipo_local equipo from juegos where semana_id=resultado union all select equipo_visitante from juegos where semana_id=resultado
  ) t group by equipo having count(*)>1) then raise exception 'Un equipo no puede jugar dos veces en una semana'; end if;
  return resultado;
end;
$$;

commit;
