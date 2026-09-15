import { describe, expect, it } from 'vitest';
import { normalizeEvent, resultFromEvent } from '../../api/_lib/nfl/theSportsDb.js';

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
});
