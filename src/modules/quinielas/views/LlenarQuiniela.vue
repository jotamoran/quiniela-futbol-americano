<script setup>
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router';
import { useAuthStore } from '@/store/auth';
import { useLoginModalStore } from '@/store/loginModal';
import { alertaError, alertaExito, confirmarAccion } from '@/lib/alertas';
import { fechaHoraCDMX } from '@/lib/fechas';
import TarjetaPartido from '../components/TarjetaPartido.vue';
import { guardarPronosticos, inscribirse, obtenerJuegos, obtenerMiPronostico, obtenerParticipacion, obtenerSemana } from '@/services/nflService';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const loginModalStore = useLoginModalStore();
const semana = ref(null);
const juegos = ref([]);
const participacion = ref(null);
const elecciones = ref({});
const underdogId = ref('');
const total = ref('');
const cargando = ref(true);
const guardando = ref(false);
const error = ref('');
const tiempoRestante = ref(null);
let intervalo;
const cerrado = computed(() => !semana.value || new Date(semana.value.fecha_cierre) <= new Date() || semana.value.estado !== 'abierta');
const juegosActivos = computed(() => juegos.value.filter(j => j.estado !== 'cancelado'));
const seleccionados = computed(() => juegosActivos.value.filter(j => elecciones.value[j.id]).length);
const faltantes = computed(() => Math.max(juegosActivos.value.length - seleccionados.value, 0));
const porcentaje = computed(() => juegosActivos.value.length ? Math.round((seleccionados.value / juegosActivos.value.length) * 100) : 0);
const totalValido = computed(() => total.value !== '' && Number.isInteger(Number(total.value)) && Number(total.value) >= 0 && Number(total.value) <= 400);
const momiosDisponibles = computed(() => juegosActivos.value.length > 0 && juegosActivos.value.every((juego) => Boolean(juego.underdog_lado)));
const underdogValido = computed(() => juegosActivos.value.some((juego) => juego.id === underdogId.value));
const completo = computed(() => seleccionados.value === juegosActivos.value.length && underdogValido.value && momiosDisponibles.value && totalValido.value);
const faltantesFormulario = computed(() => {
  if (faltantes.value > 0) return `Faltan ${faltantes.value} selecciones.`;
  if (!momiosDisponibles.value) return 'Faltan momios para identificar algunos no favoritos.';
  if (!underdogValido.value) return 'Elige un partido como tu underdog.';
  if (!totalValido.value) return 'Indica el total del partido de desempate.';
  return 'Todo listo para guardar.';
});
const urgencia = computed(() => {
  if (!tiempoRestante.value || tiempoRestante.value.vencido) return 'cerrada';
  const minutos = tiempoRestante.value.dias * 1440 + tiempoRestante.value.horas * 60 + tiempoRestante.value.minutos;
  if (minutos < 30) return 'critica';
  if (minutos < 120) return 'alta';
  return minutos < 1440 ? 'media' : 'normal';
});
const hayCambiosPendientes = computed(() => Boolean(auth.isLoggedIn && !cerrado.value && (seleccionados.value > 0 || total.value !== '')));

function actualizarTiempo() {
  if (!semana.value) { tiempoRestante.value = null; return; }
  const diferencia = new Date(semana.value.fecha_cierre).getTime() - Date.now();
  const segundos = Math.max(0, Math.floor(diferencia / 1000));
  tiempoRestante.value = {
    vencido: diferencia <= 0,
    dias: Math.floor(segundos / 86400),
    horas: Math.floor((segundos % 86400) / 3600),
    minutos: Math.floor((segundos % 3600) / 60),
    segundos: segundos % 60,
  };
}

function advertirAntesDeSalir(evento) {
  if (!hayCambiosPendientes.value || guardando.value) return;
  evento.preventDefault();
  evento.returnValue = '';
}

async function confirmarSalida() {
  if (!hayCambiosPendientes.value || guardando.value) return true;
  return confirmarAccion({ title: 'Salir de la quiniela', text: 'Perderás los pronósticos que aún no has guardado.', confirmText: 'Salir', danger: true });
}

async function cargar() {
  semana.value = null;
  juegos.value = [];
  participacion.value = null;
  elecciones.value = {};
  total.value = '';
  underdogId.value = '';
  semana.value = await obtenerSemana(route.params.semanaId ?? null);
  if (!semana.value) return;
  juegos.value = await obtenerJuegos(semana.value.id);
  if (!auth.isLoggedIn) return;
  participacion.value = await obtenerParticipacion(semana.value.temporada_id);
  if (!participacion.value && !cerrado.value) participacion.value = { id: await inscribirse(semana.value.temporada_id), estado_pago: 'pendiente' };
  if (!participacion.value) return;
  const existente = await obtenerMiPronostico(semana.value.id, participacion.value.id);
  if (existente) {
    elecciones.value = existente.elecciones;
    underdogId.value = existente.underdog_juego_id;
    total.value = existente.total_desempate;
  }
}

function seleccionarUnderdog(juegoId) {
  if (cerrado.value) return;
  underdogId.value = underdogId.value === juegoId ? '' : juegoId;
}

async function guardar() {
  guardando.value = true;
  try {
    const eleccionesActivas = Object.fromEntries(juegos.value.filter(j => j.estado !== 'cancelado').map(j => [j.id, elecciones.value[j.id]]));
    await guardarPronosticos({ semanaId: semana.value.id, elecciones: eleccionesActivas, underdogId: underdogId.value, total: Number(total.value) });
    await alertaExito('Pronósticos guardados', 'Puedes modificarlos hasta el cierre de la semana.');
    router.push({ name: 'mi-temporada' });
  } catch (e) { await alertaError(e, 'No se pudieron guardar los pronósticos'); }
  finally { guardando.value = false; }
}

onMounted(async () => {
  try { await cargar(); } catch (e) { error.value = e.message; }
  finally { cargando.value = false; }
  actualizarTiempo();
  intervalo = setInterval(actualizarTiempo, 1000);
  window.addEventListener('beforeunload', advertirAntesDeSalir);
});
watch(() => route.params.semanaId, async () => {
  cargando.value = true;
  error.value = '';
  try { await cargar(); } catch (e) { error.value = e.message; }
  finally { cargando.value = false; }
  actualizarTiempo();
});
onBeforeRouteLeave(() => confirmarSalida());
onUnmounted(() => { clearInterval(intervalo); window.removeEventListener('beforeunload', advertirAntesDeSalir); });
</script>

<template>
  <main class="page-shell max-w-4xl" :aria-busy="cargando">
    <header><p class="eyebrow">Quiniela NFL</p><h1 class="page-title">{{ semana?.nombre ?? 'Semana actual' }}</h1><p v-if="semana" class="page-description">Cierra {{ fechaHoraCDMX(semana.fecha_cierre) }} · hora CDMX</p></header>
    <div v-if="cargando" role="status" aria-live="polite" class="grid gap-4 sm:grid-cols-2"><div v-for="n in 4" :key="n" class="h-44 animate-pulse rounded-2xl bg-white shadow-sm"></div></div>
    <p v-else-if="error" role="alert" class="rounded-xl border border-red-200 bg-red-50 p-4 text-red-700">{{ error }}</p>
    <div v-else-if="!semana" class="empty-state"><p>No hay una semana abierta.</p><router-link :to="{ name: 'clasificacion-temporada' }" class="auth-link mt-3 inline-block">Ver clasificación</router-link></div>
    <template v-else>
      <section v-if="tiempoRestante && !cerrado" class="rounded-2xl p-4 text-white shadow-sm" :class="urgencia === 'critica' ? 'bg-quiniela-rojo' : urgencia === 'alta' ? 'bg-orange-600' : 'bg-quiniela-azul'"><div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between"><div><p class="text-xs font-bold uppercase tracking-widest text-white/80">Tiempo para cerrar</p><p class="text-2xl font-bold tabular-nums">{{ tiempoRestante.dias }}d {{ String(tiempoRestante.horas).padStart(2, '0') }}h {{ String(tiempoRestante.minutos).padStart(2, '0') }}m {{ String(tiempoRestante.segundos).padStart(2, '0') }}s</p></div><p class="text-sm text-white/90">Guarda tus pronósticos antes del cierre.</p></div></section>
      <p v-if="hayCambiosPendientes && urgencia === 'critica'" role="status" class="rounded-xl border border-red-200 bg-red-50 p-3 text-sm font-semibold text-red-800">El cierre es inminente. Guarda tu quiniela cuanto antes.</p>
      <div v-if="!auth.isLoggedIn" class="flex flex-col gap-3 rounded-xl border border-blue-200 bg-blue-50 p-4 text-sm text-quiniela-azulOscuro sm:flex-row sm:items-center sm:justify-between"><span>Inicia sesión o crea tu cuenta para guardar tus pronósticos.</span><button type="button" @click="loginModalStore.abrir()" class="min-h-11 rounded-lg bg-quiniela-azul px-4 py-2 font-semibold text-white">Iniciar sesión</button></div>
      <p v-if="auth.isLoggedIn && participacion && participacion.estado_pago !== 'pagado'" class="rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800">Tu pago de temporada está {{ participacion.estado_pago === 'revision' ? 'en revisión' : 'pendiente' }}. Esto no bloquea tu participación durante el plazo de pago.</p>
      <section v-if="auth.isLoggedIn && juegosActivos.length" class="rounded-2xl border border-blue-100 bg-white p-4 shadow-sm sm:p-5" aria-live="polite">
        <div class="flex items-center justify-between gap-3"><div><p class="eyebrow">Tu progreso</p><p class="font-bold text-quiniela-azulOscuro">{{ seleccionados }} de {{ juegosActivos.length }} partidos seleccionados</p></div><strong class="text-lg text-quiniela-azul">{{ porcentaje }}%</strong></div>
        <div class="mt-3 h-2 overflow-hidden rounded-full bg-gray-100" role="progressbar" aria-label="Progreso de pronósticos" :aria-valuenow="porcentaje" aria-valuemin="0" aria-valuemax="100"><div class="h-full rounded-full bg-quiniela-rojo transition-all duration-300" :style="{ width: `${porcentaje}%` }"></div></div>
        <p v-if="faltantes" class="mt-2 text-sm text-gray-500">Te {{ faltantes === 1 ? 'falta' : 'faltan' }} {{ faltantes }} {{ faltantes === 1 ? 'partido' : 'partidos' }} por seleccionar.</p>
        <p v-else-if="!momiosDisponibles" class="mt-2 text-sm text-amber-700">Faltan momios para identificar el no favorito de uno o más partidos.</p>
        <p v-else-if="!underdogValido" class="mt-2 text-sm text-amber-700">Elige un partido como tu underdog.</p>
        <p v-else-if="!totalValido" class="mt-2 text-sm text-amber-700">Indica un total entre 0 y 400 para el desempate.</p>
        <p v-else class="mt-2 text-sm font-semibold text-green-700">Tu quiniela está lista para guardar.</p>
      </section>
      <div class="grid gap-4 sm:grid-cols-2">
        <TarjetaPartido v-for="juego in juegos" :key="juego.id" v-model="elecciones[juego.id]" :juego="juego" :underdog-seleccionado="underdogId === juego.id" :disabled="cerrado || !auth.isLoggedIn" @seleccionar-underdog="seleccionarUnderdog(juego.id)" />
      </div>
      <p v-if="!momiosDisponibles" class="rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800">Todavía no están disponibles los momios de todos los partidos. Podrás guardar cuando se identifique cada no favorito.</p>
      <p v-else-if="!underdogValido" class="rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800">Elige un partido como tu underdog. Si aciertas al no favorito, sumará 2 puntos adicionales.</p>
      <section v-if="juegos.length" class="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm sm:p-6">
        <h2 class="font-bold text-quiniela-azulOscuro">Puntos totales del partido de desempate</h2>
        <p class="mt-1 text-sm text-gray-500">Se usa únicamente entre participantes empatados; gana quien acierte o quede más cerca.</p>
        <label for="total-desempate" class="form-label mt-3 max-w-xs">Puntos estimados</label>
        <input id="total-desempate" v-model="total" type="number" min="0" max="400" inputmode="numeric" :disabled="cerrado || !auth.isLoggedIn" class="form-control max-w-xs" placeholder="Ej. 47" />
      </section>
      <section v-if="auth.isLoggedIn && !cerrado && juegosActivos.length" class="sticky bottom-3 z-20 rounded-2xl border border-gray-200 bg-white/95 p-3 shadow-xl backdrop-blur sm:flex sm:items-center sm:justify-between sm:gap-4 sm:p-4"><p class="hidden text-sm text-gray-600 sm:block">{{ faltantesFormulario }}</p><button :disabled="!completo || guardando" @click="guardar" class="w-full rounded-xl bg-quiniela-rojo px-5 py-3 font-bold text-white transition hover:bg-quiniela-rojoOscuro disabled:cursor-not-allowed disabled:opacity-40">{{ guardando ? 'Guardando…' : 'Guardar quiniela semanal' }}</button></section>
      <p v-if="cerrado" class="rounded-xl bg-gray-200 p-4 text-center font-semibold text-gray-700">La recepción de pronósticos está cerrada.</p>
    </template>
  </main>
</template>
