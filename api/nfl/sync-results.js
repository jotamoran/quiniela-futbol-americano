import { ErrorHttp, requireAdmin } from '../_lib/auth.js';
import { getEventResults, NFL_PROVIDER } from '../_lib/nfl/theSportsDb.js';
import { getSupabaseAdmin } from '../_lib/supabaseAdmin.js';

export default async function handler(req, res) {
  try {
    await requireAdmin(req);
    if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido' });
    const weekId = req.body?.weekId;
    if (!/^[0-9a-f-]{36}$/i.test(String(weekId ?? ''))) throw new ErrorHttp(400, 'Semana inválida');

    const supabase = getSupabaseAdmin();
    const { data: games, error } = await supabase.from('juegos')
      .select('id, external_event_id')
      .eq('semana_id', weekId)
      .eq('provider', NFL_PROVIDER)
      .not('external_event_id', 'is', null)
      .neq('estado', 'cancelado');
    if (error) throw error;

    const results = await getEventResults((games ?? []).map((game) => game.external_event_id));
    let updated = 0;
    for (const game of games ?? []) {
      const result = results.get(String(game.external_event_id));
      if (!result) continue;
      const { error: updateError } = await supabase.from('juegos').update({
        puntos_local: result.homeScore,
        puntos_visitante: result.awayScore,
        estado: 'finalizado',
      }).eq('id', game.id).eq('semana_id', weekId);
      if (updateError) throw updateError;
      updated += 1;
    }
    return res.status(200).json({ checked: games?.length ?? 0, updated });
  } catch (error) {
    console.error('nfl/sync-results:', error.message);
    return res.status(error instanceof ErrorHttp ? error.status : 500).json({ error: error.message });
  }
}
