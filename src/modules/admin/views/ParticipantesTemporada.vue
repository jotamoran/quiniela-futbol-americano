<script setup>
import { onMounted, ref } from 'vue';
import { alertaError, alertaExito } from '@/lib/alertas';
import { actualizarParticipante, listarParticipantes, obtenerTemporadaActiva } from '@/services/nflService';

const temporada = ref(null);
const participantes = ref([]);
const guardando = ref('');

async function cargar() {
  temporada.value = await obtenerTemporadaActiva();
  participantes.value = temporada.value ? await listarParticipantes(temporada.value.id) : [];
}
async function guardar(item) {
  guardando.value = item.id;
  try { await actualizarParticipante(item); await cargar(); await alertaExito('Participante actualizado'); }
  catch (e) { await alertaError(e); }
  finally { guardando.value = ''; }
}
onMounted(async () => { try { await cargar(); } catch (e) { await alertaError(e, 'No se pudieron cargar los participantes'); } });
</script>

<template>
  <main class="page-shell max-w-6xl">
    <header><p class="eyebrow">Administración</p><h1 class="page-title">Participantes</h1><p class="page-description">Gestiona información y pago de toda la temporada.</p></header>
    <div class="grid gap-4">
      <form v-for="item in participantes" :key="item.id" @submit.prevent="guardar(item)" class="grid gap-3 rounded-2xl border border-gray-200 bg-white p-4 shadow-sm md:grid-cols-6 md:items-end">
        <label class="form-label md:col-span-2">Nombre<input v-model="item.nombre_completo" required class="form-control" /></label>
        <div class="text-sm"><p class="font-semibold">@{{ item.username }}</p><p class="break-all text-gray-500">{{ item.email }}</p></div>
        <label class="form-label">Teléfono<input v-model="item.telefono" maxlength="30" class="form-control" /></label>
        <label class="flex min-h-11 items-center gap-2 rounded-xl border border-gray-200 px-3"><input v-model="item.estado_pago" type="checkbox" true-value="pagado" false-value="pendiente" /> Pago confirmado</label>
        <button :disabled="guardando === item.id" class="rounded-xl bg-quiniela-azul px-4 py-2 font-bold text-white disabled:opacity-50">Guardar</button>
        <label class="form-label md:col-span-3">Referencia<input v-model="item.referencia_pago" readonly class="form-control bg-gray-50" /></label>
        <label class="form-label md:col-span-3">Notas privadas<input v-model="item.notas_admin" maxlength="2000" class="form-control" /></label>
      </form>
    </div>
    <p v-if="!participantes.length" class="empty-state">No hay participantes registrados.</p>
  </main>
</template>
