begin;

do $$
declare temporada public.temporadas;
begin
  select * into temporada from public.temporadas where estado = 'activa';
  assert found, 'Debe existir una temporada activa inicial';
  assert temporada.cuota = 2500, 'La cuota de temporada debe ser 2500';
  assert temporada.premio_semanal = 500, 'El premio semanal debe ser 500';
  assert temporada.fecha_limite_pago = '2026-09-30 23:59:59-06'::timestamptz, 'La fecha límite inicial no coincide';
end;
$$;

do $$
begin
  assert to_regclass('public.participantes_temporada') is not null, 'Falta participantes_temporada';
  assert to_regclass('public.pronosticos_semanales') is not null, 'Falta pronosticos_semanales';
  assert to_regclass('public.nfl_ranking_semanal') is not null, 'Falta nfl_ranking_semanal';
  assert to_regclass('public.nfl_ranking_temporada') is not null, 'Falta nfl_ranking_temporada';
end;
$$;

rollback;
