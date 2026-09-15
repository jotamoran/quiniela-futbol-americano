import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const sql = readFileSync(new URL('../../supabase/migrations/202609140001_nfl.sql', import.meta.url), 'utf8');
const providerSql = readFileSync(new URL('../../supabase/migrations/202609150001_nfl_provider.sql', import.meta.url), 'utf8');
const rulesSql = readFileSync(new URL('../../supabase/migrations/202609150002_reglas_admin.sql', import.meta.url), 'utf8');

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

  it('conserva identificadores externos sin duplicar partidos', () => {
    expect(providerSql).toContain('add column if not exists external_event_id text');
    expect(providerSql).toContain('juegos_semana_provider_evento');
    expect(providerSql).toContain('logo_visitante');
    expect(providerSql).not.toMatch(/drop\s+(table|schema)/i);
  });

  it('deja underdog y desempate bajo control del administrador', () => {
    expect(rulesSql).toContain('add column if not exists underdog boolean');
    expect(rulesSql).toContain('nfl_configurar_juego');
    expect(rulesSql).toContain('juego_underdog_unico');
    expect(rulesSql).toContain('cercanos=1');
    expect(rulesSql).not.toMatch(/drop\s+(table|schema)/i);
  });
});
