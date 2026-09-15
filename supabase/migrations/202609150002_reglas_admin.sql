begin;

-- Estas columnas también se aseguran aquí para permitir reintentos seguros
-- aunque la migración del calendario automático aún no se haya ejecutado.
alter table public.juegos
  add column if not exists provider text,
  add column if not exists external_event_id text,
  add column if not exists logo_visitante text,
  add column if not exists logo_local text,
  add column if not exists underdog boolean not null default false;

create unique index if not exists juegos_semana_provider_evento
  on public.juegos(semana_id, provider, external_event_id)
  where provider is not null and external_event_id is not null;

create unique index if not exists juego_underdog_unico on public.juegos(semana_id) where underdog;

create or replace function public.nfl_crear_semana(p_datos jsonb, p_juegos jsonb) returns uuid language plpgsql security definer
set search_path = public, pg_temp as $$
declare resultado uuid; juego jsonb; cierre timestamptz := (p_datos->>'fecha_cierre')::timestamptz;
begin
  if not es_admin() then raise exception 'Requiere administrador'; end if;
  perform 1 from temporadas where id=(p_datos->>'temporada_id')::uuid and estado='activa' for share;
  if not found then raise exception 'La temporada no está activa'; end if;
  if jsonb_typeof(p_juegos) is distinct from 'array' or jsonb_array_length(p_juegos) not between 1 and 16 then raise exception 'Incluye de 1 a 16 partidos'; end if;
  if (select count(*) from jsonb_array_elements(p_juegos) j where coalesce((j->>'desempate')::boolean,false)) <> 1 then raise exception 'Selecciona un partido de desempate'; end if;
  if (select count(*) from jsonb_array_elements(p_juegos) j where coalesce((j->>'underdog')::boolean,false)) <> 1 then raise exception 'Selecciona un partido underdog'; end if;
  if cierre <= now() then raise exception 'El cierre debe estar en el futuro'; end if;
  insert into semanas(temporada_id,numero,nombre,fecha_cierre)
  values((p_datos->>'temporada_id')::uuid,(p_datos->>'numero')::integer,p_datos->>'nombre',cierre) returning id into resultado;
  for juego in select value from jsonb_array_elements(p_juegos) loop
    if (juego->>'fecha_partido')::timestamptz < cierre then raise exception 'El cierre debe ser anterior o igual al primer partido'; end if;
    insert into juegos(semana_id,equipo_visitante,equipo_local,fecha_partido,desempate,underdog,provider,external_event_id,logo_visitante,logo_local)
    values(resultado,trim(juego->>'equipo_visitante'),trim(juego->>'equipo_local'),(juego->>'fecha_partido')::timestamptz,
      coalesce((juego->>'desempate')::boolean,false),coalesce((juego->>'underdog')::boolean,false),nullif(juego->>'provider',''),
      nullif(juego->>'external_event_id',''),nullif(juego->>'logo_visitante',''),nullif(juego->>'logo_local',''));
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
  select id into p_underdog from juegos where semana_id=p_semana and underdog and estado<>'cancelado';
  if p_underdog is null then raise exception 'El administrador todavía no define el partido underdog'; end if;
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
  coalesce(max(case when j.underdog and j.estado='finalizado' and
    q.elecciones->>j.id::text=case when j.puntos_local>j.puntos_visitante then 'L' when j.puntos_visitante>j.puntos_local then 'V' end then 2 else 0 end),0) as bono_underdog,
  case when bool_and(j.estado in ('finalizado','cancelado')) then
    max(case when j.desempate and j.estado='finalizado' then abs(q.total_desempate-j.puntos_local-j.puntos_visitante) end)
    end as diferencia,
  bool_and(j.estado in ('finalizado','cancelado')) as completa
from pronosticos_semanales q join semanas s on s.id=q.semana_id join juegos j on j.semana_id=s.id
join participantes_temporada p on p.id=q.participante_id join perfiles f on f.id=p.usuario_id
where s.fecha_cierre<=now()
group by q.id,s.temporada_id,f.username;

create or replace view public.nfl_puntos as
with base as (select *,aciertos+bono_underdog as puntos_base from nfl_base),
grupos as (select *,count(*) over(partition by semana_id,puntos_base) as empatados,
  min(diferencia) over(partition by semana_id,puntos_base) as minima from base),
candidatos as (select *,count(*) filter(where diferencia=minima) over(partition by semana_id,puntos_base) as cercanos from grupos)
select id,semana_id,temporada_id,participante_id,username,aciertos,bono_underdog,puntos_base,diferencia,completa,
  case when empatados>1 and cercanos=1 and diferencia=minima then 1 else 0 end as bono_desempate,
  puntos_base+case when empatados>1 and cercanos=1 and diferencia=minima then 1 else 0 end as puntos,
  (completa and empatados>1 and ((cercanos>1 and diferencia=minima) or diferencia is null)) as empate_pendiente
from candidatos;

create or replace view public.nfl_ranking_semanal as
select *,rank() over(partition by semana_id order by puntos desc) as posicion from nfl_puntos;

create or replace view public.nfl_ranking_temporada as
with totales as (
select p.temporada_id,p.id as participante_id,f.username,count(r.id)::integer as semanas_jugadas,
  coalesce(sum(r.aciertos),0)::integer as aciertos,coalesce(sum(r.bono_underdog),0)::integer as bono_underdog,
  coalesce(sum(r.bono_desempate),0)::integer as bono_desempate,coalesce(sum(r.puntos),0)::integer as puntos,
  coalesce(bool_or(r.empate_pendiente),false) as empate_pendiente
from participantes_temporada p join perfiles f on f.id=p.usuario_id left join nfl_puntos r on r.participante_id=p.id
group by p.id,f.username)
select *,rank() over(partition by temporada_id order by puntos desc) as posicion from totales;

create function public.nfl_configurar_juego(p_juego uuid, p_underdog boolean, p_cancelado boolean) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare juego juegos;
begin
  if not es_admin() then raise exception 'Requiere administrador'; end if;
  select * into juego from juegos where id=p_juego for update;
  if not found then raise exception 'Partido no encontrado'; end if;
  perform 1 from semanas where id=juego.semana_id and estado='abierta';
  if not found then raise exception 'La semana ya está finalizada'; end if;
  if p_underdog then update juegos set underdog=false where semana_id=juego.semana_id and id<>p_juego; end if;
  update juegos set underdog=p_underdog and not p_cancelado,
    estado=case when p_cancelado then 'cancelado' when estado='cancelado' then 'pendiente' else estado end,
    puntos_local=case when p_cancelado then null else puntos_local end,
    puntos_visitante=case when p_cancelado then null else puntos_visitante end
  where id=p_juego;
end;
$$;

revoke execute on function nfl_configurar_juego(uuid,boolean,boolean) from public,anon,authenticated;
grant execute on function nfl_configurar_juego(uuid,boolean,boolean) to authenticated;

commit;
