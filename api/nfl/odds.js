import { ErrorHttp, requireAdmin } from '../_lib/auth.js';
import { obtenerUnderdogs } from '../_lib/nfl/theOddsApi.js';
import { getSupabaseAdmin } from '../_lib/supabaseAdmin.js';

export default async function handler(req, res) {
  try {
    await requireAdmin(req);
    if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido' });
    const weekId = req.body?.weekId;
    if (!/^[0-9a-f-]{36}$/i.test(String(weekId ?? ''))) throw new ErrorHttp(400, 'Semana inválida');
    const supabase = getSupabaseAdmin();
    const { data: semana, error: semanaError } = await supabase.from('semanas').select('estado, fecha_cierre').eq('id', weekId).maybeSingle();
    if (semanaError) throw semanaError;
    if (!semana) throw new ErrorHttp(404, 'Semana no encontrada');
    if (semana.estado === 'finalizada') throw new ErrorHttp(409, 'La semana ya es de solo consulta');
    if (new Date(semana.fecha_cierre) <= new Date()) throw new ErrorHttp(409, 'La semana ya cerró y sus momios no se pueden cambiar');
    const { data: juegos, error: juegosError } = await supabase.from('juegos').select('id, equipo_visitante, equipo_local, fecha_partido, estado').eq('semana_id', weekId).neq('estado', 'cancelado').order('fecha_partido');
    if (juegosError) throw juegosError;
    const resultados = await obtenerUnderdogs(juegos ?? []);
    const actualizables = resultados.filter((resultado) => resultado.underdog);
    for (const resultado of actualizables) {
      const { error } = await supabase.from('juegos').update({ underdog_lado: resultado.underdog, underdog_fuente: 'momios', underdog_actualizado_el: new Date().toISOString() }).eq('id', resultado.gameId).eq('semana_id', weekId);
      if (error) throw error;
    }
    return res.status(200).json({ checked: resultados.length, updated: actualizables.length, unmatched: resultados.filter((resultado) => !resultado.underdog).map((resultado) => resultado.gameId) });
  } catch (error) {
    console.error('nfl/odds:', error.message);
    return res.status(error instanceof ErrorHttp ? error.status : 500).json({ error: error.message });
  }
}
