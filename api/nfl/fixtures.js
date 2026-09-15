import { ErrorHttp, requireAdmin } from '../_lib/auth.js';
import { getWeekEvents } from '../_lib/nfl/theSportsDb.js';

export default async function handler(req, res) {
  try {
    await requireAdmin(req);
    if (req.method !== 'GET') return res.status(405).json({ error: 'Método no permitido' });
    const year = Number(req.query.year);
    const week = Number(req.query.week);
    if (!Number.isInteger(year) || year < 2020 || year > 2100) throw new ErrorHttp(400, 'Año inválido');
    if (!Number.isInteger(week) || week < 1 || week > 30) throw new ErrorHttp(400, 'Semana inválida');
    const games = await getWeekEvents(year, week);
    return res.status(200).json({ games });
  } catch (error) {
    console.error('nfl/fixtures:', error.message);
    return res.status(error instanceof ErrorHttp ? error.status : 500).json({ error: error.message });
  }
}
