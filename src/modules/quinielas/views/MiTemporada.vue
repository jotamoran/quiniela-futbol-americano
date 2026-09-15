<script setup>
import { computed, onMounted, ref } from 'vue';
import { alertaError, alertaExito } from '@/lib/alertas';
import { fechaHoraCDMX, fechaCortaCDMX } from '@/lib/fechas';
import { listarSemanas, obtenerParticipacion, obtenerTemporadaActiva, rankingTemporada, reportarPago } from '@/services/nflService';

const temporada = ref(null);
const participacion = ref(null);
const semanas = ref([]);
const ranking = ref([]);
const referencia = ref('');
const cargando = ref(true);
const reportando = ref(false);
const miRanking = computed(() => ranking.value.find(r => r.participante_id === participacion.value?.id));

async function cargar() {
  temporada.value = await obtenerTemporadaActiva();
  if (!temporada.value) return;
  [participacion.value, semanas.value, ranking.value] = await Promise.all([
    obtenerParticipacion(temporada.value.id), listarSemanas(temporada.value.id), rankingTemporada(temporada.value.id),
  ]);
}

async function enviarPago() {
  reportando.value = true;
  try {
    await reportarPago(participacion.value.id, referencia.value);
    referencia.value = '';
    await cargar();
    await alertaExito('Pago enviado a revisión');
  } catch (e) { await alertaError(e, 'No se pudo reportar el pago'); }
  finally { reportando.value = false; }
}

onMounted(async () => {
  try { await cargar(); } catch (e) { await alertaError(e, 'No se pudo cargar tu temporada'); }
  finally { cargando.value = false; }
});
</script>

<template>
  <main class="page-shell max-w-5xl">
    <header><p class="eyebrow">Mi cuenta</p><h1 class="page-title">Mi temporada</h1><p class="page-description">Pronósticos, puntos y pago de tu inscripción.</p></header>
    <p v-if="cargando" class="empty-state">Cargando…</p>
    <p v-else-if="!temporada" class="empty-state">No hay una temporada activa.</p>
    <template v-else>
      <section class="grid gap-3 sm:grid-cols-3">
        <div class="rounded-2xl bg-quiniela-azulOscuro p-5 text-white"><p class="text-sm text-blue-100">Temporada</p><strong class="text-xl">{{ temporada.nombre }}</strong></div>
        <div class="rounded-2xl bg-white p-5 shadow-sm"><p class="text-sm text-gray-500">Puntos acumulados</p><strong class="text-2xl text-quiniela-azul">{{ miRanking?.puntos ?? 0 }}</strong></div>
        <div class="rounded-2xl bg-white p-5 shadow-sm"><p class="text-sm text-gray-500">Posición general</p><strong class="text-2xl text-quiniela-rojo">{{ miRanking?.posicion ?? '—' }}</strong></div>
      </section>
      <section class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div><h2 class="font-bold text-quiniela-azulOscuro">Pago de temporada</h2><p class="text-sm text-gray-500">Cuota: ${{ Number(temporada.cuota).toLocaleString('es-MX') }} · límite {{ fechaCortaCDMX(temporada.fecha_limite_pago) }}</p></div>
          <span class="rounded-full px-3 py-1 text-sm font-bold" :class="participacion?.estado_pago === 'pagado' ? 'bg-green-100 text-green-800' : participacion?.estado_pago === 'revision' ? 'bg-blue-100 text-blue-800' : 'bg-amber-100 text-amber-800'">{{ participacion?.estado_pago === 'pagado' ? 'Pagado' : participacion?.estado_pago === 'revision' ? 'En revisión' : 'Pendiente' }}</span>
        </div>
        <form v-if="participacion && participacion.estado_pago === 'pendiente'" @submit.prevent="enviarPago" class="mt-4 flex flex-col gap-2 sm:flex-row">
          <label for="referencia-pago" class="sr-only">Referencia o últimos dígitos de transferencia</label>
          <input id="referencia-pago" v-model="referencia" required minlength="3" maxlength="200" class="form-control mt-0 flex-1" placeholder="Referencia o últimos dígitos de transferencia" />
          <button :disabled="reportando" class="rounded-xl bg-quiniela-rojo px-5 py-2 font-bold text-white disabled:opacity-50">{{ reportando ? 'Enviando…' : 'Reportar pago' }}</button>
        </form>
      </section>
      <section><div class="mb-3 flex items-end justify-between"><div><p class="eyebrow">Calendario</p><h2 class="text-xl font-bold text-quiniela-azulOscuro">Semanas</h2></div><router-link :to="{ name: 'clasificacion-temporada' }" class="text-sm font-semibold text-quiniela-azul">Ver tabla general</router-link></div>
        <div class="grid gap-3 sm:grid-cols-2">
          <article v-for="semana in semanas" :key="semana.id" class="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
            <div class="flex items-center justify-between"><strong>{{ semana.nombre }}</strong><span class="text-xs text-gray-500">Semana {{ semana.numero }}</span></div>
            <p class="mt-1 text-sm text-gray-500">Cierre: {{ fechaHoraCDMX(semana.fecha_cierre) }} · CDMX</p>
            <div class="mt-3 flex gap-2"><router-link :to="{ name: 'llenar-quiniela', params: { semanaId: semana.id } }" class="rounded-lg bg-quiniela-azul px-3 py-2 text-sm font-bold text-white">Pronósticos</router-link><router-link :to="{ name: 'clasificacion-semana', params: { semanaId: semana.id } }" class="rounded-lg border border-gray-300 px-3 py-2 text-sm font-semibold text-quiniela-azul">Tabla</router-link></div>
          </article>
        </div>
        <p v-if="!semanas.length" class="empty-state">Todavía no hay semanas publicadas.</p>
      </section>
    </template>
  </main>
</template>
