# Quiniela NFL

Plataforma de quinielas NFL por temporada (Vue 3 + Tailwind + Supabase + Vercel).

## Desarrollo local

1. Copia `.env.example` a `.env.local` y llena las variables `VITE_*`.
2. `npm install`
3. `npm run dev`

## Base de datos (Supabase)

1. Instala el [Supabase CLI](https://supabase.com/docs/guides/cli).
2. `npx supabase start` (requiere Docker) para el stack local.
3. `npx supabase db reset` aplica las migraciones y crea la temporada NFL 2026.
4. Para un proyecto real en supabase.com: `npx supabase link` y `npx supabase db push`.
5. Después de registrar la primera cuenta, asígnale el rol de administrador desde el editor SQL: `update public.perfiles set rol = 'admin' where username = 'TU_USUARIO';`.

El antiguo `supabase/estructura_bd.sql` fue retirado para evitar crear por accidente el modelo de fútbol soccer. Las migraciones son la fuente vigente. En una base existente aplica, en orden, `supabase/migrations/202609150001_nfl_provider.sql`, `supabase/migrations/202609150002_reglas_admin.sql` y `supabase/migrations/202609150003_nfl_seguridad_y_cierre.sql`.

La verificación de correo está habilitada y usa exactamente seis dígitos. El proyecto local ya lo define en `supabase/config.toml`; en el proyecto hospedado confirma en Authentication → Email que la confirmación de correo esté activa, **OTP length** sea `6` y la plantilla use el token de Supabase.

## Calendario y resultados NFL

El panel de administración consulta automáticamente el calendario NFL. Desde **Temporada y semanas** se carga una semana por número, se revisan los partidos, se eligen el partido de desempate y el partido underdog, y se publica. Desde **Resultados y registros** se sincronizan los marcadores finales; la captura manual permanece disponible.

Configura `SPORTSDB_API_KEY` solamente en el servidor. La clave pública gratuita `123` funciona para desarrollo; para producción se recomienda una clave propia del servicio automático.

## Pruebas

`npm run test` corre las pruebas unitarias (countdown, balance, reparto de premios).
Las pruebas SQL (`supabase/tests/*.test.sql`) se corren con `psql "$(npx supabase status -o json | jq -r .DB_URL)" -f supabase/tests/<archivo>.sql` tras cada `db reset`.

## Despliegue en Vercel

1. Importa el repo en Vercel.
2. Configura las variables de entorno de `.env.example` (las `VITE_*` y las privadas del servidor) en el proyecto de Vercel.
3. Deploy — `vercel.json` ya define el rewrite SPA y las funciones de `/api`.
