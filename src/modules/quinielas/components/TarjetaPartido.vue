<script setup>
const props = defineProps({ juego: { type: Object, required: true }, modelValue: { type: String, default: '' }, underdogSeleccionado: { type: Boolean, default: false }, disabled: Boolean });
const emit = defineEmits(['update:modelValue', 'seleccionar-underdog']);

function fecha(fechaPartido) {
  return new Intl.DateTimeFormat('es-MX', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', timeZone: 'America/Mexico_City' }).format(new Date(fechaPartido));
}
</script>

<template>
  <article class="rounded-2xl border bg-white p-4 shadow-sm transition" :class="props.underdogSeleccionado ? 'border-quiniela-rojo ring-2 ring-red-100' : juego.estado === 'cancelado' ? 'border-gray-200 bg-gray-50 opacity-70' : 'border-gray-200'">
    <div class="mb-3 flex items-center justify-between gap-3 text-xs text-gray-500">
      <span>{{ fecha(juego.fecha_partido) }} · CDMX</span>
      <span class="flex flex-wrap justify-end gap-1"><span v-if="props.underdogSeleccionado" class="rounded-full bg-red-50 px-2 py-1 font-bold text-quiniela-rojo">Tu underdog · +2</span><span v-if="juego.underdog_lado" class="rounded-full bg-amber-50 px-2 py-1 font-bold text-amber-800">No favorito: {{ juego.underdog_lado === 'L' ? juego.equipo_local : juego.equipo_visitante }}</span><span v-if="juego.desempate" class="rounded-full bg-blue-50 px-2 py-1 font-bold text-quiniela-azul">Desempate</span><span v-if="juego.estado === 'cancelado'" class="rounded-full bg-gray-200 px-2 py-1 font-bold text-gray-600">Cancelado</span></span>
    </div>
    <div class="grid grid-cols-2 gap-3" role="radiogroup" :aria-label="`Pronóstico para ${juego.equipo_visitante} contra ${juego.equipo_local}`">
      <button v-for="opcion in [{ valor: 'V', equipo: juego.equipo_visitante, lugar: 'Visitante', logo: juego.logo_visitante }, { valor: 'L', equipo: juego.equipo_local, lugar: 'Local', logo: juego.logo_local }]" :key="opcion.valor" type="button" role="radio" :disabled="disabled || juego.estado === 'cancelado'" :aria-label="`${opcion.lugar}: ${opcion.equipo}`" :aria-checked="modelValue === opcion.valor" @click="$emit('update:modelValue', opcion.valor)" class="min-h-24 min-w-0 overflow-hidden rounded-xl border p-3 text-left transition disabled:opacity-50" :class="modelValue === opcion.valor ? 'border-quiniela-rojo bg-red-50 text-quiniela-rojoOscuro' : 'border-gray-200 hover:border-quiniela-azul'">
        <span class="block text-[10px] font-bold uppercase tracking-widest opacity-60">{{ opcion.lugar }}</span>
        <span class="mt-2 flex min-w-0 items-center gap-2"><img v-if="opcion.logo" :src="opcion.logo" alt="" loading="lazy" decoding="async" class="h-9 w-9 shrink-0 object-contain" /><strong class="block min-w-0 break-words text-sm leading-tight">{{ opcion.equipo }}</strong></span>
      </button>
    </div>
    <button type="button" :disabled="disabled || juego.estado === 'cancelado' || !juego.underdog_lado" :aria-pressed="props.underdogSeleccionado" @click="emit('seleccionar-underdog')" class="mt-3 min-h-11 w-full rounded-xl border px-3 py-2 text-sm font-semibold transition disabled:cursor-not-allowed disabled:opacity-50" :class="props.underdogSeleccionado ? 'border-quiniela-rojo bg-red-50 text-quiniela-rojoOscuro' : 'border-gray-300 text-gray-700 hover:border-quiniela-rojo'">{{ props.underdogSeleccionado ? 'Tu underdog · +2 si aciertas' : 'Elegir este partido como underdog' }}</button>
    <p v-if="!juego.underdog_lado && juego.estado !== 'cancelado'" class="mt-2 text-center text-xs text-amber-700">Los momios de este partido todavía no están disponibles.</p>
  </article>
</template>
