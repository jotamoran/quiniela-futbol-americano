<script setup>
import { onMounted, ref } from 'vue';
import { alertaError, alertaExito } from '@/lib/alertas';
import { guardarResultados, listarSemanas, obtenerJuegos, obtenerTemporadaActiva, registrosSemana } from '@/services/nflService';

const semanas = ref([]);
const semanaId = ref('');
const juegos = ref([]);
const registros = ref([]);
const guardando = ref(false);
async function cargarSemanas() { const temporada = await obtenerTemporadaActiva(); semanas.value = temporada ? await listarSemanas(temporada.id) : []; }
async function cargarSemana() {
  if (!semanaId.value) return;
  juegos.value = (await obtenerJuegos(semanaId.value)).map(j => ({ ...j, puntos_visitante: j.puntos_visitante ?? '', puntos_local: j.puntos_local ?? '' }));
  try { registros.value = await registrosSemana(semanaId.value); } catch { registros.value = []; }
}
async function guardar() {
  guardando.value = true;
  try {
    const resultados = juegos.value.map(j => ({ id: j.id, estado: j.estado, puntos_visitante: j.puntos_visitante, puntos_local: j.puntos_local }));
    await guardarResultados(semanaId.value, resultados); await cargarSemana(); await alertaExito('Resultados guardados');
  } catch (e) { await alertaError(e, 'No se pudieron guardar los resultados'); } finally { guardando.value = false; }
}
onMounted(async () => { try { await cargarSemanas(); } catch (e) { await alertaError(e); } });
</script>

<template>
  <main class="page-shell max-w-5xl">
    <header><p class="eyebrow">Administración</p><h1 class="page-title">Resultados y registros</h1><p class="page-description">Captura marcadores y consulta quién entregó su quiniela.</p></header>
    <label class="form-label max-w-md">Semana<select v-model="semanaId" @change="cargarSemana" class="form-control"><option value="">Selecciona una semana</option><option v-for="semana in semanas" :key="semana.id" :value="semana.id">{{ semana.nombre }}</option></select></label>
    <form v-if="juegos.length" @submit.prevent="guardar" class="space-y-3">
      <article v-for="juego in juegos" :key="juego.id" class="grid gap-3 rounded-2xl bg-white p-4 shadow-sm sm:grid-cols-[1fr_7rem_7rem_10rem] sm:items-end">
        <div><strong>{{ juego.equipo_visitante }} @ {{ juego.equipo_local }}</strong><p v-if="juego.desempate" class="text-xs font-bold text-quiniela-rojo">Partido de desempate</p></div>
        <label class="form-label">Visitante<input v-model="juego.puntos_visitante" type="number" min="0" max="200" class="form-control" /></label><label class="form-label">Local<input v-model="juego.puntos_local" type="number" min="0" max="200" class="form-control" /></label>
        <label class="form-label">Estado<select v-model="juego.estado" class="form-control"><option value="pendiente">Pendiente</option><option value="en_curso">En curso</option><option value="finalizado">Finalizado</option><option value="cancelado">Cancelado</option></select></label>
      </article>
      <button :disabled="guardando" class="w-full rounded-xl bg-quiniela-azul px-5 py-3 font-bold text-white disabled:opacity-50">{{ guardando ? 'Guardando…' : 'Guardar resultados' }}</button>
    </form>
    <section v-if="semanaId" class="rounded-2xl bg-white p-5 shadow-sm"><h2 class="font-bold text-quiniela-azulOscuro">Registros recibidos ({{ registros.length }})</h2><div class="mt-3 flex flex-wrap gap-2"><span v-for="registro in registros" :key="registro.id" class="rounded-full bg-blue-50 px-3 py-1 text-sm font-semibold text-quiniela-azul">@{{ registro.username }}</span></div><p v-if="!registros.length" class="mt-2 text-sm text-gray-500">No hay registros o todavía no ha cerrado la semana.</p></section>
  </main>
</template>
