import { ErrorHttp, requireAdmin } from '../_lib/auth.js';
import { searchNflTeams } from '../_lib/nfl/theSportsDb.js';

export default async function handler(req, res) {
  try {
    await requireAdmin(req);
    if (req.method !== 'GET') return res.status(405).json({ error: 'Método no permitido' });
    const search = String(req.query.search ?? '').trim();
    if (search.length < 2 || search.length > 80) throw new ErrorHttp(400, 'Escribe entre 2 y 80 caracteres');
    return res.status(200).json({ teams: await searchNflTeams(search) });
  } catch (error) {
    console.error('nfl/teams:', error.message);
    return res.status(error instanceof ErrorHttp ? error.status : 500).json({ error: error.message });
  }
}
