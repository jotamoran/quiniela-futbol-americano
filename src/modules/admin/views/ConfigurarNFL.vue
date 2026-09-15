<script setup>
import { computed, onMounted, ref } from 'vue';
import { alertaError, alertaExito } from '@/lib/alertas';
import { crearSemana, guardarTemporada, listarSemanas, obtenerTemporadaActiva } from '@/services/nflService';
import { buscarSemanaNFL } from '../services/nflAdminService';
import EquipoNFLAutocomplete from '../components/EquipoNFLAutocomplete.vue';

const temporada = ref(null);
const semanas = ref([]);
const temporadaForm = ref({ nombre: 'NFL 2026', anio: 2026, fecha_limite_pago: '2026-09-30T23:59', premio_primero: '', premio_segundo: '', premio_tercero: '' });
const semanaForm = ref({ numero: 1, nombre: 'Semana 1', fecha_cierre: '' });
const juegos = ref([nuevoJuego()]);
const guardando = ref(false);
const buscando = ref(false);
function nuevoJuego() { return { visitante: null, local: null, fecha_partido: '', desempate: false, underdog: false, provider: 'manual', external_event_id: null }; }
const valido = computed(() => juegos.value.length && juegos.value.length <= 16 && juegos.value.every(j => j.visitante?.name?.trim() && j.local?.name?.trim() && j.fecha_partido) && juegos.value.filter(j => j.desempate).length === 1 && juegos.value.filter(j => j.underdog).length === 1);
function fechaIso(valor) { return new Date(valor).toISOString(); }
function fechaLocal(valor) {
  const fecha = new Date(valor);
  const parte = (numero) => String(numero).padStart(2, '0');
  return `${fecha.getFullYear()}-${parte(fecha.getMonth() + 1)}-${parte(fecha.getDate())}T${parte(fecha.getHours())}:${parte(fecha.getMinutes())}`;
}

async function cargar() {
  temporada.value = await obtenerTemporadaActiva();
  if (temporada.value) {
    Object.assign(temporadaForm.value, temporada.value, { fecha_limite_pago: new Date(temporada.value.fecha_limite_pago).toISOString().slice(0, 16) });
    semanas.value = await listarSemanas(temporada.value.id);
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
onMounted(cargar);
</script>

<template>
  <main class="page-shell max-w-5xl">
    <header><p class="eyebrow">Administración</p><h1 class="page-title">Temporada y semanas</h1><p class="page-description">Configura la competencia y captura el calendario semanal.</p></header>
    <form @submit.prevent="guardarDatosTemporada" class="grid gap-3 rounded-2xl bg-white p-5 shadow-sm sm:grid-cols-3">
      <h2 class="font-bold text-quiniela-azulOscuro sm:col-span-3">Temporada</h2>
      <label class="form-label">Nombre<input v-model="temporadaForm.nombre" required class="form-control" /></label><label class="form-label">Año<input v-model="temporadaForm.anio" type="number" required class="form-control" /></label><label class="form-label">Fecha límite de pago<input v-model="temporadaForm.fecha_limite_pago" type="datetime-local" required class="form-control" /></label>
      <label class="form-label">Premio 1.º<input v-model="temporadaForm.premio_primero" type="number" min="0" class="form-control" /></label><label class="form-label">Premio 2.º<input v-model="temporadaForm.premio_segundo" type="number" min="0" class="form-control" /></label><label class="form-label">Premio 3.º<input v-model="temporadaForm.premio_tercero" type="number" min="0" class="form-control" /></label>
      <button :disabled="guardando" class="rounded-xl bg-quiniela-azul px-5 py-3 font-bold text-white sm:col-span-3">Guardar temporada</button>
    </form>
    <form v-if="temporada" @submit.prevent="publicarSemana" class="space-y-4 rounded-2xl bg-white p-5 shadow-sm">
      <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"><div><h2 class="font-bold text-quiniela-azulOscuro">Nueva semana</h2><p class="text-sm text-gray-500">Carga el calendario automáticamente o agrega partidos manuales.</p></div><button type="button" @click="importarSemana" :disabled="buscando || guardando" class="min-h-11 rounded-xl border border-quiniela-azul px-4 py-2 font-semibold text-quiniela-azul disabled:opacity-50">{{ buscando ? 'Consultando…' : 'Cargar calendario automáticamente' }}</button></div>
      <div class="grid gap-3 sm:grid-cols-3"><label class="form-label">Número<input v-model="semanaForm.numero" type="number" min="1" max="18" required class="form-control" /><span class="mt-1 block text-xs font-normal text-gray-500">Temporada regular: semanas 1 a 18.</span></label><label class="form-label">Nombre<input v-model="semanaForm.nombre" required class="form-control" /></label><label class="form-label">Cierre de pronósticos<input v-model="semanaForm.fecha_cierre" type="datetime-local" required class="form-control" /><span class="mt-1 block text-xs font-normal text-gray-500">Se propone 5 minutos antes del primer partido; puedes modificarlo.</span></label></div>
      <div class="space-y-3"><article v-for="(juego, index) in juegos" :key="juego.external_event_id || index" class="rounded-2xl border border-gray-200 p-3 sm:p-4"><div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-[1fr_1fr_1.15fr]"><EquipoNFLAutocomplete v-model="juego.visitante" label="Visitante" /><EquipoNFLAutocomplete v-model="juego.local" label="Local" /><label class="form-label">Fecha del partido<input v-model="juego.fecha_partido" type="datetime-local" required class="form-control" /></label></div><div class="mt-3 flex flex-col gap-2 border-t border-gray-100 pt-3 sm:flex-row sm:items-center sm:justify-between"><div class="flex flex-wrap gap-x-5 gap-y-2"><label class="flex min-h-11 items-center gap-2 text-sm font-semibold"><input v-model="juego.desempate" type="radio" name="desempate" :value="true" @change="juegos.forEach((j, i) => j.desempate = i === index)" /> Partido de desempate</label><label class="flex min-h-11 items-center gap-2 text-sm font-semibold text-quiniela-rojoOscuro"><input v-model="juego.underdog" type="radio" name="underdog" :value="true" @change="juegos.forEach((j, i) => j.underdog = i === index)" /> Partido underdog</label></div><button v-if="juegos.length > 1" type="button" @click="juegos.splice(index, 1)" class="min-h-11 self-start rounded-lg px-3 text-sm font-semibold text-red-700 hover:bg-red-50">Quitar partido</button></div></article></div>
      <div class="flex flex-wrap gap-2"><button type="button" :disabled="juegos.length >= 16" @click="juegos.push(nuevoJuego())" class="rounded-xl border border-quiniela-azul px-4 py-2 font-semibold text-quiniela-azul">Agregar partido</button><button :disabled="!valido || guardando" class="rounded-xl bg-quiniela-rojo px-5 py-2 font-bold text-white disabled:opacity-40">Publicar semana</button></div>
    </form>
    <section><h2 class="mb-3 text-xl font-bold text-quiniela-azulOscuro">Semanas publicadas</h2><div class="grid gap-2 sm:grid-cols-2"><div v-for="semana in semanas" :key="semana.id" class="rounded-xl bg-white p-4 shadow-sm"><strong>{{ semana.nombre }}</strong><p class="text-sm text-gray-500">{{ semana.estado }} · {{ new Date(semana.fecha_cierre).toLocaleString('es-MX') }}</p></div></div></section>
  </main>
</template>
