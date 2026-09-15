import { createClient } from '@supabase/supabase-js';

let cliente;

export function getSupabaseAdmin() {
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error('Falta configurar Supabase en el servidor');
  }
  if (!cliente) cliente = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
  return cliente;
}
