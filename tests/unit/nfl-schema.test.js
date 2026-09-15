import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const sql = readFileSync(new URL('../../supabase/migrations/202609140001_nfl.sql', import.meta.url), 'utf8');

describe('contrato del esquema NFL', () => {
  it('crea las entidades de temporada y una temporada inicial', () => {
    for (const entidad of ['temporadas', 'participantes_temporada', 'semanas', 'juegos', 'pronosticos_semanales']) {
      expect(sql).toContain(`create table public.${entidad}`);
    }
    expect(sql).toContain("values ('NFL 2026', 2026, 2500");
    expect(sql).toContain("'2026-09-30 23:59:59-06'");
  });

  it('incluye las tres partes de la puntuación', () => {
    expect(sql).toContain('aciertos+bono_underdog as puntos_base');
    expect(sql).toContain('then 2 else 0');
    expect(sql).toContain('when empatados>1 and cercanos=1');
  });

  it('protege datos privados y no contiene borrados destructivos', () => {
    expect(sql).toContain('alter table participantes_temporada enable row level security');
    expect(sql).toContain('alter table pronosticos_semanales enable row level security');
    expect(sql).not.toMatch(/drop\s+(table|schema)/i);
  });
});
