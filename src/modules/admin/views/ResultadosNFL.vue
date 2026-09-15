<script setup>
import { onMounted, ref } from 'vue';
import { alertaError, alertaExito, confirmarAccion } from '@/lib/alertas';
import { configurarJuego, guardarResultados, listarSemanas, obtenerJuegos, obtenerTemporadaActiva, registrosSemana } from '@/services/nflService';
import { sincronizarResultadosNFL } from '../services/nflAdminService';

const semanas = ref([]);
const semanaId = ref('');
const juegos = ref([]);
const registros = ref([]);
const guardando = ref(false);
const sincronizando = ref(false);
const configurando = ref('');
async function cargarSemanas() { const temporada = await obtenerTemporadaActiva(); semanas.value = temporada ? await listarSemanas(temporada.id) : []; }
async function cargarSemana() {
  if (!semanaId.value) return;
  juegos.value = (await obtenerJuegos(semanaId.value)).map(j => ({ ...j, puntos_visitante: j.puntos_visitante ?? '', puntos_local: j.puntos_local ?? '' }));
  try { registros.value = await registrosSemana(semanaId.value); } catch { registros.value = []; }
}
async function cambiarJuego(juego, cambio) {
  if (cambio === 'cancelado') {
    const confirmado = await confirmarAccion({ title: juego.estado === 'cancelado' ? 'Reactivar partido' : 'Cancelar partido', text: `${juego.equipo_visitante} @ ${juego.equipo_local}`, confirmText: juego.estado === 'cancelado' ? 'Reactivar' : 'Cancelar', danger: juego.estado !== 'cancelado' });
    if (!confirmado) return;
  }
  configurando.value = juego.id;
  try {
    await configurarJuego(juego.id, { underdog: cambio === 'underdog' ? true : juego.underdog, cancelado: cambio === 'cancelado' ? juego.estado !== 'cancelado' : juego.estado === 'cancelado' });
    await cargarSemana();
    await alertaExito(cambio === 'underdog' ? 'Partido underdog actualizado' : 'Estado del partido actualizado');
  } catch (e) { await alertaError(e, 'No se pudo actualizar el partido'); } finally { configurando.value = ''; }
}
async function guardar() {
  guardando.value = true;
  try {
    const resultados = juegos.value.map(j => ({ id: j.id, estado: j.estado, puntos_visitante: j.puntos_visitante, puntos_local: j.puntos_local }));
    await guardarResultados(semanaId.value, resultados); await cargarSemana(); await alertaExito('Resultados guardados');
  } catch (e) { await alertaError(e, 'No se pudieron guardar los resultados'); } finally { guardando.value = false; }
}
async function sincronizar() {
  sincronizando.value = true;
  try {
    const respuesta = await sincronizarResultadosNFL(semanaId.value);
    await cargarSemana();
    await alertaExito('Resultados sincronizados', `${respuesta.updated} de ${respuesta.checked} partidos actualizados.`);
  } catch (e) { await alertaError(e, 'No se pudieron sincronizar los resultados'); } finally { sincronizando.value = false; }
}
onMounted(async () => { try { await cargarSemanas(); } catch (e) { await alertaError(e); } });
</script>

<template>
  <main class="page-shell max-w-5xl">
    <header><p class="eyebrow">Administración</p><h1 class="page-title">Resultados y registros</h1><p class="page-description">Configura el partido underdog, cancela partidos y actualiza marcadores. El desempate se calcula automáticamente.</p></header>
    <div class="flex flex-col gap-3 sm:flex-row sm:items-end"><label class="form-label min-w-0 max-w-md flex-1">Semana<select v-model="semanaId" @change="cargarSemana" class="form-control"><option value="">Selecciona una semana</option><option v-for="semana in semanas" :key="semana.id" :value="semana.id">{{ semana.nombre }}</option></select></label><button v-if="semanaId" type="button" @click="sincronizar" :disabled="sincronizando || guardando" class="min-h-11 w-full rounded-xl border border-quiniela-azul px-4 py-2 font-semibold text-quiniela-azul disabled:opacity-50 sm:w-auto">{{ sincronizando ? 'Sincronizando…' : 'Actualizar resultados automáticamente' }}</button></div>
    <form v-if="juegos.length" @submit.prevent="guardar" class="space-y-3">
      <article v-for="juego in juegos" :key="juego.id" class="rounded-2xl border bg-white p-4 shadow-sm" :class="juego.estado === 'cancelado' ? 'border-gray-300 bg-gray-50' : juego.underdog ? 'border-red-200' : 'border-transparent'">
        <div class="grid gap-3 sm:grid-cols-[1fr_7rem_7rem_10rem] sm:items-end"><div><div class="flex items-center gap-3"><img v-if="juego.logo_visitante" :src="juego.logo_visitante" alt="" class="h-9 w-9 object-contain" /><strong>{{ juego.equipo_visitante }} @ {{ juego.equipo_local }}</strong><img v-if="juego.logo_local" :src="juego.logo_local" alt="" class="h-9 w-9 object-contain" /></div><div class="mt-2 flex flex-wrap gap-1"><span v-if="juego.desempate" class="rounded-full bg-blue-50 px-2 py-1 text-xs font-bold text-quiniela-azul">Desempate</span><span v-if="juego.underdog" class="rounded-full bg-red-50 px-2 py-1 text-xs font-bold text-quiniela-rojo">Underdog</span><span v-if="juego.estado === 'cancelado'" class="rounded-full bg-gray-200 px-2 py-1 text-xs font-bold text-gray-600">Cancelado</span></div></div>
        <label class="form-label">Visitante<input v-model="juego.puntos_visitante" :disabled="juego.estado === 'cancelado'" type="number" min="0" max="200" class="form-control disabled:bg-gray-100" /></label><label class="form-label">Local<input v-model="juego.puntos_local" :disabled="juego.estado === 'cancelado'" type="number" min="0" max="200" class="form-control disabled:bg-gray-100" /></label>
        <label class="form-label">Estado<select v-model="juego.estado" :disabled="juego.estado === 'cancelado'" class="form-control disabled:bg-gray-100"><option value="pendiente">Pendiente</option><option value="en_curso">En curso</option><option value="finalizado">Finalizado</option><option v-if="juego.estado === 'cancelado'" value="cancelado">Cancelado</option></select></label></div>
        <div class="mt-3 flex flex-col gap-2 border-t border-gray-100 pt-3 sm:flex-row"><button type="button" @click="cambiarJuego(juego, 'underdog')" :disabled="configurando || juego.estado === 'cancelado'" class="min-h-11 rounded-xl border border-quiniela-rojo px-3 py-2 text-sm font-semibold text-quiniela-rojo disabled:opacity-40">{{ juego.underdog ? 'Underdog actual' : 'Marcar como underdog' }}</button><button type="button" @click="cambiarJuego(juego, 'cancelado')" :disabled="Boolean(configurando)" class="min-h-11 rounded-xl border border-gray-300 px-3 py-2 text-sm font-semibold text-gray-700 disabled:opacity-40">{{ juego.estado === 'cancelado' ? 'Reactivar partido' : 'Cancelar partido' }}</button></div>
      </article>
      <button :disabled="guardando" class="w-full rounded-xl bg-quiniela-azul px-5 py-3 font-bold text-white disabled:opacity-50">{{ guardando ? 'Guardando…' : 'Guardar resultados' }}</button>
    </form>
    <section v-if="semanaId" class="rounded-2xl bg-white p-5 shadow-sm"><h2 class="font-bold text-quiniela-azulOscuro">Registros recibidos ({{ registros.length }})</h2><div class="mt-3 flex flex-wrap gap-2"><span v-for="registro in registros" :key="registro.id" class="rounded-full bg-blue-50 px-3 py-1 text-sm font-semibold text-quiniela-azul">@{{ registro.username }}</span></div><p v-if="!registros.length" class="mt-2 text-sm text-gray-500">No hay registros o todavía no ha cerrado la semana.</p></section>
  </main>
</template>
