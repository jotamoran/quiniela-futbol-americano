const API_BASE_URL = 'https://www.thesportsdb.com/api/v1/json';
const FINAL_STATUSES = new Set(['FT', 'AET', 'PEN', 'Match Finished', 'Final']);
const LIVE_STATUSES = new Set(['1H', '2H', 'HT', 'ET', 'P', 'Live', 'In Play', 'Half Time']);
const REQUEST_TIMEOUT_MS = 8000;
const MAX_RETRIES = 2;
export const NFL_LEAGUE_ID = '4391';
export const NFL_PROVIDER = 'thesportsdb';

function apiKey() {
  const key = process.env.SPORTSDB_API_KEY?.trim();
  if (key) return key;
  if (process.env.NODE_ENV !== 'production') return '123';
  throw new Error('Falta configurar la clave del servicio deportivo');
}

async function request(endpoint) {
  let ultimoError;
  for (let intento = 0; intento <= MAX_RETRIES; intento += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
    try {
      const response = await fetch(`${API_BASE_URL}/${apiKey()}/${endpoint}`, { signal: controller.signal });
      if (response.status === 429 || response.status >= 500) throw new Error(`Respuesta temporal ${response.status}`);
      if (!response.ok) throw new Error(`El servicio deportivo respondió ${response.status}`);
      return await response.json();
    } catch (error) {
      ultimoError = error.name === 'AbortError' ? new Error('El servicio deportivo tardó demasiado en responder') : error;
      if (intento === MAX_RETRIES) throw ultimoError;
      await new Promise((resolve) => setTimeout(resolve, 250 * (intento + 1)));
    } finally {
      clearTimeout(timeout);
    }
  }
  throw ultimoError;
}

export function normalizeEvent(event) {
  const timestamp = event.strTimestamp || `${event.dateEvent}T${event.strTime || '00:00:00'}`;
  return {
    externalId: String(event.idEvent),
    week: Number(event.intRound) || null,
    date: /(?:Z|[+-]\d{2}:?\d{2})$/.test(timestamp) ? timestamp : `${timestamp}Z`,
    home: { name: event.strHomeTeam, logo: event.strHomeTeamBadge || null },
    away: { name: event.strAwayTeam, logo: event.strAwayTeamBadge || null },
  };
}

export function resultFromEvent(event) {
  const finalizado = FINAL_STATUSES.has(event?.strStatus) || String(event?.strProgress ?? '').toLowerCase() === 'final';
  if (!finalizado) return null;
  const homeScore = Number(event.intHomeScore);
  const awayScore = Number(event.intAwayScore);
  if (!Number.isInteger(homeScore) || !Number.isInteger(awayScore) || homeScore < 0 || awayScore < 0) return null;
  return { homeScore, awayScore };
}

export function estadoFromEvent(event) {
  if (FINAL_STATUSES.has(event?.strStatus) || String(event?.strProgress ?? '').toLowerCase() === 'final') return 'finalizado';
  if (LIVE_STATUSES.has(event?.strStatus) || String(event?.strProgress ?? '').toLowerCase().includes('live')) return 'en_curso';
  return 'pendiente';
}

export async function getWeekEvents(year, week) {
  const payload = await request(`eventsround.php?id=${NFL_LEAGUE_ID}&r=${week}&s=${year}`);
  return (payload.events ?? [])
    .filter((event) => String(event.idLeague) === NFL_LEAGUE_ID)
    .map(normalizeEvent)
    .sort((a, b) => new Date(a.date) - new Date(b.date));
}

export async function getEventResults(ids) {
  const results = new Map();
  await Promise.all([...new Set(ids.map(String))].map(async (id) => {
    const payload = await request(`lookupevent.php?id=${encodeURIComponent(id)}`);
    const event = payload.events?.[0];
    const resultado = resultFromEvent(event);
    const estado = estadoFromEvent(event);
    results.set(id, resultado ? { ...resultado, estado } : { estado });
  }));
  return results;
}

export async function searchNflTeams(search) {
  const payload = await request(`searchteams.php?t=${encodeURIComponent(search)}`);
  return (payload.teams ?? [])
    .filter((team) => team.strSport === 'American Football' && (String(team.idLeague) === NFL_LEAGUE_ID || team.strLeague === 'NFL'))
    .map((team) => ({ id: String(team.idTeam), name: team.strTeam, logo: team.strBadge || team.strTeamBadge || null }))
    .slice(0, 10);
}
