<script setup>
defineProps({ juego: { type: Object, required: true }, modelValue: { type: String, default: '' }, disabled: Boolean });
defineEmits(['update:modelValue']);

function fecha(fechaPartido) {
  return new Intl.DateTimeFormat('es-MX', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', timeZone: 'America/Mexico_City' }).format(new Date(fechaPartido));
}
</script>

<template>
  <article class="rounded-2xl border bg-white p-4 shadow-sm transition" :class="juego.underdog ? 'border-quiniela-rojo ring-2 ring-red-100' : juego.estado === 'cancelado' ? 'border-gray-200 bg-gray-50 opacity-70' : 'border-gray-200'">
    <div class="mb-3 flex items-center justify-between gap-3 text-xs text-gray-500">
      <span>{{ fecha(juego.fecha_partido) }} · CDMX</span>
      <span class="flex flex-wrap justify-end gap-1"><span v-if="juego.underdog" class="rounded-full bg-red-50 px-2 py-1 font-bold text-quiniela-rojo">Underdog · +2</span><span v-if="juego.desempate" class="rounded-full bg-blue-50 px-2 py-1 font-bold text-quiniela-azul">Desempate</span><span v-if="juego.estado === 'cancelado'" class="rounded-full bg-gray-200 px-2 py-1 font-bold text-gray-600">Cancelado</span></span>
    </div>
    <div class="grid grid-cols-2 gap-3">
      <button v-for="opcion in [{ valor: 'V', equipo: juego.equipo_visitante, lugar: 'Visitante', logo: juego.logo_visitante }, { valor: 'L', equipo: juego.equipo_local, lugar: 'Local', logo: juego.logo_local }]" :key="opcion.valor" type="button" :disabled="disabled || juego.estado === 'cancelado'" @click="$emit('update:modelValue', opcion.valor)" class="min-h-24 rounded-xl border p-3 text-left transition disabled:opacity-50" :class="modelValue === opcion.valor ? 'border-quiniela-rojo bg-red-50 text-quiniela-rojoOscuro' : 'border-gray-200 hover:border-quiniela-azul'">
        <span class="block text-[10px] font-bold uppercase tracking-widest opacity-60">{{ opcion.lugar }}</span>
        <span class="mt-2 flex items-center gap-2"><img v-if="opcion.logo" :src="opcion.logo" alt="" class="h-9 w-9 shrink-0 object-contain" /><strong class="block">{{ opcion.equipo }}</strong></span>
      </button>
    </div>
    <p v-if="juego.underdog" class="mt-3 rounded-xl bg-red-50 px-3 py-2 text-center text-sm font-semibold text-quiniela-rojoOscuro">Tu elección en este partido recibe 2 puntos adicionales si aciertas.</p>
  </article>
</template>
