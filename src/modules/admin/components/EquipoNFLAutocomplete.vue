<script setup>
import { onUnmounted, ref, useId, watch } from 'vue';
import { buscarEquiposNFL } from '../services/nflAdminService';

const props = defineProps({ modelValue: { type: Object, default: null }, label: { type: String, required: true } });
const emit = defineEmits(['update:modelValue']);
const listaId = `equipos-lista-${useId()}`;
const query = ref(props.modelValue?.name ?? '');
const options = ref([]);
const loading = ref(false);
const opcionActiva = ref(-1);
let timer;
let suppressNextSearch = false;

watch(() => props.modelValue, (value) => { if (value?.name !== query.value) query.value = value?.name ?? ''; });
watch(query, (value) => {
  clearTimeout(timer);
  opcionActiva.value = -1;
  if (suppressNextSearch) { suppressNextSearch = false; options.value = []; return; }
  if (value !== props.modelValue?.name) emit('update:modelValue', value.trim() ? { name: value.trim(), logo: null, manual: true } : null);
  if (value.trim().length < 2) { options.value = []; return; }
  timer = setTimeout(async () => {
    loading.value = true;
    try { options.value = (await buscarEquiposNFL(value.trim())).teams; } catch { options.value = []; } finally { loading.value = false; }
  }, 400);
});

function manejarTecla(evento) {
  if (evento.key === 'Escape') { options.value = []; opcionActiva.value = -1; return; }
  if (!options.value.length) return;
  if (evento.key === 'ArrowDown') { evento.preventDefault(); opcionActiva.value = (opcionActiva.value + 1) % options.value.length; }
  if (evento.key === 'ArrowUp') { evento.preventDefault(); opcionActiva.value = opcionActiva.value <= 0 ? options.value.length - 1 : opcionActiva.value - 1; }
  if (evento.key === 'Enter' && opcionActiva.value >= 0) { evento.preventDefault(); select(options.value[opcionActiva.value]); }
}

function select(team) {
  clearTimeout(timer);
  suppressNextSearch = true;
  opcionActiva.value = -1;
  query.value = team.name;
  options.value = [];
  emit('update:modelValue', team);
}

onUnmounted(() => clearTimeout(timer));
</script>

<template>
  <label class="relative block text-sm font-semibold">
    {{ label }}
    <div class="relative mt-1"><img v-if="modelValue?.logo" :src="modelValue.logo" alt="" class="absolute left-3 top-1/2 h-7 w-7 -translate-y-1/2 object-contain" /><input v-model="query" role="combobox" aria-autocomplete="list" :aria-expanded="Boolean(options.length)" :aria-controls="listaId" :aria-activedescendant="opcionActiva >= 0 ? `${listaId}-opcion-${options[opcionActiva].id}` : undefined" :aria-busy="loading" autocomplete="off" @keydown="manejarTecla" class="form-control pr-10" :class="modelValue?.logo ? 'pl-12' : ''" :placeholder="loading ? 'Buscando…' : 'Busca un equipo NFL'" /><span v-if="loading" class="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-gray-400" aria-hidden="true">•••</span></div>
    <ul v-if="options.length" :id="listaId" role="listbox" class="absolute z-30 mt-1 max-h-56 w-full overflow-auto rounded-xl border border-gray-200 bg-white p-1 shadow-xl">
      <li v-for="(team, index) in options" :id="`${listaId}-opcion-${team.id}`" :key="team.id" role="option" :aria-selected="index === opcionActiva"><button type="button" @click="select(team)" class="flex min-h-11 w-full items-center gap-3 rounded-lg p-2 text-left" :class="index === opcionActiva ? 'bg-blue-50' : 'hover:bg-blue-50'"><img v-if="team.logo" :src="team.logo" alt="" loading="lazy" decoding="async" class="h-8 w-8 object-contain" /><span>{{ team.name }}</span></button></li>
    </ul>
    <span v-if="query.length >= 2 && modelValue?.manual && !loading && !options.length" class="mt-1 block text-xs font-normal text-gray-500">Puedes conservar el nombre escrito si el equipo no aparece.</span>
  </label>
</template>
