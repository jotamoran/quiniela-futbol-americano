<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { obtenerSemana, obtenerTemporadaActiva, rankingSemanal, rankingTemporada } from '@/services/nflService';

const route = useRoute();
const temporada = ref(null);
const semana = ref(null);
const filas = ref([]);
const error = ref('');
const cargando = ref(true);
const esSemana = computed(() => Boolean(route.params.semanaId));

async function cargar() {
  cargando.value = true;
  error.value = '';
  filas.value = [];
  try {
    if (esSemana.value) {
      semana.value = await obtenerSemana(route.params.semanaId);
      temporada.value = semana.value?.temporadas;
      filas.value = await rankingSemanal(route.params.semanaId);
    } else {
      temporada.value = await obtenerTemporadaActiva();
      if (temporada.value) filas.value = await rankingTemporada(temporada.value.id);
    }
  } catch (e) { error.value = e.message; }
  finally { cargando.value = false; }
}
onMounted(cargar);
watch(() => route.fullPath, cargar);
</script>

<template>
  <main class="page-shell max-w-4xl">
    <header class="rounded-3xl bg-quiniela-azulOscuro p-6 text-white shadow-lg sm:p-8"><p class="text-xs font-bold uppercase tracking-[0.2em] text-blue-200">Clasificación</p><h1 class="mt-1 text-2xl font-bold sm:text-3xl">{{ esSemana ? (semana?.nombre ?? 'Tabla semanal') : (temporada?.nombre ?? 'Tabla general') }}</h1><p class="mt-2 text-blue-100">{{ esSemana ? 'Premio semanal: $500' : 'Resultados acumulados de la temporada' }}</p></header>
    <p v-if="cargando" role="status" aria-live="polite" class="empty-state">Cargando clasificación…</p>
    <p v-else-if="error" role="alert" class="rounded-xl border border-red-200 bg-red-50 p-4 text-red-700">{{ error }}</p>
    <div v-else class="rounded-2xl bg-white shadow-sm">
      <div class="divide-y sm:hidden"><article v-for="fila in filas" :key="`movil-${fila.id ?? fila.participante_id}`" class="p-4"><div class="flex items-start justify-between gap-3"><div class="flex min-w-0 items-center gap-3"><span class="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-gray-100 font-bold" :class="fila.posicion <= 3 ? 'text-quiniela-rojo' : 'text-gray-600'">{{ fila.posicion }}</span><div class="min-w-0"><p class="truncate font-bold">@{{ fila.username }}</p><span v-if="fila.empate_pendiente" class="mt-1 inline-block rounded bg-amber-100 px-2 py-1 text-xs text-amber-800">Empate pendiente</span></div></div><strong class="text-xl text-quiniela-azul">{{ fila.puntos }} pts</strong></div><dl class="mt-3 grid grid-cols-3 gap-2 rounded-xl bg-gray-50 p-3 text-center text-xs"><div v-if="!esSemana"><dt class="text-gray-500">Semanas</dt><dd class="mt-1 font-bold">{{ fila.semanas_jugadas }}</dd></div><div><dt class="text-gray-500">Aciertos</dt><dd class="mt-1 font-bold">{{ fila.aciertos }}</dd></div><div><dt class="text-gray-500">Underdog</dt><dd class="mt-1 font-bold">+{{ fila.bono_underdog }}</dd></div><div v-if="esSemana"><dt class="text-gray-500">Desempate</dt><dd class="mt-1 font-bold">+{{ fila.bono_desempate }}</dd></div></dl></article></div>
      <div class="hidden overflow-x-auto sm:block"><table class="w-full min-w-[620px] text-sm"><thead class="bg-gray-100 text-left text-gray-600"><tr><th class="p-3">Posición</th><th class="p-3">Participante</th><th v-if="!esSemana" class="p-3 text-right">Semanas</th><th class="p-3 text-right">Aciertos</th><th class="p-3 text-right">Underdog</th><th v-if="esSemana" class="p-3 text-right">Desempate</th><th class="p-3 text-right">Puntos</th></tr></thead>
        <tbody><tr v-for="fila in filas" :key="fila.id ?? fila.participante_id" class="border-t"><td class="p-3 font-bold" :class="fila.posicion <= 3 ? 'text-quiniela-rojo' : ''">{{ fila.posicion }}</td><td class="p-3 font-semibold">@{{ fila.username }}<span v-if="fila.empate_pendiente" class="ml-2 rounded bg-amber-100 px-2 py-1 text-xs text-amber-800">Empate pendiente</span></td><td v-if="!esSemana" class="p-3 text-right">{{ fila.semanas_jugadas }}</td><td class="p-3 text-right">{{ fila.aciertos }}</td><td class="p-3 text-right">+{{ fila.bono_underdog }}</td><td v-if="esSemana" class="p-3 text-right">+{{ fila.bono_desempate }}</td><td class="p-3 text-right text-lg font-bold text-quiniela-azul">{{ fila.puntos }}</td></tr></tbody>
      </table></div>
      <p v-if="!filas.length" class="p-8 text-center text-gray-500">Aún no hay resultados disponibles.</p>
    </div>
  </main>
</template>
