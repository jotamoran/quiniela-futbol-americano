const API_BASE_URL = 'https://www.thesportsdb.com/api/v1/json';
const FINAL_STATUSES = new Set(['FT', 'AET', 'PEN', 'Match Finished', 'Final']);
export const NFL_LEAGUE_ID = '4391';
export const NFL_PROVIDER = 'thesportsdb';

function apiKey() {
  return process.env.SPORTSDB_API_KEY || '123';
}

async function request(endpoint) {
  const response = await fetch(`${API_BASE_URL}/${apiKey()}/${endpoint}`);
  if (!response.ok) throw new Error(`TheSportsDB respondió ${response.status}`);
  return response.json();
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
    results.set(id, resultFromEvent(payload.events?.[0]));
  }));
  return results;
}
