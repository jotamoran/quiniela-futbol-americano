<script setup>
import { computed, onMounted, ref } from 'vue';
import { alertaError, alertaExito, confirmarAccion } from '@/lib/alertas';
import { configurarJuego, finalizarSemana, guardarResultados, listarSemanas, obtenerJuegos, obtenerTemporadaActual, registrosSemana } from '@/services/nflService';
import { sincronizarMomiosNFL, sincronizarResultadosNFL } from '../services/nflAdminService';

const semanas = ref([]);
const semanaId = ref('');
const juegos = ref([]);
const registros = ref([]);
const guardando = ref(false);
const sincronizando = ref(false);
const sincronizandoMomios = ref(false);
const configurando = ref('');
const finalizando = ref(false);
const semanaActual = computed(() => semanas.value.find((semana) => semana.id === semanaId.value));
const semanaFinalizada = computed(() => semanaActual.value?.estado === 'finalizada');
const semanaCerrada = computed(() => Boolean(semanaActual.value && new Date(semanaActual.value.fecha_cierre) <= new Date() && !semanaFinalizada.value));
const todosLosJuegosResueltos = computed(() => juegos.value.length > 0 && juegos.value.every((juego) => ['finalizado', 'cancelado'].includes(juego.estado)));
const momiosIdentificados = computed(() => juegos.value.filter((juego) => juego.estado !== 'cancelado' && juego.underdog_lado).length);
function esEmpate(juego) { return juego.estado === 'finalizado' && juego.puntos_local !== '' && juego.puntos_local !== null && juego.puntos_visitante !== '' && juego.puntos_visitante !== null && Number(juego.puntos_local) === Number(juego.puntos_visitante); }
const erroresResultados = computed(() => juegos.value.flatMap((juego) => {
  if (juego.estado === 'cancelado') return [];
  const visitanteVacio = juego.puntos_visitante === '' || juego.puntos_visitante === null || juego.puntos_visitante === undefined;
  const localVacio = juego.puntos_local === '' || juego.puntos_local === null || juego.puntos_local === undefined;
  const errores = [];
  if (juego.estado === 'finalizado' && (visitanteVacio || localVacio)) errores.push(`${juego.equipo_visitante} @ ${juego.equipo_local}: captura ambos marcadores para finalizarlo.`);
  const visitante = Number(juego.puntos_visitante);
  const local = Number(juego.puntos_local);
  if ((!visitanteVacio && (!Number.isInteger(visitante) || visitante < 0 || visitante > 200)) || (!localVacio && (!Number.isInteger(local) || local < 0 || local > 200))) errores.push(`${juego.equipo_visitante} @ ${juego.equipo_local}: los marcadores deben ser enteros entre 0 y 200.`);
  return errores;
}));
async function cargarSemanas() { const temporada = await obtenerTemporadaActual(); semanas.value = temporada ? await listarSemanas(temporada.id) : []; }
async function cargarSemana() {
  if (!semanaId.value) { juegos.value = []; registros.value = []; return; }
  juegos.value = (await obtenerJuegos(semanaId.value)).map(j => ({ ...j, puntos_visitante: j.puntos_visitante ?? '', puntos_local: j.puntos_local ?? '' }));
  try { registros.value = await registrosSemana(semanaId.value); } catch { registros.value = []; }
}
async function cerrarSemana() {
  const confirmado = await confirmarAccion({ title: 'Finalizar semana', text: 'La semana quedará en modo de solo consulta y no podrás reabrirla.', confirmText: 'Finalizar', danger: true });
  if (!confirmado || !semanaId.value) return;
  finalizando.value = true;
  try { await finalizarSemana(semanaId.value); await cargarSemanas(); await cargarSemana(); await alertaExito('Semana finalizada'); }
  catch (e) { await alertaError(e, 'No se pudo finalizar la semana'); }
  finally { finalizando.value = false; }
}
async function cambiarJuego(juego, cambio) {
  if (cambio === 'cancelado') {
    const confirmado = await confirmarAccion({ title: juego.estado === 'cancelado' ? 'Reactivar partido' : 'Cancelar partido', text: `${juego.equipo_visitante} @ ${juego.equipo_local}`, confirmText: juego.estado === 'cancelado' ? 'Reactivar' : 'Cancelar', danger: juego.estado !== 'cancelado' });
    if (!confirmado) return;
  }
  configurando.value = juego.id;
  try {
    await configurarJuego(juego.id, { underdog: false, cancelado: cambio === 'cancelado' ? juego.estado !== 'cancelado' : juego.estado === 'cancelado' });
    await cargarSemana();
    await alertaExito('Estado del partido actualizado');
  } catch (e) { await alertaError(e, 'No se pudo actualizar el partido'); } finally { configurando.value = ''; }
}
async function guardar() {
  if (erroresResultados.value.length) { await alertaError(new Error(erroresResultados.value[0]), 'Revisa los resultados'); return; }
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
async function sincronizarMomios() {
  sincronizandoMomios.value = true;
  try {
    const respuesta = await sincronizarMomiosNFL(semanaId.value);
    await cargarSemana();
    await alertaExito('Momios actualizados', respuesta.unmatched?.length ? `${respuesta.updated} partidos identificados; ${respuesta.unmatched.length} quedaron pendientes.` : `${respuesta.updated} partidos identificados automáticamente.`);
  } catch (e) { await alertaError(e, 'No se pudieron actualizar los momios'); } finally { sincronizandoMomios.value = false; }
}
onMounted(async () => { try { await cargarSemanas(); } catch (e) { await alertaError(e); } });
</script>

<template>
  <main class="page-shell max-w-5xl">
    <header><p class="eyebrow">Administración</p><h1 class="page-title">Resultados y registros</h1><p class="page-description">Consulta los momios, cancela partidos y actualiza marcadores. Los empates persistentes quedan marcados para revisión.</p></header>
    <div class="flex flex-col gap-3 sm:flex-row sm:items-end"><label class="form-label min-w-0 max-w-md flex-1">Semana<select v-model="semanaId" @change="cargarSemana" class="form-control"><option value="">Selecciona una semana</option><option v-for="semana in semanas" :key="semana.id" :value="semana.id">{{ semana.nombre }} · {{ semana.estado === 'finalizada' ? 'Finalizada' : new Date(semana.fecha_cierre) <= new Date() ? 'Cerrada' : 'Abierta' }}</option></select></label><span v-if="semanaActual" class="rounded-full px-3 py-2 text-sm font-bold" :class="semanaFinalizada ? 'bg-blue-100 text-blue-800' : semanaCerrada ? 'bg-amber-100 text-amber-800' : 'bg-green-100 text-green-800'">{{ semanaFinalizada ? 'Solo consulta' : semanaCerrada ? 'Cerrada · captura de resultados' : 'Semana abierta' }}</span><button v-if="semanaId && !semanaFinalizada" type="button" @click="sincronizarMomios" :disabled="sincronizandoMomios || guardando || semanaCerrada" class="min-h-11 w-full rounded-xl border border-amber-600 px-4 py-2 font-semibold text-amber-800 disabled:opacity-50 sm:w-auto">{{ sincronizandoMomios ? 'Consultando momios…' : 'Actualizar momios' }}</button><button v-if="semanaId" type="button" @click="sincronizar" :disabled="sincronizando || guardando || semanaFinalizada" class="min-h-11 w-full rounded-xl border border-quiniela-azul px-4 py-2 font-semibold text-quiniela-azul disabled:opacity-50 sm:w-auto">{{ sincronizando ? 'Sincronizando…' : 'Actualizar resultados automáticamente' }}</button><button v-if="semanaId && !semanaFinalizada" type="button" @click="cerrarSemana" :disabled="finalizando || !todosLosJuegosResueltos" class="min-h-11 w-full rounded-xl border border-red-300 px-4 py-2 font-semibold text-red-700 disabled:opacity-40 sm:w-auto">{{ finalizando ? 'Finalizando…' : 'Finalizar semana' }}</button></div>
    <form v-if="juegos.length" @submit.prevent="guardar" class="space-y-3">
       <article v-for="juego in juegos" :key="juego.id" class="rounded-2xl border bg-white p-4 shadow-sm" :class="juego.estado === 'cancelado' ? 'border-gray-300 bg-gray-50' : juego.underdog_lado ? 'border-amber-200' : 'border-transparent'">
        <div class="grid gap-3 sm:grid-cols-[1fr_7rem_7rem_10rem] sm:items-end"><div class="min-w-0"><div class="flex min-w-0 items-center gap-3"><img v-if="juego.logo_visitante" :src="juego.logo_visitante" alt="" loading="lazy" decoding="async" class="h-9 w-9 shrink-0 object-contain" /><strong class="min-w-0 break-words">{{ juego.equipo_visitante }} @ {{ juego.equipo_local }}</strong><img v-if="juego.logo_local" :src="juego.logo_local" alt="" loading="lazy" decoding="async" class="h-9 w-9 shrink-0 object-contain" /></div><div class="mt-2 flex flex-wrap gap-1"><span v-if="juego.desempate" class="rounded-full bg-blue-50 px-2 py-1 text-xs font-bold text-quiniela-azul">Desempate</span><span v-if="juego.underdog_lado" class="inline-flex max-w-full flex-wrap items-center gap-1 rounded-full bg-amber-50 px-2 py-1 text-xs font-bold text-amber-800"><span class="rounded-full bg-amber-200 px-1.5 py-0.5 text-[10px] uppercase tracking-wide">No favorito</span><span class="break-words">{{ juego.underdog_lado === 'L' ? juego.equipo_local : juego.equipo_visitante }}</span></span><span v-if="juego.estado === 'cancelado'" class="rounded-full bg-gray-200 px-2 py-1 text-xs font-bold text-gray-600">Cancelado</span><span v-else-if="juego.estado === 'en_curso'" class="rounded-full bg-red-50 px-2 py-1 text-xs font-bold text-red-700">En vivo</span><span v-else-if="juego.estado === 'finalizado' && esEmpate(juego)" class="rounded-full bg-amber-50 px-2 py-1 text-xs font-bold text-amber-800">Empate</span><span v-else-if="juego.estado === 'finalizado'" class="rounded-full bg-green-50 px-2 py-1 text-xs font-bold text-green-700">Finalizado</span><span v-else class="rounded-full bg-gray-100 px-2 py-1 text-xs font-bold text-gray-700">Pendiente</span></div></div>
        <label class="form-label">Visitante<input v-model="juego.puntos_visitante" :disabled="semanaFinalizada || juego.estado === 'cancelado'" type="number" min="0" max="200" step="1" class="form-control disabled:bg-gray-100" /></label><label class="form-label">Local<input v-model="juego.puntos_local" :disabled="semanaFinalizada || juego.estado === 'cancelado'" type="number" min="0" max="200" step="1" class="form-control disabled:bg-gray-100" /></label>
        <label class="form-label">Estado<select v-model="juego.estado" :disabled="semanaFinalizada || juego.estado === 'cancelado'" class="form-control disabled:bg-gray-100"><option value="pendiente">Pendiente</option><option value="en_curso">En curso</option><option value="finalizado">Finalizado</option><option v-if="juego.estado === 'cancelado'" value="cancelado">Cancelado</option></select></label></div>
        <div class="mt-3 flex flex-col gap-2 border-t border-gray-100 pt-3 sm:flex-row"><button type="button" @click="cambiarJuego(juego, 'cancelado')" :disabled="semanaFinalizada || Boolean(configurando)" class="min-h-11 rounded-xl border border-gray-300 px-3 py-2 text-sm font-semibold text-gray-700 disabled:opacity-40">{{ juego.estado === 'cancelado' ? 'Reactivar partido' : 'Cancelar partido' }}</button></div>
      </article>
      <section class="sticky bottom-3 z-20 rounded-2xl border border-gray-200 bg-white/95 p-3 shadow-xl backdrop-blur sm:flex sm:items-center sm:justify-between sm:gap-4 sm:p-4"><div><p class="text-sm font-semibold text-quiniela-azulOscuro">{{ juegos.filter((juego) => juego.estado === 'finalizado').length }} partidos finalizados · {{ momiosIdentificados }}/{{ juegos.filter((juego) => juego.estado !== 'cancelado').length }} no favoritos identificados</p><p v-if="erroresResultados.length" role="alert" class="mt-1 text-xs text-amber-700">{{ erroresResultados[0] }}</p><p v-else class="mt-1 text-xs text-gray-500">{{ semanaFinalizada ? 'Semana finalizada: información de solo consulta.' : semanaCerrada ? 'Semana cerrada: solo se actualizan resultados.' : 'Verifica marcadores y estados antes de guardar.' }}</p></div><button :disabled="semanaFinalizada || guardando || erroresResultados.length > 0" class="min-h-11 w-full rounded-xl bg-quiniela-azul px-5 py-3 font-bold text-white disabled:opacity-50 sm:w-auto">{{ guardando ? 'Guardando…' : 'Guardar resultados' }}</button></section>
    </form>
    <section v-if="semanaId" class="rounded-2xl bg-white p-5 shadow-sm"><h2 class="font-bold text-quiniela-azulOscuro">Registros recibidos ({{ registros.length }})</h2><div class="mt-3 flex flex-wrap gap-2"><span v-for="registro in registros" :key="registro.id" class="rounded-full bg-blue-50 px-3 py-1 text-sm font-semibold text-quiniela-azul">@{{ registro.username }}</span></div><p v-if="!registros.length" class="mt-2 text-sm text-gray-500">{{ semanaFinalizada || semanaActual && new Date(semanaActual.fecha_cierre) <= new Date() ? 'No hay registros para esta semana.' : 'Los registros se mostrarán cuando cierre la semana.' }}</p></section>
  </main>
</template>
