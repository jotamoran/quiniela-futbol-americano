<script setup>
import { computed, onMounted, ref } from 'vue';
import { alertaError, alertaExito, confirmarAccion } from '@/lib/alertas';
import { fechaHoraCDMX, fechaInputCDMX } from '@/lib/fechas';
import { crearSemana, finalizarTemporada, guardarTemporada, listarParticipantes, listarSemanas, obtenerJuegos, obtenerTemporadaActual, rankingSemanal } from '@/services/nflService';
import { buscarSemanaNFL } from '../services/nflAdminService';
import EquipoNFLAutocomplete from '../components/EquipoNFLAutocomplete.vue';

const temporada = ref(null);
const semanas = ref([]);
const temporadaForm = ref({ nombre: 'NFL 2026', anio: 2026, fecha_limite_pago: '2026-09-30T23:59', premio_primero: '', premio_segundo: '', premio_tercero: '' });
const semanaForm = ref({ numero: 1, nombre: 'Semana 1', fecha_cierre: '' });
const juegos = ref([nuevoJuego()]);
const guardando = ref(false);
const buscando = ref(false);
const finalizando = ref(false);
const resumen = ref({ semanasAbiertas: 0, partidosPendientes: 0, pagosPendientes: 0, empatesPendientes: 0 });
function nuevoJuego() { return { visitante: null, local: null, fecha_partido: '', desempate: false, underdog: false, provider: 'manual', external_event_id: null }; }
const erroresSemana = computed(() => {
  const errores = [];
  const numero = Number(semanaForm.value.numero);
  const cierre = new Date(semanaForm.value.fecha_cierre);
  if (!Number.isInteger(numero) || numero < 1 || numero > 18) errores.push('El número de semana debe estar entre 1 y 18.');
  if (semanas.value.some((semana) => Number(semana.numero) === numero)) errores.push('Ese número de semana ya está publicado.');
  if (!semanaForm.value.fecha_cierre || Number.isNaN(cierre.getTime()) || cierre <= new Date()) errores.push('Define un cierre de pronósticos futuro.');
  if (!juegos.value.length || juegos.value.length > 16) errores.push('La semana debe tener entre 1 y 16 partidos.');
  const nombres = juegos.value.flatMap((juego) => [juego.visitante?.name, juego.local?.name]).filter(Boolean).map((nombre) => nombre.trim().toLowerCase());
  const repetidos = [...new Set(nombres.filter((nombre, index) => nombres.indexOf(nombre) !== index))];
  if (repetidos.length) errores.push(`Un equipo aparece más de una vez: ${repetidos.join(', ')}.`);
  if (juegos.value.some((juego) => !juego.visitante?.name?.trim() || !juego.local?.name?.trim() || !juego.fecha_partido)) errores.push('Completa los dos equipos y la fecha de cada partido.');
  const primerPartido = juegos.value.filter((juego) => juego.fecha_partido).map((juego) => new Date(juego.fecha_partido).getTime()).filter(Number.isFinite).sort((a, b) => a - b)[0];
  if (Number.isFinite(primerPartido) && !Number.isNaN(cierre.getTime()) && cierre.getTime() > primerPartido - 5 * 60 * 1000) errores.push('El cierre debe quedar al menos cinco minutos antes del primer partido.');
  if (juegos.value.filter((juego) => juego.desempate).length !== 1) errores.push('Selecciona un único partido de desempate.');
  if (juegos.value.filter((juego) => juego.underdog).length !== 1) errores.push('Selecciona un único partido underdog.');
  return [...new Set(errores)];
});
const valido = computed(() => erroresSemana.value.length === 0);
const semanasListasParaFinalizar = computed(() => semanas.value.length > 0 && semanas.value.every((semana) => semana.estado === 'finalizada'));
function fechaIso(valor) { return new Date(valor).toISOString(); }
function fechaLocal(valor) {
  return fechaInputCDMX(valor);
}
function prepararSiguienteSemana() {
  const siguiente = Math.min(18, Math.max(0, ...semanas.value.map((semana) => Number(semana.numero) || 0)) + 1);
  const formularioVacio = juegos.value.length === 1 && !juegos.value[0].visitante && !juegos.value[0].local && !juegos.value[0].fecha_partido;
  if (formularioVacio && !semanaForm.value.fecha_cierre) {
    semanaForm.value.numero = siguiente;
    semanaForm.value.nombre = `Semana ${siguiente}`;
  }
}

async function cargar() {
  temporada.value = await obtenerTemporadaActual();
  if (temporada.value) {
    Object.assign(temporadaForm.value, temporada.value, { fecha_limite_pago: fechaInputCDMX(temporada.value.fecha_limite_pago) });
    semanas.value = await listarSemanas(temporada.value.id);
    const [juegosPorSemana, participantes, rankings] = await Promise.all([
      Promise.all(semanas.value.map((semana) => obtenerJuegos(semana.id))),
      listarParticipantes(temporada.value.id),
      Promise.all(semanas.value.map((semana) => rankingSemanal(semana.id))),
    ]);
    resumen.value = {
      semanasAbiertas: semanas.value.filter((semana) => semana.estado === 'abierta' && new Date(semana.fecha_cierre) > new Date()).length,
      partidosPendientes: juegosPorSemana.flat().filter((juego) => !['finalizado', 'cancelado'].includes(juego.estado)).length,
      pagosPendientes: participantes.filter((participante) => participante.estado_pago !== 'pagado').length,
      empatesPendientes: rankings.flat().filter((fila) => fila.empate_pendiente).length,
    };
    prepararSiguienteSemana();
  }
}
async function guardarDatosTemporada() {
  guardando.value = true;
  try {
    await guardarTemporada({ ...temporadaForm.value, fecha_limite_pago: fechaIso(temporadaForm.value.fecha_limite_pago) });
    await cargar(); await alertaExito('Temporada guardada');
  } catch (e) { await alertaError(e); } finally { guardando.value = false; }
}
async function importarSemana() {
  buscando.value = true;
  try {
    const { games } = await buscarSemanaNFL(temporada.value.anio, semanaForm.value.numero);
    if (!games.length) throw new Error('No se encontraron partidos para esa semana');
    if (games.length > 16) throw new Error(`Se encontraron ${games.length} partidos; revisa que sea una semana de temporada regular`);
    juegos.value = games.map((game) => ({
      visitante: game.away,
      local: game.home,
      fecha_partido: fechaLocal(game.date),
      desempate: false,
      underdog: false,
      provider: 'thesportsdb',
      external_event_id: game.externalId,
    }));
    juegos.value[juegos.value.length - 1].desempate = true;
    const primerPartido = new Date(Math.min(...games.map((game) => new Date(game.date))));
    semanaForm.value.fecha_cierre = fechaLocal(new Date(primerPartido.getTime() - 5 * 60 * 1000));
    semanaForm.value.nombre = `Semana ${semanaForm.value.numero}`;
    await alertaExito('Calendario cargado', `${games.length} partidos importados automáticamente.`);
  } catch (e) { await alertaError(e, 'No se pudo importar la semana'); } finally { buscando.value = false; }
}
async function publicarSemana() {
  guardando.value = true;
  try {
    await crearSemana({ ...semanaForm.value, temporada_id: temporada.value.id, fecha_cierre: fechaIso(semanaForm.value.fecha_cierre) }, juegos.value.map(j => ({
      equipo_visitante: j.visitante.name,
      equipo_local: j.local.name,
      fecha_partido: fechaIso(j.fecha_partido),
      desempate: j.desempate,
      underdog: j.underdog,
      provider: j.provider,
      external_event_id: j.external_event_id,
      logo_visitante: j.visitante.logo,
      logo_local: j.local.logo,
    })));
    semanaForm.value = { numero: Number(semanaForm.value.numero) + 1, nombre: `Semana ${Number(semanaForm.value.numero) + 1}`, fecha_cierre: '' };
    juegos.value = [nuevoJuego()]; await cargar(); await alertaExito('Semana publicada');
  } catch (e) { await alertaError(e, 'No se pudo publicar la semana'); } finally { guardando.value = false; }
}
async function cerrarTemporada() {
  const confirmado = await confirmarAccion({ title: 'Finalizar temporada', text: 'La temporada quedará en modo de solo consulta y no podrás reabrirla.', confirmText: 'Finalizar', danger: true });
  if (!confirmado || !temporada.value) return;
  finalizando.value = true;
  try { await finalizarTemporada(temporada.value.id); await alertaExito('Temporada finalizada'); await cargar(); }
  catch (e) { await alertaError(e, 'No se pudo finalizar la temporada'); }
  finally { finalizando.value = false; }
}
onMounted(cargar);
</script>

<template>
  <main class="page-shell max-w-5xl">
    <header><p class="eyebrow">Administración</p><h1 class="page-title">Temporada y semanas</h1><p class="page-description">Configura la competencia y captura el calendario semanal.</p></header>
    <section v-if="temporada" class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4" aria-label="Resumen de administración"><article class="rounded-2xl bg-white p-4 shadow-sm"><p class="text-sm text-gray-500">Semanas abiertas</p><strong class="text-2xl text-quiniela-azul">{{ resumen.semanasAbiertas }}</strong></article><article class="rounded-2xl bg-white p-4 shadow-sm"><p class="text-sm text-gray-500">Partidos pendientes</p><strong class="text-2xl text-quiniela-rojo">{{ resumen.partidosPendientes }}</strong></article><article class="rounded-2xl bg-white p-4 shadow-sm"><p class="text-sm text-gray-500">Pagos por revisar</p><strong class="text-2xl text-amber-700">{{ resumen.pagosPendientes }}</strong></article><article class="rounded-2xl bg-white p-4 shadow-sm"><p class="text-sm text-gray-500">Empates por resolver</p><strong class="text-2xl text-quiniela-azul">{{ resumen.empatesPendientes }}</strong></article></section>
    <form @submit.prevent="guardarDatosTemporada" class="grid gap-3 rounded-2xl bg-white p-5 shadow-sm sm:grid-cols-3">
      <div class="flex flex-wrap items-center justify-between gap-2 sm:col-span-3"><h2 class="font-bold text-quiniela-azulOscuro">Temporada</h2><span class="rounded-full bg-green-100 px-3 py-1 text-xs font-bold text-green-800">{{ temporada?.estado === 'finalizada' ? 'Finalizada' : 'Activa' }}</span></div>
      <label class="form-label">Nombre<input v-model="temporadaForm.nombre" :disabled="temporada?.estado === 'finalizada'" required class="form-control" /></label><label class="form-label">Año<input v-model="temporadaForm.anio" :disabled="temporada?.estado === 'finalizada'" type="number" required class="form-control" /></label><label class="form-label">Fecha límite de pago<input v-model="temporadaForm.fecha_limite_pago" :disabled="temporada?.estado === 'finalizada'" type="datetime-local" required class="form-control" /></label>
      <label class="form-label">Premio 1.º<input v-model="temporadaForm.premio_primero" :disabled="temporada?.estado === 'finalizada'" type="number" min="0" class="form-control" /></label><label class="form-label">Premio 2.º<input v-model="temporadaForm.premio_segundo" :disabled="temporada?.estado === 'finalizada'" type="number" min="0" class="form-control" /></label><label class="form-label">Premio 3.º<input v-model="temporadaForm.premio_tercero" :disabled="temporada?.estado === 'finalizada'" type="number" min="0" class="form-control" /></label>
      <div class="flex flex-col gap-2 sm:col-span-3 sm:flex-row sm:items-center sm:justify-between"><button :disabled="guardando || temporada?.estado === 'finalizada'" class="rounded-xl bg-quiniela-azul px-5 py-3 font-bold text-white">Guardar temporada</button><button v-if="temporada?.estado !== 'finalizada'" type="button" :disabled="finalizando || !semanasListasParaFinalizar" @click="cerrarTemporada" class="rounded-xl border border-red-300 px-5 py-3 font-bold text-red-700 disabled:cursor-not-allowed disabled:opacity-40">{{ finalizando ? 'Finalizando…' : 'Finalizar temporada' }}</button></div>
    </form>
    <form v-if="temporada && temporada.estado !== 'finalizada'" @submit.prevent="publicarSemana" class="space-y-4 rounded-2xl bg-white p-5 shadow-sm">
      <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"><div><h2 class="font-bold text-quiniela-azulOscuro">Nueva semana</h2><p class="text-sm text-gray-500">Carga el calendario automáticamente o agrega partidos manuales.</p></div><button type="button" @click="importarSemana" :disabled="buscando || guardando" class="min-h-11 rounded-xl border border-quiniela-azul px-4 py-2 font-semibold text-quiniela-azul disabled:opacity-50">{{ buscando ? 'Consultando…' : 'Cargar calendario automáticamente' }}</button></div>
      <div class="grid gap-3 sm:grid-cols-3"><label class="form-label">Número<input v-model="semanaForm.numero" type="number" min="1" max="18" required class="form-control" /><span class="mt-1 block text-xs font-normal text-gray-500">Temporada regular: semanas 1 a 18.</span></label><label class="form-label">Nombre<input v-model="semanaForm.nombre" required class="form-control" /></label><label class="form-label">Cierre de pronósticos<input v-model="semanaForm.fecha_cierre" type="datetime-local" required class="form-control" /><span class="mt-1 block text-xs font-normal text-gray-500">Se propone 5 minutos antes del primer partido; puedes modificarlo.</span></label></div>
      <div class="space-y-3"><article v-for="(juego, index) in juegos" :key="juego.external_event_id || index" class="rounded-2xl border border-gray-200 p-3 sm:p-4"><div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-[1fr_1fr_1.15fr]"><EquipoNFLAutocomplete v-model="juego.visitante" label="Visitante" /><EquipoNFLAutocomplete v-model="juego.local" label="Local" /><label class="form-label">Fecha del partido<input v-model="juego.fecha_partido" type="datetime-local" required class="form-control" /></label></div><div class="mt-3 flex flex-col gap-2 border-t border-gray-100 pt-3 sm:flex-row sm:items-center sm:justify-between"><div class="flex flex-wrap gap-x-5 gap-y-2"><label class="flex min-h-11 items-center gap-2 text-sm font-semibold"><input v-model="juego.desempate" type="radio" name="desempate" :value="true" @change="juegos.forEach((j, i) => j.desempate = i === index)" /> Partido de desempate</label><label class="flex min-h-11 items-center gap-2 text-sm font-semibold text-quiniela-rojoOscuro"><input v-model="juego.underdog" type="radio" name="underdog" :value="true" @change="juegos.forEach((j, i) => j.underdog = i === index)" /> Partido underdog</label></div><button v-if="juegos.length > 1" type="button" @click="juegos.splice(index, 1)" class="min-h-11 self-start rounded-lg px-3 text-sm font-semibold text-red-700 hover:bg-red-50">Quitar partido</button></div></article></div>
      <section class="sticky bottom-3 z-20 rounded-2xl border border-gray-200 bg-white/95 p-3 shadow-xl backdrop-blur sm:flex sm:items-center sm:justify-between sm:gap-4 sm:p-4"><div><p class="text-sm font-semibold text-quiniela-azulOscuro">{{ juegos.length }} de 16 partidos</p><p v-if="erroresSemana.length" role="alert" class="mt-1 text-xs text-amber-700">{{ erroresSemana[0] }}</p><p v-else class="mt-1 text-xs font-semibold text-green-700">La semana está lista para publicar.</p></div><div class="flex flex-col gap-2 sm:flex-row"><button type="button" :disabled="juegos.length >= 16" @click="juegos.push(nuevoJuego())" class="min-h-11 rounded-xl border border-quiniela-azul px-4 py-2 font-semibold text-quiniela-azul">Agregar partido</button><button :disabled="!valido || guardando" class="min-h-11 rounded-xl bg-quiniela-rojo px-5 py-2 font-bold text-white disabled:opacity-40">Publicar semana</button></div></section>
    </form>
    <section><div class="mb-3 flex flex-wrap items-end justify-between gap-2"><div><h2 class="text-xl font-bold text-quiniela-azulOscuro">Semanas publicadas</h2><p class="text-sm text-gray-500">Solo una temporada finalizada deja de aceptar cambios.</p></div><span v-if="semanas.length" class="text-sm font-semibold text-gray-600">{{ semanas.filter((semana) => semana.estado === 'finalizada').length }} de {{ semanas.length }} finalizadas</span></div><div class="grid gap-2 sm:grid-cols-2"><div v-for="semana in semanas" :key="semana.id" class="rounded-xl bg-white p-4 shadow-sm"><div class="flex flex-wrap items-center justify-between gap-2"><strong>{{ semana.nombre }}</strong><span class="rounded-full px-2 py-1 text-xs font-bold" :class="semana.estado === 'finalizada' ? 'bg-blue-100 text-blue-800' : 'bg-green-100 text-green-800'">{{ semana.estado === 'finalizada' ? 'Finalizada' : 'Abierta' }}</span></div><p class="mt-1 text-sm text-gray-500">Cierre: {{ fechaHoraCDMX(semana.fecha_cierre) }} · CDMX</p></div></div><p v-if="!semanas.length" class="empty-state">Todavía no hay semanas publicadas.</p></section>
  </main>
</template>
