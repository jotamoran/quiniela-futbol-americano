<script setup>
import { computed, onMounted, ref } from 'vue';
import { useLoginModalStore } from '@/store/loginModal';
import { useAuthStore } from '@/store/auth';
import { obtenerTemporadaActual } from '@/services/nflService';
import { fechaCortaCDMX } from '@/lib/fechas';

const loginModal = useLoginModalStore();
const auth = useAuthStore();
const temporada = ref(null);
const cargando = ref(true);
const cuota = computed(() => temporada.value ? Number(temporada.value.cuota).toLocaleString('es-MX') : '2,500');
const temporadaActiva = computed(() => temporada.value?.estado === 'activa');

onMounted(async () => {
  try { temporada.value = await obtenerTemporadaActual(); } catch { temporada.value = null; }
  finally { cargando.value = false; }
});
</script>

<template>
  <main>
    <section class="bg-quiniela-azulOscuro px-4 py-12 text-white sm:py-16 lg:py-20">
      <div class="mx-auto grid max-w-6xl items-center gap-10 lg:grid-cols-[1.15fr_.85fr]">
        <div>
          <p class="eyebrow text-blue-200">Quiniela NFL · Temporada regular</p>
          <h1 class="mt-3 max-w-3xl text-4xl font-bold leading-tight sm:text-5xl">Vive cada partido. Suma puntos. Gana cada semana.</h1>
          <p class="mt-5 max-w-2xl text-lg leading-relaxed text-blue-100">Elige quién gana, marca tus pronósticos y sigue tu posición durante toda la temporada NFL.</p>
          <div class="mt-7 flex flex-col gap-3 sm:flex-row">
            <router-link v-if="!auth.isLoggedIn && temporadaActiva" :to="{ name: 'registro' }" class="inline-flex min-h-12 items-center justify-center rounded-xl bg-quiniela-rojo px-6 py-3 font-bold text-white transition hover:bg-quiniela-rojoOscuro">Crear mi cuenta</router-link>
            <router-link v-if="auth.isLoggedIn" :to="{ name: 'mi-temporada' }" class="inline-flex min-h-12 items-center justify-center rounded-xl bg-quiniela-rojo px-6 py-3 font-bold text-white transition hover:bg-quiniela-rojoOscuro">Ir a mi temporada</router-link>
            <router-link v-if="!auth.isLoggedIn && !temporadaActiva" :to="{ name: 'clasificacion-temporada' }" class="inline-flex min-h-12 items-center justify-center rounded-xl border border-white/40 px-6 py-3 font-bold text-white transition hover:bg-white/10">Ver clasificación</router-link>
            <button v-if="!auth.isLoggedIn && temporadaActiva" type="button" @click="loginModal.abrir()" class="min-h-12 rounded-xl border border-white/40 px-6 py-3 font-bold text-white transition hover:bg-white/10">Ya tengo cuenta</button>
          </div>
        </div>
        <div class="rounded-3xl border border-white/15 bg-white/10 p-6 backdrop-blur sm:p-8">
          <img src="@assets/logo.webp" alt="Quiniela Futbol Americano" class="mx-auto w-full max-w-xs object-contain" />
          <div class="mt-6 grid grid-cols-2 gap-3 text-center">
            <div class="rounded-2xl bg-white/10 p-4"><strong class="block text-2xl">1–18</strong><span class="text-sm text-blue-100">Semanas regulares</span></div>
            <div class="rounded-2xl bg-white/10 p-4"><strong class="block text-2xl">$500</strong><span class="text-sm text-blue-100">Premio semanal</span></div>
          </div>
        </div>
      </div>
    </section>

    <section class="page-shell max-w-6xl">
      <div class="grid gap-4 md:grid-cols-3">
        <article class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm"><span class="grid h-10 w-10 place-items-center rounded-full bg-blue-50 font-bold text-quiniela-azul">1</span><h2 class="mt-4 text-lg font-bold text-quiniela-azulOscuro">Acierta partidos</h2><p class="mt-1 text-sm leading-relaxed text-gray-600">Cada resultado correcto suma un punto a tu clasificación.</p></article>
        <article class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm"><span class="grid h-10 w-10 place-items-center rounded-full bg-red-50 font-bold text-quiniela-rojo">+2</span><h2 class="mt-4 text-lg font-bold text-quiniela-azulOscuro">Elige el underdog</h2><p class="mt-1 text-sm leading-relaxed text-gray-600">El partido definido por la administración suma dos puntos extra si aciertas.</p></article>
        <article class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm"><span class="grid h-10 w-10 place-items-center rounded-full bg-amber-50 font-bold text-amber-700">≈</span><h2 class="mt-4 text-lg font-bold text-quiniela-azulOscuro">Desempate automático</h2><p class="mt-1 text-sm leading-relaxed text-gray-600">Indica el total de puntos del partido de desempate; gana quien acierte o quede más cerca.</p></article>
      </div>

      <section class="mt-10 rounded-3xl border border-blue-100 bg-blue-50 p-6 sm:p-8">
        <div class="flex flex-col gap-5 sm:flex-row sm:items-center sm:justify-between">
          <div><p class="eyebrow">{{ temporadaActiva ? 'Inscripción de temporada' : 'Temporada concluida' }}</p><h2 class="mt-1 text-2xl font-bold text-quiniela-azulOscuro">{{ temporada?.nombre ?? 'La temporada NFL' }}</h2><p class="mt-2 max-w-2xl text-sm leading-relaxed text-gray-600">{{ temporadaActiva ? `Cuota de inscripción: $${cuota}. Puedes dejar el pago pendiente y reportarlo después; la fecha límite es ${cargando ? '30 de septiembre' : fechaCortaCDMX(temporada.fecha_limite_pago)}.` : 'Consulta la clasificación y los resultados definitivos de la temporada.' }}</p></div>
          <router-link :to="{ name: auth.isLoggedIn ? 'mi-temporada' : 'clasificacion-temporada' }" class="inline-flex min-h-11 shrink-0 items-center justify-center rounded-xl bg-quiniela-azul px-5 py-2.5 font-bold text-white">{{ auth.isLoggedIn ? 'Ir a mi temporada' : temporadaActiva ? 'Ver registro' : 'Ver clasificación' }}</router-link>
        </div>
      </section>
    </section>
  </main>
</template>
