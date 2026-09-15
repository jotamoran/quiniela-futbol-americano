<script setup>
defineProps({ juego: { type: Object, required: true }, modelValue: { type: String, default: '' }, underdog: Boolean, disabled: Boolean });
defineEmits(['update:modelValue', 'underdog']);

function fecha(fechaPartido) {
  return new Intl.DateTimeFormat('es-MX', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', timeZone: 'America/Mexico_City' }).format(new Date(fechaPartido));
}
</script>

<template>
  <article class="rounded-2xl border bg-white p-4 shadow-sm transition" :class="underdog ? 'border-quiniela-rojo ring-2 ring-red-100' : 'border-gray-200'">
    <div class="mb-3 flex items-center justify-between gap-3 text-xs text-gray-500">
      <span>{{ fecha(juego.fecha_partido) }} · CDMX</span>
      <span v-if="juego.desempate" class="rounded-full bg-blue-50 px-2 py-1 font-bold text-quiniela-azul">Desempate</span>
    </div>
    <div class="grid grid-cols-2 gap-3">
      <button v-for="opcion in [{ valor: 'V', equipo: juego.equipo_visitante, lugar: 'Visitante', logo: juego.logo_visitante }, { valor: 'L', equipo: juego.equipo_local, lugar: 'Local', logo: juego.logo_local }]" :key="opcion.valor" type="button" :disabled="disabled" @click="$emit('update:modelValue', opcion.valor)" class="min-h-20 rounded-xl border p-3 text-left transition disabled:opacity-50" :class="modelValue === opcion.valor ? 'border-quiniela-rojo bg-red-50 text-quiniela-rojoOscuro' : 'border-gray-200 hover:border-quiniela-azul'">
        <span class="block text-[10px] font-bold uppercase tracking-widest opacity-60">{{ opcion.lugar }}</span>
        <span class="mt-2 flex items-center gap-2"><img v-if="opcion.logo" :src="opcion.logo" alt="" class="h-9 w-9 shrink-0 object-contain" /><strong class="block">{{ opcion.equipo }}</strong></span>
      </button>
    </div>
    <button type="button" :disabled="disabled || !modelValue" @click="$emit('underdog')" class="mt-3 min-h-11 w-full rounded-xl border px-3 py-2 text-sm font-semibold disabled:opacity-40" :class="underdog ? 'border-quiniela-rojo bg-quiniela-rojo text-white' : 'border-gray-300 text-gray-600'">
      {{ underdog ? '★ Mi underdog · +2 si acierta' : 'Elegir mi underdog' }}
    </button>
  </article>
</template>
