<script setup>
import NavbarComponent from '@/components/NavbarComponent.vue';
import FooterComponent from '@/components/FooterComponent.vue';
</script>

<template>
  <div class="flex min-h-screen flex-col bg-quiniela-grisClaro">
    <a href="#contenido-principal" class="sr-only focus:not-sr-only focus:fixed focus:left-3 focus:top-3 focus:z-50 focus:rounded-lg focus:bg-white focus:px-4 focus:py-3 focus:font-semibold focus:text-quiniela-azulOscuro">Saltar al contenido</a>
    <NavbarComponent />
    <div id="contenido-principal" tabindex="-1" class="flex-1 outline-none"><router-view /></div>
    <FooterComponent />
  </div>
</template>
