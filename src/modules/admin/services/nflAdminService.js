import { supabase } from '@/lib/supabase';

async function llamarApi(ruta, opciones = {}) {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) throw new Error('Inicia sesión nuevamente');
  const response = await fetch(`/api/nfl/${ruta}`, {
    ...opciones,
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${session.access_token}`, ...opciones.headers },
  });
  const data = await response.json();
  if (!response.ok) throw new Error(data.error ?? 'Error inesperado');
  return data;
}

export function buscarSemanaNFL(year, week) {
  return llamarApi(`fixtures?${new URLSearchParams({ year, week })}`);
}

export function sincronizarResultadosNFL(weekId) {
  return llamarApi('sync-results', { method: 'POST', body: JSON.stringify({ weekId }) });
}

export function sincronizarMomiosNFL(weekId) {
  return llamarApi('odds', { method: 'POST', body: JSON.stringify({ weekId }) });
}

export function buscarEquiposNFL(search) {
  return llamarApi(`teams?${new URLSearchParams({ search })}`);
}
