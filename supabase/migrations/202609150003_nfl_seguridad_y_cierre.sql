begin;

-- Un partido en vivo puede todavía no tener marcador; solo un finalizado lo exige.
alter table public.juegos drop constraint if exists juegos_estado_check;
alter table public.juegos add constraint juegos_estado_check
  check (estado <> 'finalizado' or (puntos_visitante is not null and puntos_local is not null));

-- Refuerza el cierre cinco minutos antes del primer partido.
create or replace function public.validar_cierre_semana()
returns trigger
language plpgsql
set search_path = public, pg_temp as $$
declare primer_partido timestamptz;
begin
  if new.estado = 'abierta' then
    select min(fecha_partido) into primer_partido
    from juegos
    where semana_id = new.id and estado <> 'cancelado';
    if primer_partido is not null and new.fecha_cierre > primer_partido - interval '5 minutes' then
      raise exception 'El cierre debe quedar al menos cinco minutos antes del primer partido';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists validar_cierre_semana_trigger on public.semanas;
create trigger validar_cierre_semana_trigger
before insert or update of fecha_cierre, estado on public.semanas
for each row execute function public.validar_cierre_semana();

create or replace function public.validar_juego_antes_del_cierre()
returns trigger
language plpgsql
set search_path = public, pg_temp as $$
declare semana_actual public.semanas%rowtype; primer_partido timestamptz;
begin
  select * into semana_actual from public.semanas where id = new.semana_id;
  if found and semana_actual.estado = 'abierta' and new.estado <> 'cancelado' then
    select min(fecha_partido) into primer_partido
    from public.juegos
    where semana_id = new.semana_id and estado <> 'cancelado' and id is distinct from new.id;
    primer_partido := least(coalesce(primer_partido, new.fecha_partido), new.fecha_partido);
    if semana_actual.fecha_cierre > primer_partido - interval '5 minutes' then
      raise exception 'El cierre debe quedar al menos cinco minutos antes del primer partido';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists validar_juego_antes_del_cierre_trigger on public.juegos;
create trigger validar_juego_antes_del_cierre_trigger
before insert or update of semana_id, fecha_partido, estado on public.juegos
for each row execute function public.validar_juego_antes_del_cierre();

-- Una temporada finalizada y sus semanas quedan en modo histórico.
create or replace function public.proteger_temporada_historica()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp as $$
begin
  if old.estado = 'finalizada' then
    raise exception 'La temporada ya es de solo consulta';
  end if;
  if tg_op = 'delete' then return old; end if;
  return new;
end;
$$;

drop trigger if exists proteger_temporada_historica_trigger on public.temporadas;
create trigger proteger_temporada_historica_trigger
before update or delete on public.temporadas
for each row execute function public.proteger_temporada_historica();

-- Una semana finalizada y sus partidos quedan en modo histórico.
create or replace function public.proteger_semana_historica()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp as $$
begin
  if old.estado = 'finalizada' then
    raise exception 'La semana ya es de solo consulta';
  end if;
  if tg_op = 'delete' then return old; end if;
  return new;
end;
$$;

drop trigger if exists proteger_semana_historica_trigger on public.semanas;
create trigger proteger_semana_historica_trigger
before update or delete on public.semanas
for each row execute function public.proteger_semana_historica();

create or replace function public.proteger_juego_historico()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp as $$
declare estado_semana text;
begin
  select estado into estado_semana from public.semanas where id = old.semana_id;
  if estado_semana = 'finalizada' then
    raise exception 'Los partidos de una semana finalizada son de solo consulta';
  end if;
  if tg_op = 'update' and new.semana_id is distinct from old.semana_id then
    select estado into estado_semana from public.semanas where id = new.semana_id;
    if estado_semana = 'finalizada' then
      raise exception 'Los partidos de una semana finalizada son de solo consulta';
    end if;
  end if;
  if tg_op = 'delete' then return old; end if;
  return new;
end;
$$;

drop trigger if exists proteger_juego_historico_trigger on public.juegos;
create trigger proteger_juego_historico_trigger
before update or delete on public.juegos
for each row execute function public.proteger_juego_historico();

-- Solo se permite reportar el pago durante la vigencia de la temporada.
create or replace function public.nfl_reportar_pago(p_participante uuid, p_referencia text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp as $$
declare estado_temporada text; limite_pago timestamptz;
begin
  if auth.uid() is null then raise exception 'Inicia sesión'; end if;
  if length(trim(coalesce(p_referencia, ''))) not between 3 and 200 then
    raise exception 'Indica la referencia de tu transferencia';
  end if;
  select t.estado, t.fecha_limite_pago into estado_temporada, limite_pago
  from participantes_temporada p join temporadas t on t.id = p.temporada_id
  where p.id = p_participante and p.usuario_id = auth.uid();
  if not found then raise exception 'No se puede reportar este pago'; end if;
  if estado_temporada <> 'activa' or clock_timestamp() > limite_pago then
    raise exception 'La fecha límite de pago ya terminó';
  end if;
  update participantes_temporada
  set estado_pago = 'revision', referencia_pago = trim(p_referencia), actualizado_el = now()
  where id = p_participante and usuario_id = auth.uid() and estado_pago <> 'pagado';
  if not found then raise exception 'No se puede reportar este pago'; end if;
end;
$$;

commit;
