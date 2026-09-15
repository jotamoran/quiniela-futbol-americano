begin;

alter table public.juegos
  add column if not exists underdog_lado text,
  add column if not exists underdog_fuente text,
  add column if not exists underdog_actualizado_el timestamptz;

alter table public.juegos drop constraint if exists juegos_underdog_lado_check;
alter table public.juegos add constraint juegos_underdog_lado_check
  check (underdog_lado is null or underdog_lado in ('L', 'V'));

drop index if exists public.juego_underdog_unico;

create or replace function public.proteger_underdog_cerrado()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp as $$
declare semana public.semanas%rowtype;
begin
  if new.underdog_lado is distinct from old.underdog_lado then
    select * into semana from public.semanas where id = old.semana_id;
    if semana.estado = 'finalizada' or semana.fecha_cierre <= clock_timestamp() then
      raise exception 'El underdog ya no puede cambiarse después del cierre';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists proteger_underdog_cerrado_trigger on public.juegos;
create trigger proteger_underdog_cerrado_trigger
before update of underdog_lado, underdog_fuente, underdog_actualizado_el on public.juegos
for each row execute function public.proteger_underdog_cerrado();

create or replace function public.nfl_crear_semana(p_datos jsonb, p_juegos jsonb) returns uuid
language plpgsql security definer
set search_path = public, pg_temp as $$
declare resultado uuid; juego jsonb; cierre timestamptz := (p_datos->>'fecha_cierre')::timestamptz;
begin
  if not es_admin() then raise exception 'Requiere administrador'; end if;
  perform 1 from temporadas where id=(p_datos->>'temporada_id')::uuid and estado='activa' for share;
  if not found then raise exception 'La temporada no está activa'; end if;
  if jsonb_typeof(p_juegos) is distinct from 'array' or jsonb_array_length(p_juegos) not between 1 and 16 then raise exception 'Incluye de 1 a 16 partidos'; end if;
  if (select count(*) from jsonb_array_elements(p_juegos) j where coalesce((j->>'desempate')::boolean,false)) <> 1 then raise exception 'Selecciona un partido de desempate'; end if;
  if cierre <= now() then raise exception 'El cierre debe estar en el futuro'; end if;
  insert into semanas(temporada_id,numero,nombre,fecha_cierre)
  values((p_datos->>'temporada_id')::uuid,(p_datos->>'numero')::integer,p_datos->>'nombre',cierre) returning id into resultado;
  for juego in select value from jsonb_array_elements(p_juegos) loop
    insert into juegos(semana_id,equipo_visitante,equipo_local,fecha_partido,desempate,underdog,provider,external_event_id,logo_visitante,logo_local)
    values(resultado,trim(juego->>'equipo_visitante'),trim(juego->>'equipo_local'),(juego->>'fecha_partido')::timestamptz,
      coalesce((juego->>'desempate')::boolean,false),false,nullif(juego->>'provider',''),nullif(juego->>'external_event_id',''),
      nullif(juego->>'logo_visitante',''),nullif(juego->>'logo_local',''));
  end loop;
  if exists(select equipo from (
    select equipo_local equipo from juegos where semana_id=resultado union all select equipo_visitante from juegos where semana_id=resultado
  ) t group by equipo having count(*)>1) then raise exception 'Un equipo no puede jugar dos veces en una semana'; end if;
  return resultado;
end;
$$;

create or replace function public.nfl_guardar_pronosticos(p_semana uuid, p_elecciones jsonb, p_underdog uuid, p_total integer)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare semana semanas; participante uuid; resultado uuid;
begin
  if auth.uid() is null then raise exception 'Inicia sesión'; end if;
  select * into semana from semanas where id=p_semana for update;
  if not found or semana.estado <> 'abierta' or clock_timestamp() >= semana.fecha_cierre then raise exception 'La semana está cerrada'; end if;
  perform 1 from temporadas where id=semana.temporada_id and estado='activa';
  if not found then raise exception 'La temporada está finalizada'; end if;
  select id into participante from participantes_temporada where temporada_id=semana.temporada_id and usuario_id=auth.uid();
  if participante is null then raise exception 'Inscríbete a la temporada'; end if;
  if jsonb_typeof(p_elecciones) is distinct from 'object' then raise exception 'Pronósticos inválidos'; end if;
  if (select count(*) from jsonb_object_keys(p_elecciones)) <> (select count(*) from juegos where semana_id=p_semana and estado<>'cancelado')
    or exists(select 1 from juegos where semana_id=p_semana and estado<>'cancelado' and coalesce(p_elecciones->>id::text,'') not in ('L','V')) then
    raise exception 'Elige visitante o local en todos los partidos';
  end if;
  if not exists(select 1 from juegos where id=p_underdog and semana_id=p_semana and estado<>'cancelado') then raise exception 'Elige un partido underdog'; end if;
  if exists(select 1 from juegos where semana_id=p_semana and estado<>'cancelado' and underdog_lado is null) then
    raise exception 'Los momios del underdog todavía no están disponibles';
  end if;
  insert into pronosticos_semanales(semana_id,participante_id,elecciones,underdog_juego_id,underdog_eleccion,total_desempate)
  values(p_semana,participante,p_elecciones,p_underdog,p_elecciones->>p_underdog::text,p_total)
  on conflict(semana_id,participante_id) do update set elecciones=excluded.elecciones,underdog_juego_id=excluded.underdog_juego_id,
    underdog_eleccion=excluded.underdog_eleccion,total_desempate=excluded.total_desempate,actualizado_el=now()
  returning id into resultado;
  return resultado;
end;
$$;

create or replace view public.nfl_base as
select q.id, q.semana_id, s.temporada_id, q.participante_id, f.username,
  count(*) filter(where j.estado='finalizado' and
    q.elecciones->>j.id::text = case when j.puntos_local>j.puntos_visitante then 'L' when j.puntos_visitante>j.puntos_local then 'V' end)::integer as aciertos,
  coalesce(max(case when j.id=q.underdog_juego_id and j.estado='finalizado'
    and q.underdog_eleccion=case when j.puntos_local>j.puntos_visitante then 'L' when j.puntos_visitante>j.puntos_local then 'V' end
    and ((j.underdog_lado is not null and q.underdog_eleccion=j.underdog_lado) or (j.underdog_lado is null and j.underdog)) then 2 else 0 end),0) as bono_underdog,
  case when bool_and(j.estado in ('finalizado','cancelado')) then
    max(case when j.desempate and j.estado='finalizado' then abs(q.total_desempate-j.puntos_local-j.puntos_visitante) end)
    end as diferencia,
  bool_and(j.estado in ('finalizado','cancelado')) as completa
from pronosticos_semanales q join semanas s on s.id=q.semana_id join juegos j on j.semana_id=s.id
join participantes_temporada p on p.id=q.participante_id join perfiles f on f.id=p.usuario_id
where s.fecha_cierre<=now()
group by q.id,s.temporada_id,f.username;

create or replace function public.nfl_configurar_juego(p_juego uuid, p_underdog boolean, p_cancelado boolean) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare juego juegos;
begin
  if not es_admin() then raise exception 'Requiere administrador'; end if;
  if p_underdog then raise exception 'El underdog se determina automáticamente'; end if;
  select * into juego from juegos where id=p_juego for update;
  if not found then raise exception 'Partido no encontrado'; end if;
  perform 1 from semanas where id=juego.semana_id and estado='abierta';
  if not found then raise exception 'La semana ya está finalizada'; end if;
  update juegos set estado=case when p_cancelado then 'cancelado' when estado='cancelado' then 'pendiente' else estado end,
    puntos_local=case when p_cancelado then null else puntos_local end,
    puntos_visitante=case when p_cancelado then null else puntos_visitante end
  where id=p_juego;
end;
$$;

commit;
