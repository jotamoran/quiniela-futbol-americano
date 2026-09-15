<script setup>
import { computed, onMounted, ref } from 'vue';
import { alertaError, alertaExito } from '@/lib/alertas';
import { fechaHoraCDMX, fechaCortaCDMX } from '@/lib/fechas';
import { listarSemanas, obtenerParticipacion, obtenerTemporadaActual, rankingTemporada, reportarPago } from '@/services/nflService';

const temporada = ref(null);
const participacion = ref(null);
const semanas = ref([]);
const ranking = ref([]);
const referencia = ref('');
const cargando = ref(true);
const reportando = ref(false);
const miRanking = computed(() => ranking.value.find(r => r.participante_id === participacion.value?.id));
const semanaAbierta = computed(() => semanas.value.find((semana) => semana.estado === 'abierta' && new Date(semana.fecha_cierre) > new Date()));
const pagoVencido = computed(() => temporada.value && new Date(temporada.value.fecha_limite_pago) < new Date());
function semanaPuedeEditar(semana) { return semana.estado === 'abierta' && new Date(semana.fecha_cierre) > new Date(); }
function etiquetaSemana(semana) { return semanaPuedeEditar(semana) ? 'Abierta' : semana.estado === 'finalizada' ? 'Finalizada' : 'Cerrada'; }
function claseSemana(semana) { return semanaPuedeEditar(semana) ? 'bg-green-100 text-green-800' : semana.estado === 'finalizada' ? 'bg-blue-100 text-blue-800' : 'bg-gray-100 text-gray-700'; }

async function cargar() {
  temporada.value = await obtenerTemporadaActual();
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
    <p v-else-if="!temporada" class="empty-state">No hay una temporada disponible.</p>
    <template v-else>
      <section class="grid gap-3 sm:grid-cols-3">
        <div class="rounded-2xl bg-quiniela-azulOscuro p-5 text-white"><p class="text-sm text-blue-100">Temporada</p><strong class="text-xl">{{ temporada.nombre }}</strong></div>
        <div class="rounded-2xl bg-white p-5 shadow-sm"><p class="text-sm text-gray-500">Puntos acumulados</p><strong class="text-2xl text-quiniela-azul">{{ miRanking?.puntos ?? 0 }}</strong></div>
        <div class="rounded-2xl bg-white p-5 shadow-sm"><p class="text-sm text-gray-500">Posición general</p><strong class="text-2xl text-quiniela-rojo">{{ miRanking?.posicion ?? '—' }}</strong></div>
      </section>
      <section v-if="semanaAbierta" class="flex flex-col gap-3 rounded-2xl border border-blue-100 bg-blue-50 p-4 sm:flex-row sm:items-center sm:justify-between sm:p-5"><div><p class="eyebrow">Semana abierta</p><p class="font-bold text-quiniela-azulOscuro">{{ semanaAbierta.nombre }} recibe tus pronósticos hasta {{ fechaHoraCDMX(semanaAbierta.fecha_cierre) }}.</p></div><router-link :to="{ name: 'llenar-quiniela', params: { semanaId: semanaAbierta.id } }" class="inline-flex min-h-11 items-center justify-center rounded-xl bg-quiniela-azul px-5 py-2.5 font-bold text-white">Jugar ahora</router-link></section>
      <section class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div><h2 class="font-bold text-quiniela-azulOscuro">Pago de temporada</h2><p class="text-sm text-gray-500">Cuota: ${{ Number(temporada.cuota).toLocaleString('es-MX') }} · límite {{ fechaCortaCDMX(temporada.fecha_limite_pago) }}</p></div>
          <span class="rounded-full px-3 py-1 text-sm font-bold" :class="!participacion ? 'bg-gray-100 text-gray-700' : participacion.estado_pago === 'pagado' ? 'bg-green-100 text-green-800' : participacion.estado_pago === 'revision' ? 'bg-blue-100 text-blue-800' : 'bg-amber-100 text-amber-800'">{{ !participacion ? 'Sin inscripción' : participacion.estado_pago === 'pagado' ? 'Pagado' : participacion.estado_pago === 'revision' ? 'En revisión' : 'Pendiente' }}</span>
        </div>
        <p v-if="!participacion" class="mt-3 text-sm text-gray-600">Tu cuenta todavía no está inscrita en esta temporada.</p>
        <p v-if="participacion && participacion.estado_pago === 'pendiente' && pagoVencido" class="mt-3 rounded-xl border border-red-200 bg-red-50 p-3 text-sm text-red-800">La fecha límite para reportar el pago ya terminó. Contacta al administrador.</p>
        <form v-else-if="participacion && participacion.estado_pago === 'pendiente'" @submit.prevent="enviarPago" class="mt-4 flex flex-col gap-2 sm:flex-row">
          <label for="referencia-pago" class="sr-only">Referencia o últimos dígitos de transferencia</label>
          <input id="referencia-pago" v-model="referencia" required minlength="3" maxlength="200" class="form-control mt-0 flex-1" placeholder="Referencia o últimos dígitos de transferencia" />
          <button :disabled="reportando" class="rounded-xl bg-quiniela-rojo px-5 py-2 font-bold text-white disabled:opacity-50">{{ reportando ? 'Enviando…' : 'Reportar pago' }}</button>
        </form>
      </section>
      <section><div class="mb-3 flex items-end justify-between"><div><p class="eyebrow">Calendario</p><h2 class="text-xl font-bold text-quiniela-azulOscuro">Semanas</h2></div><router-link :to="{ name: 'clasificacion-temporada' }" class="text-sm font-semibold text-quiniela-azul">Ver tabla general</router-link></div>
        <div class="grid gap-3 sm:grid-cols-2">
          <article v-for="semana in semanas" :key="semana.id" class="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
            <div class="flex flex-wrap items-center justify-between gap-2"><strong>{{ semana.nombre }}</strong><div class="flex items-center gap-2"><span class="text-xs text-gray-500">Semana {{ semana.numero }}</span><span class="rounded-full px-2 py-1 text-xs font-bold" :class="claseSemana(semana)">{{ etiquetaSemana(semana) }}</span></div></div>
            <p class="mt-1 text-sm text-gray-500">Cierre: {{ fechaHoraCDMX(semana.fecha_cierre) }} · CDMX</p>
            <div class="mt-3 flex flex-wrap gap-2"><router-link :to="{ name: 'llenar-quiniela', params: { semanaId: semana.id } }" class="rounded-lg px-3 py-2 text-sm font-bold text-white" :class="semanaPuedeEditar(semana) ? 'bg-quiniela-azul' : 'bg-gray-600'">{{ semanaPuedeEditar(semana) ? 'Pronósticos' : 'Ver pronósticos' }}</router-link><router-link :to="{ name: 'clasificacion-semana', params: { semanaId: semana.id } }" class="rounded-lg border border-gray-300 px-3 py-2 text-sm font-semibold text-quiniela-azul">Tabla</router-link></div>
          </article>
        </div>
        <p v-if="!semanas.length" class="empty-state">Todavía no hay semanas publicadas.</p>
      </section>
    </template>
  </main>
</template>
