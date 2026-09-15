<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { obtenerSemana, obtenerTemporadaActiva, rankingSemanal, rankingTemporada } from '@/services/nflService';

const route = useRoute();
const temporada = ref(null);
const semana = ref(null);
const filas = ref([]);
const error = ref('');
const esSemana = computed(() => Boolean(route.params.semanaId));

async function cargar() {
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
}
onMounted(cargar);
watch(() => route.fullPath, cargar);
</script>

<template>
  <main class="page-shell max-w-4xl">
    <header class="rounded-3xl bg-quiniela-azulOscuro p-6 text-white shadow-lg sm:p-8"><p class="text-xs font-bold uppercase tracking-[0.2em] text-blue-200">Clasificación</p><h1 class="mt-1 text-3xl font-bold">{{ esSemana ? semana?.nombre : temporada?.nombre }}</h1><p class="mt-2 text-blue-100">{{ esSemana ? 'Premio semanal: $500' : 'Resultados acumulados de la temporada' }}</p></header>
    <p v-if="error" class="rounded-xl border border-red-200 bg-red-50 p-4 text-red-700">{{ error }}</p>
    <div v-else class="overflow-x-auto rounded-2xl bg-white shadow-sm">
      <table class="w-full min-w-[620px] text-sm"><thead class="bg-gray-100 text-left text-gray-600"><tr><th class="p-3">Posición</th><th class="p-3">Participante</th><th v-if="!esSemana" class="p-3 text-right">Semanas</th><th class="p-3 text-right">Aciertos</th><th class="p-3 text-right">Underdog</th><th v-if="esSemana" class="p-3 text-right">Desempate</th><th class="p-3 text-right">Puntos</th></tr></thead>
        <tbody><tr v-for="fila in filas" :key="fila.id ?? fila.participante_id" class="border-t"><td class="p-3 font-bold" :class="fila.posicion <= 3 ? 'text-quiniela-rojo' : ''">{{ fila.posicion }}</td><td class="p-3 font-semibold">@{{ fila.username }}<span v-if="fila.empate_pendiente" class="ml-2 rounded bg-amber-100 px-2 py-1 text-xs text-amber-800">Empate pendiente</span></td><td v-if="!esSemana" class="p-3 text-right">{{ fila.semanas_jugadas }}</td><td class="p-3 text-right">{{ fila.aciertos }}</td><td class="p-3 text-right">+{{ fila.bono_underdog }}</td><td v-if="esSemana" class="p-3 text-right">+{{ fila.bono_desempate }}</td><td class="p-3 text-right text-lg font-bold text-quiniela-azul">{{ fila.puntos }}</td></tr></tbody>
      </table>
      <p v-if="!filas.length" class="p-8 text-center text-gray-500">Aún no hay resultados disponibles.</p>
    </div>
  </main>
</template>
