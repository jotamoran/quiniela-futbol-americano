begin;

create table public.perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre_completo text not null check (length(trim(nombre_completo)) between 1 and 120),
  username text not null unique check (username ~ '^[a-z0-9_]{3,20}$'),
  rol text not null default 'usuario' check (rol in ('usuario','admin')),
  creado_el timestamptz not null default now()
);

create function public.es_admin() returns boolean language sql stable security definer
set search_path = public, pg_temp as $$
  select exists(select 1 from perfiles where id = auth.uid() and rol = 'admin');
$$;

create table public.temporadas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null check (length(trim(nombre)) between 1 and 100),
  anio integer not null check (anio between 2020 and 2100),
  cuota numeric(10,2) not null default 2500 check (cuota >= 0),
  fecha_limite_pago timestamptz not null,
  premio_semanal numeric(10,2) not null default 500 check (premio_semanal >= 0),
  premio_primero numeric(10,2) check (premio_primero >= 0),
  premio_segundo numeric(10,2) check (premio_segundo >= 0),
  premio_tercero numeric(10,2) check (premio_tercero >= 0),
  estado text not null default 'activa' check (estado in ('activa','finalizada')),
  creado_el timestamptz not null default now()
);
create unique index temporada_activa_unica on temporadas((estado)) where estado = 'activa';
insert into temporadas(nombre, anio, cuota, fecha_limite_pago, premio_semanal)
values ('NFL 2026', 2026, 2500, '2026-09-30 23:59:59-06', 500);

create table public.participantes_temporada (
  id uuid primary key default gen_random_uuid(),
  temporada_id uuid not null references temporadas(id),
  usuario_id uuid not null references perfiles(id),
  telefono text not null default '' check (length(telefono) <= 30),
  estado_pago text not null default 'pendiente' check (estado_pago in ('pendiente','revision','pagado')),
  referencia_pago text not null default '' check (length(referencia_pago) <= 200),
  notas_admin text not null default '' check (length(notas_admin) <= 2000),
  pagado_el timestamptz,
  revisado_por uuid references perfiles(id),
  actualizado_el timestamptz not null default now(),
  creado_el timestamptz not null default now(),
  unique(temporada_id, usuario_id),
  check ((estado_pago = 'pagado') = (pagado_el is not null))
);

create table public.semanas (
  id uuid primary key default gen_random_uuid(),
  temporada_id uuid not null references temporadas(id),
  numero integer not null check (numero between 1 and 30),
  nombre text not null check (length(trim(nombre)) between 1 and 100),
  fecha_cierre timestamptz not null,
  estado text not null default 'abierta' check (estado in ('abierta','finalizada')),
  creado_el timestamptz not null default now(),
  unique(temporada_id, numero)
);

create table public.juegos (
  id uuid primary key default gen_random_uuid(),
  semana_id uuid not null references semanas(id),
  equipo_visitante text not null check (length(trim(equipo_visitante)) between 1 and 80),
  equipo_local text not null check (length(trim(equipo_local)) between 1 and 80),
  fecha_partido timestamptz not null,
  desempate boolean not null default false,
  estado text not null default 'pendiente' check (estado in ('pendiente','en_curso','finalizado','cancelado')),
  puntos_visitante integer check (puntos_visitante between 0 and 200),
  puntos_local integer check (puntos_local between 0 and 200),
  check (equipo_visitante <> equipo_local),
  check (estado not in ('en_curso','finalizado') or (puntos_visitante is not null and puntos_local is not null)),
  unique(semana_id, equipo_visitante, equipo_local)
);
create unique index juego_desempate_unico on juegos(semana_id) where desempate;

create table public.pronosticos_semanales (
  id uuid primary key default gen_random_uuid(),
  semana_id uuid not null references semanas(id),
  participante_id uuid not null references participantes_temporada(id),
  elecciones jsonb not null,
  underdog_juego_id uuid not null references juegos(id),
  underdog_eleccion text not null check (underdog_eleccion in ('L','V')),
  total_desempate integer not null check (total_desempate between 0 and 400),
  actualizado_el timestamptz not null default now(),
  unique(semana_id, participante_id)
);
create index juegos_semana on juegos(semana_id);
create index participantes_usuario on participantes_temporada(usuario_id);
create index pronosticos_participante on pronosticos_semanales(participante_id);

create table public.datos_bancarios (
  id integer primary key default 1 check (id = 1), banco text, clabe text, titular text,
  actualizado_el timestamptz not null default now()
);
insert into datos_bancarios(id) values (1);

alter table perfiles enable row level security;
alter table temporadas enable row level security;
alter table participantes_temporada enable row level security;
alter table semanas enable row level security;
alter table juegos enable row level security;
alter table pronosticos_semanales enable row level security;
alter table datos_bancarios enable row level security;

revoke all on perfiles, temporadas, participantes_temporada, semanas, juegos, pronosticos_semanales, datos_bancarios from anon, authenticated;
grant select on temporadas, semanas, juegos to anon, authenticated;
grant select on perfiles, participantes_temporada, pronosticos_semanales to authenticated;
grant select on datos_bancarios to anon, authenticated;
grant update(nombre_completo) on perfiles to authenticated;
grant update(banco, clabe, titular, actualizado_el) on datos_bancarios to authenticated;
grant all on perfiles, temporadas, participantes_temporada, semanas, juegos, pronosticos_semanales, datos_bancarios to service_role;

create policy perfil_lectura on perfiles for select to authenticated using (id = auth.uid() or es_admin());
create policy perfil_nombre on perfiles for update to authenticated using (id = auth.uid() or es_admin()) with check (id = auth.uid() or es_admin());
create policy temporada_publica on temporadas for select using (true);
create policy semana_publica on semanas for select using (true);
create policy juego_publico on juegos for select using (true);
create policy participantes_privados on participantes_temporada for select to authenticated using (usuario_id = auth.uid() or es_admin());
create policy pronosticos_privados on pronosticos_semanales for select to authenticated using (
  es_admin() or exists(select 1 from participantes_temporada p where p.id = participante_id and p.usuario_id = auth.uid())
);
create policy banco_lectura on datos_bancarios for select using (true);
create policy banco_admin on datos_bancarios for update to authenticated using (es_admin()) with check (es_admin());

create function public.handle_new_user() returns trigger language plpgsql security definer
set search_path = public, pg_temp as $$
declare temporada uuid;
begin
  insert into perfiles(id, nombre_completo, username) values (
    new.id, trim(new.raw_user_meta_data->>'nombre_completo'), lower(trim(new.raw_user_meta_data->>'username'))
  );
  temporada := nullif(new.raw_user_meta_data->>'temporada_id','')::uuid;
  if temporada is not null then
    perform 1 from temporadas where id = temporada and estado = 'activa' for share;
    if not found then raise exception 'La temporada no admite inscripciones'; end if;
    insert into participantes_temporada(temporada_id, usuario_id, estado_pago, referencia_pago)
    values(
      temporada,
      new.id,
      case when coalesce(new.raw_user_meta_data->>'reportar_pago','false') = 'true'
        and length(trim(coalesce(new.raw_user_meta_data->>'referencia_pago',''))) between 3 and 200 then 'revision' else 'pendiente' end,
      case when coalesce(new.raw_user_meta_data->>'reportar_pago','false') = 'true'
        and length(trim(coalesce(new.raw_user_meta_data->>'referencia_pago',''))) between 3 and 200
        then trim(coalesce(new.raw_user_meta_data->>'referencia_pago','')) else '' end
    );
  end if;
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

create function public.nfl_inscribir(p_temporada uuid) returns uuid language plpgsql security definer
set search_path = public, pg_temp as $$
declare resultado uuid;
begin
  if auth.uid() is null then raise exception 'Inicia sesión'; end if;
  perform 1 from temporadas where id = p_temporada and estado = 'activa' for share;
  if not found then raise exception 'La temporada no admite inscripciones'; end if;
  insert into participantes_temporada(temporada_id, usuario_id) values(p_temporada, auth.uid())
  on conflict(temporada_id,usuario_id) do nothing;
  select id into resultado from participantes_temporada where temporada_id = p_temporada and usuario_id = auth.uid();
  return resultado;
end;
$$;

create function public.nfl_reportar_pago(p_participante uuid, p_referencia text) returns void language plpgsql security definer
set search_path = public, pg_temp as $$
begin
  if length(trim(coalesce(p_referencia,''))) not between 3 and 200 then raise exception 'Indica la referencia de tu transferencia'; end if;
  update participantes_temporada set estado_pago = 'revision', referencia_pago = trim(p_referencia), actualizado_el = now()
  where id = p_participante and usuario_id = auth.uid() and estado_pago <> 'pagado';
  if not found then raise exception 'No se puede reportar este pago'; end if;
end;
$$;

create function public.nfl_guardar_temporada(p_datos jsonb) returns uuid language plpgsql security definer
set search_path = public, pg_temp as $$
declare resultado uuid;
begin
  if not es_admin() then raise exception 'Requiere administrador'; end if;
  resultado := coalesce(nullif(p_datos->>'id','')::uuid, gen_random_uuid());
  insert into temporadas(id,nombre,anio,cuota,fecha_limite_pago,premio_semanal,premio_primero,premio_segundo,premio_tercero)
  values(resultado, p_datos->>'nombre',(p_datos->>'anio')::integer,2500,(p_datos->>'fecha_limite_pago')::timestamptz,500,
    nullif(p_datos->>'premio_primero','')::numeric,nullif(p_datos->>'premio_segundo','')::numeric,nullif(p_datos->>'premio_tercero','')::numeric)
  on conflict(id) do update set nombre=excluded.nombre, fecha_limite_pago=excluded.fecha_limite_pago,
    premio_primero=excluded.premio_primero,premio_segundo=excluded.premio_segundo,premio_tercero=excluded.premio_tercero;
  return resultado;
end;
$$;

create function public.nfl_crear_semana(p_datos jsonb, p_juegos jsonb) returns uuid language plpgsql security definer
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
    insert into juegos(semana_id,equipo_visitante,equipo_local,fecha_partido,desempate)
    values(resultado,trim(juego->>'equipo_visitante'),trim(juego->>'equipo_local'),(juego->>'fecha_partido')::timestamptz,coalesce((juego->>'desempate')::boolean,false));
  end loop;
  if exists(select equipo from (
    select equipo_local equipo from juegos where semana_id=resultado union all select equipo_visitante from juegos where semana_id=resultado
  ) t group by equipo having count(*)>1) then raise exception 'Un equipo no puede jugar dos veces en una semana'; end if;
  return resultado;
end;
$$;

create function public.nfl_guardar_pronosticos(p_semana uuid, p_elecciones jsonb, p_underdog uuid, p_total integer)
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
  if not exists(select 1 from juegos where id=p_underdog and semana_id=p_semana and estado<>'cancelado') then raise exception 'Elige tu underdog'; end if;
  insert into pronosticos_semanales(semana_id,participante_id,elecciones,underdog_juego_id,underdog_eleccion,total_desempate)
  values(p_semana,participante,p_elecciones,p_underdog,p_elecciones->>p_underdog::text,p_total)
  on conflict(semana_id,participante_id) do update set elecciones=excluded.elecciones,underdog_juego_id=excluded.underdog_juego_id,
    underdog_eleccion=excluded.underdog_eleccion,total_desempate=excluded.total_desempate,actualizado_el=now()
  returning id into resultado;
  return resultado;
end;
$$;

create function public.nfl_guardar_resultados(p_semana uuid, p_resultados jsonb) returns void language plpgsql security definer
set search_path = public, pg_temp as $$
declare item jsonb; semana semanas;
begin
  if not es_admin() then raise exception 'Requiere administrador'; end if;
  select * into semana from semanas where id=p_semana for update;
  if not found or semana.estado='finalizada' then raise exception 'Semana no editable'; end if;
  if now()<semana.fecha_cierre then raise exception 'Espera al cierre de pronósticos'; end if;
  if jsonb_typeof(p_resultados) is distinct from 'array' or jsonb_array_length(p_resultados) not between 1 and 16 then raise exception 'Resultados inválidos'; end if;
  for item in select value from jsonb_array_elements(p_resultados) loop
    update juegos set estado=item->>'estado',puntos_visitante=nullif(item->>'puntos_visitante','')::integer,
      puntos_local=nullif(item->>'puntos_local','')::integer where id=(item->>'id')::uuid and semana_id=p_semana;
    if not found then raise exception 'El partido no pertenece a esta semana'; end if;
  end loop;
end;
$$;

create function public.nfl_participantes(p_temporada uuid) returns table(
  id uuid, usuario_id uuid, nombre_completo text, username text, email text, telefono text, estado_pago text,
  referencia_pago text, notas_admin text, pagado_el timestamptz, creado_el timestamptz
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not es_admin() then raise exception 'Requiere administrador'; end if;
  return query select p.id,p.usuario_id,f.nombre_completo,f.username,u.email::text,p.telefono,p.estado_pago,
    p.referencia_pago,p.notas_admin,p.pagado_el,p.creado_el
    from participantes_temporada p join perfiles f on f.id=p.usuario_id join auth.users u on u.id=p.usuario_id
    where p.temporada_id=p_temporada order by f.nombre_completo;
end;
$$;

create function public.nfl_actualizar_participante(p_id uuid,p_nombre text,p_telefono text,p_notas text,p_pagado boolean)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare participante participantes_temporada;
begin
  if not es_admin() then raise exception 'Requiere administrador'; end if;
  select * into participante from participantes_temporada where id=p_id for update;
  if not found then raise exception 'Participante no encontrado'; end if;
  update perfiles set nombre_completo=trim(p_nombre) where id=participante.usuario_id;
  update participantes_temporada set telefono=p_telefono, notas_admin=p_notas,
    estado_pago=case when p_pagado then 'pagado' when estado_pago='pagado' then 'pendiente' else estado_pago end,
    pagado_el=case when p_pagado then coalesce(pagado_el,now()) else null end,
    revisado_por=auth.uid(),actualizado_el=now() where id=p_id;
end;
$$;

create view public.nfl_base as
select q.id, q.semana_id, s.temporada_id, q.participante_id, f.username,
  count(*) filter(where j.estado='finalizado' and
    q.elecciones->>j.id::text = case when j.puntos_local>j.puntos_visitante then 'L' when j.puntos_visitante>j.puntos_local then 'V' end)::integer as aciertos,
  coalesce(max(case when j.id=q.underdog_juego_id and j.estado='finalizado' and
    q.underdog_eleccion=case when j.puntos_local>j.puntos_visitante then 'L' when j.puntos_visitante>j.puntos_local then 'V' end then 2 else 0 end),0) as bono_underdog,
  case when bool_and(j.estado in ('finalizado','cancelado')) then
    max(case when j.desempate and j.estado='finalizado' then abs(q.total_desempate-j.puntos_local-j.puntos_visitante) end)
    end as diferencia,
  bool_and(j.estado in ('finalizado','cancelado')) as completa
from pronosticos_semanales q join semanas s on s.id=q.semana_id join juegos j on j.semana_id=s.id
join participantes_temporada p on p.id=q.participante_id join perfiles f on f.id=p.usuario_id
where s.fecha_cierre<=now()
group by q.id,s.temporada_id,f.username;

create view public.nfl_puntos as
with base as (select *,aciertos+bono_underdog as puntos_base from nfl_base),
grupos as (select *,count(*) over(partition by semana_id,puntos_base) as empatados,
  min(diferencia) over(partition by semana_id,puntos_base) as minima from base),
candidatos as (select *,count(*) filter(where diferencia=minima) over(partition by semana_id,puntos_base) as cercanos from grupos)
select id,semana_id,temporada_id,participante_id,username,aciertos,bono_underdog,puntos_base,diferencia,completa,
  case when empatados>1 and cercanos=1 and diferencia=minima then 1 else 0 end as bono_desempate,
  puntos_base+case when empatados>1 and cercanos=1 and diferencia=minima then 1 else 0 end as puntos,
  (completa and empatados>1 and ((cercanos>1 and diferencia=minima) or diferencia is null)) as empate_pendiente
from candidatos;

create view public.nfl_ranking_semanal as
select *,rank() over(partition by semana_id order by puntos desc) as posicion from nfl_puntos;

create view public.nfl_ranking_temporada as
with totales as (
select p.temporada_id,p.id as participante_id,f.username,count(r.id)::integer as semanas_jugadas,
  coalesce(sum(r.aciertos),0)::integer as aciertos,coalesce(sum(r.bono_underdog),0)::integer as bono_underdog,
  coalesce(sum(r.bono_desempate),0)::integer as bono_desempate,coalesce(sum(r.puntos),0)::integer as puntos,
  coalesce(bool_or(r.empate_pendiente),false) as empate_pendiente
from participantes_temporada p join perfiles f on f.id=p.usuario_id left join nfl_puntos r on r.participante_id=p.id
group by p.id,f.username)
select *,rank() over(partition by temporada_id order by puntos desc) as posicion from totales;

revoke all on nfl_base,nfl_puntos,nfl_ranking_semanal,nfl_ranking_temporada from anon,authenticated;
grant select on nfl_ranking_semanal,nfl_ranking_temporada to anon,authenticated;

create function public.nfl_registros_semana(p_semana uuid) returns table(
  id uuid,participante_id uuid,username text,elecciones jsonb,underdog_juego_id uuid,underdog_eleccion text,total_desempate integer,actualizado_el timestamptz
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not es_admin() and not exists(select 1 from semanas where semanas.id=p_semana and fecha_cierre<=now()) then
    raise exception 'Los pronósticos se publican al cierre';
  end if;
  return query select q.id,q.participante_id,f.username,q.elecciones,q.underdog_juego_id,q.underdog_eleccion,q.total_desempate,q.actualizado_el
  from pronosticos_semanales q join participantes_temporada p on p.id=q.participante_id join perfiles f on f.id=p.usuario_id
  where q.semana_id=p_semana order by f.username;
end;
$$;

create function public.nfl_finalizar(p_semana uuid default null,p_temporada uuid default null) returns void language plpgsql security definer
set search_path = public, pg_temp as $$
begin
  if not es_admin() then raise exception 'Requiere administrador'; end if;
  if p_semana is not null then
    perform 1 from semanas where id=p_semana and fecha_cierre<=now() for update;
    if not found then raise exception 'La semana no ha cerrado'; end if;
    if exists(select 1 from juegos where semana_id=p_semana and estado not in ('finalizado','cancelado')) then raise exception 'Faltan resultados'; end if;
    update semanas set estado='finalizada' where id=p_semana;
  elsif p_temporada is not null then
    perform 1 from temporadas where id=p_temporada for update;
    if not found then raise exception 'Temporada no encontrada'; end if;
    if not exists(select 1 from semanas where temporada_id=p_temporada) or exists(select 1 from semanas where temporada_id=p_temporada and estado<>'finalizada') then
      raise exception 'Finaliza todas las semanas primero';
    end if;
    update temporadas set estado='finalizada' where id=p_temporada;
  else raise exception 'Indica semana o temporada'; end if;
end;
$$;

revoke execute on function es_admin(),handle_new_user(),nfl_inscribir(uuid),nfl_reportar_pago(uuid,text),nfl_guardar_temporada(jsonb),
  nfl_crear_semana(jsonb,jsonb),nfl_guardar_pronosticos(uuid,jsonb,uuid,integer),nfl_guardar_resultados(uuid,jsonb),nfl_participantes(uuid),
  nfl_actualizar_participante(uuid,text,text,text,boolean),nfl_registros_semana(uuid),nfl_finalizar(uuid,uuid) from public,anon,authenticated;
grant execute on function es_admin(),nfl_inscribir(uuid),nfl_reportar_pago(uuid,text),nfl_guardar_temporada(jsonb),
  nfl_crear_semana(jsonb,jsonb),nfl_guardar_pronosticos(uuid,jsonb,uuid,integer),nfl_guardar_resultados(uuid,jsonb),nfl_participantes(uuid),
  nfl_actualizar_participante(uuid,text,text,text,boolean),nfl_finalizar(uuid,uuid) to authenticated;
grant execute on function nfl_registros_semana(uuid),es_admin() to anon,authenticated;
grant usage on schema public to anon, authenticated;
commit;
