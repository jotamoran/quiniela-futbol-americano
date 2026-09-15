<script setup>
import { onMounted, computed } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from '@/store/auth';
import AppLayout from '@/layouts/AppLayout.vue';
import AuthLayout from '@/layouts/AuthLayout.vue';
import LoginModal from '@/components/LoginModal.vue';

const route = useRoute();
const authStore = useAuthStore();
onMounted(() => authStore.init());

// Cada layout ya renderiza su propio <router-view /> internamente, así que
// basta con montar el layout correcto según el tipo de ruta actual.
const layout = computed(() => {
  if (route.meta.guestOnly) return AuthLayout;
  return AppLayout;
});
</script>

<template>
  <component :is="layout" />
  <LoginModal />
</template>
