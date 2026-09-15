import { describe, expect, it } from 'vitest';
import { normalizeEvent, resultFromEvent } from '../../api/_lib/nfl/theSportsDb.js';
import { determinarUnderdog, emparejarEvento } from '../../api/_lib/nfl/theOddsApi.js';

const event = (status, home, away) => ({
  idEvent: '123', idLeague: '4391', intRound: '7', strLeague: 'NFL',
  strTimestamp: '2026-10-18T17:00:00Z', strHomeTeam: 'Home', strAwayTeam: 'Away',
  strStatus: status, intHomeScore: home, intAwayScore: away,
});

describe('calendario automático NFL', () => {
  it('normaliza partido, semana y orden local/visitante', () => {
    expect(normalizeEvent(event('NS', null, null))).toMatchObject({ externalId: '123', week: 7, home: { name: 'Home' }, away: { name: 'Away' } });
  });

  it.each([['Match Finished', '24', '17', { homeScore: 24, awayScore: 17 }], ['Final', '10', '13', { homeScore: 10, awayScore: 13 }], ['NS', null, null, null]])('interpreta %s', (status, home, away, expected) => {
    expect(resultFromEvent(event(status, home, away))).toEqual(expected);
  });

  it('determina el no favorito por el spread', () => {
    const underdog = determinarUnderdog({ bookmakers: [{ markets: [{ key: 'spreads', outcomes: [
      { name: 'Home', point: -3.5 }, { name: 'Away', point: 3.5 },
    ] }] }] });
    expect(underdog).toBe('Away');
  });

  it('usa la cuota directa cuando no hay spread', () => {
    const underdog = determinarUnderdog({ bookmakers: [{ markets: [{ key: 'h2h', outcomes: [
      { name: 'Home', price: 1.45 }, { name: 'Away', price: 2.8 },
    ] }] }] });
    expect(underdog).toBe('Away');
  });

  it('empareja momios por equipos y hora de inicio', () => {
    const juego = { equipo_visitante: 'Away Team', equipo_local: 'Home Team', fecha_partido: '2026-09-20T18:00:00Z' };
    const resultado = emparejarEvento([{ away_team: 'Away Team', home_team: 'Home Team', commence_time: '2026-09-20T18:05:00Z' }], juego);
    expect(resultado?.home_team).toBe('Home Team');
  });

  it('acepta abreviaturas comunes de equipos', () => {
    const juego = { equipo_visitante: 'LA Chargers', equipo_local: 'NY Giants', fecha_partido: '2026-09-20T18:00:00Z' };
    const resultado = emparejarEvento([{ away_team: 'Los Angeles Chargers', home_team: 'New York Giants', commence_time: '2026-09-20T18:00:00Z' }], juego);
    expect(resultado?.away_team).toBe('Los Angeles Chargers');
  });
});
