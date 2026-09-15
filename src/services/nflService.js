import { supabase } from '@/lib/supabase';

export async function obtenerTemporadaActiva() {
  const { data, error } = await supabase.from('temporadas').select('*').eq('estado', 'activa').order('anio', { ascending: false }).limit(1).maybeSingle();
  if (error) throw error;
  return data;
}

export async function obtenerTemporadaActual() {
  const { data, error } = await supabase.from('temporadas').select('*').order('anio', { ascending: false }).limit(1).maybeSingle();
  if (error) throw error;
  return data;
}

export async function obtenerDatosBancariosNFL() {
  const { data, error } = await supabase.from('datos_bancarios').select('banco, clabe, titular').eq('id', 1).maybeSingle();
  if (error) throw error;
  return data;
}

export async function actualizarDatosBancariosNFL({ banco, clabe, titular }) {
  const { error } = await supabase.from('datos_bancarios').update({ banco, clabe, titular, actualizado_el: new Date().toISOString() }).eq('id', 1);
  if (error) throw error;
}

export async function obtenerParticipacion(temporadaId) {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;
  const { data, error } = await supabase.from('participantes_temporada').select('*').eq('temporada_id', temporadaId).eq('usuario_id', user.id).maybeSingle();
  if (error) throw error;
  return data;
}

export async function inscribirse(temporadaId) {
  const { data, error } = await supabase.rpc('nfl_inscribir', { p_temporada: temporadaId });
  if (error) throw error;
  return data;
}

export async function reportarPago(participanteId, referencia) {
  const { error } = await supabase.rpc('nfl_reportar_pago', { p_participante: participanteId, p_referencia: referencia });
  if (error) throw error;
}

export async function listarSemanas(temporadaId) {
  const { data, error } = await supabase.from('semanas').select('*').eq('temporada_id', temporadaId).order('numero');
  if (error) throw error;
  return data ?? [];
}

export async function obtenerSemana(semanaId = null) {
  let consulta = supabase.from('semanas').select('*, temporadas(*)');
  if (semanaId) consulta = consulta.eq('id', semanaId);
  else consulta = consulta.eq('estado', 'abierta').gt('fecha_cierre', new Date().toISOString()).order('numero').limit(1);
  const { data, error } = await consulta.maybeSingle();
  if (error) throw error;
  return data;
}

export async function obtenerJuegos(semanaId) {
  const { data, error } = await supabase.from('juegos').select('*').eq('semana_id', semanaId).order('fecha_partido');
  if (error) throw error;
  return data ?? [];
}

export async function obtenerMiPronostico(semanaId, participanteId) {
  const { data, error } = await supabase.from('pronosticos_semanales').select('*').eq('semana_id', semanaId).eq('participante_id', participanteId).maybeSingle();
  if (error) throw error;
  return data;
}

export async function guardarPronosticos({ semanaId, elecciones, underdogId, total }) {
  const { data, error } = await supabase.rpc('nfl_guardar_pronosticos', {
    p_semana: semanaId,
    p_elecciones: elecciones,
    p_underdog: underdogId,
    p_total: total,
  });
  if (error) throw error;
  return data;
}

export async function rankingSemanal(semanaId) {
  const { data, error } = await supabase.from('nfl_ranking_semanal').select('*').eq('semana_id', semanaId).order('posicion');
  if (error) throw error;
  return data ?? [];
}

export async function rankingTemporada(temporadaId) {
  const { data, error } = await supabase.from('nfl_ranking_temporada').select('*').eq('temporada_id', temporadaId).order('posicion');
  if (error) throw error;
  return data ?? [];
}

export async function registrosSemana(semanaId) {
  const { data, error } = await supabase.rpc('nfl_registros_semana', { p_semana: semanaId });
  if (error) throw error;
  return data ?? [];
}

export async function listarParticipantes(temporadaId) {
  const { data, error } = await supabase.rpc('nfl_participantes', { p_temporada: temporadaId });
  if (error) throw error;
  return data ?? [];
}

export async function actualizarParticipante(participante) {
  const { error } = await supabase.rpc('nfl_actualizar_participante', {
    p_id: participante.id,
    p_nombre: participante.nombre_completo,
    p_telefono: participante.telefono ?? '',
    p_notas: participante.notas_admin ?? '',
    p_pagado: participante.estado_pago === 'pagado',
  });
  if (error) throw error;
}

export async function guardarTemporada(datos) {
  const { data, error } = await supabase.rpc('nfl_guardar_temporada', { p_datos: datos });
  if (error) throw error;
  return data;
}

export async function crearSemana(datos, juegos) {
  const { data, error } = await supabase.rpc('nfl_crear_semana', { p_datos: datos, p_juegos: juegos });
  if (error) throw error;
  return data;
}

export async function guardarResultados(semanaId, resultados) {
  const { error } = await supabase.rpc('nfl_guardar_resultados', { p_semana: semanaId, p_resultados: resultados });
  if (error) throw error;
}

export async function configurarJuego(juegoId, { underdog, cancelado }) {
  const { error } = await supabase.rpc('nfl_configurar_juego', { p_juego: juegoId, p_underdog: underdog, p_cancelado: cancelado });
  if (error) throw error;
}

export async function finalizarSemana(semanaId) {
  const { error } = await supabase.rpc('nfl_finalizar', { p_semana: semanaId, p_temporada: null });
  if (error) throw error;
}

export async function finalizarTemporada(temporadaId) {
  const { error } = await supabase.rpc('nfl_finalizar', { p_semana: null, p_temporada: temporadaId });
  if (error) throw error;
}
