<script setup>
import { onUnmounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { reenviarCodigo, verificarCodigo } from '../services/authService';
import { alertaError, alertaExito } from '@/lib/alertas';

const route = useRoute();
const router = useRouter();
const email = ref(route.query.email ?? '');
const codigo = ref('');
const cargando = ref(false);
const reenviando = ref(false);
const esperaReenvio = ref(0);
let intervalo;

async function onSubmit() {
  codigo.value = codigo.value.replace(/\D/g, '').slice(0, 6);
  if (codigo.value.length !== 6) {
    await alertaError(new Error('Escribe los 6 dígitos del código.'), 'Código incompleto');
    return;
  }
  cargando.value = true;
  try {
    await verificarCodigo({ email: email.value, codigo: codigo.value });
    await alertaExito('Correo verificado', 'Tu cuenta ya está lista para usarse.');
    router.push({ name: 'mi-temporada' });
  } catch (e) {
    await alertaError(e, 'No se pudo verificar el código');
  } finally {
    cargando.value = false;
  }
}

async function reenviar() {
  if (reenviando.value || esperaReenvio.value > 0) return;
  reenviando.value = true;
  try {
    await reenviarCodigo(email.value);
    esperaReenvio.value = 30;
    clearInterval(intervalo);
    intervalo = setInterval(() => {
      esperaReenvio.value -= 1;
      if (esperaReenvio.value <= 0) clearInterval(intervalo);
    }, 1000);
    await alertaExito('Código reenviado', 'Revisa tu correo nuevamente.');
  } catch (e) { await alertaError(e, 'No se pudo reenviar el código'); }
  finally { reenviando.value = false; }
}

onUnmounted(() => clearInterval(intervalo));
</script>

<template>
  <div class="auth-page">
    <form @submit.prevent="onSubmit" class="auth-card">
      <img src="@assets/logo.webp" alt="Quiniela NFL" class="auth-logo" />
      <div class="space-y-1"><h1 class="auth-title">Verifica tu correo</h1><p class="auth-description">Enviamos un código a <span class="font-semibold text-gray-700 break-all">{{ email }}</span></p></div>
      <label class="form-label">Código de verificación<input v-model="codigo" type="text" inputmode="numeric" autocomplete="one-time-code" minlength="6" maxlength="6" pattern="[0-9]{6}" placeholder="Código de 6 dígitos" required class="form-control min-h-11 tracking-widest" @input="codigo = codigo.replace(/\D/g, '').slice(0, 6)" /></label>
      <button type="submit" :disabled="cargando" class="primary-action">
        {{ cargando ? 'Verificando...' : 'Verificar' }}
      </button>
      <button type="button" :disabled="reenviando || esperaReenvio > 0" @click="reenviar" class="auth-link mx-auto block disabled:cursor-wait disabled:opacity-50">{{ reenviando ? 'Reenviando…' : esperaReenvio > 0 ? `Reenviar en ${esperaReenvio}s` : 'Reenviar código' }}</button>
      <router-link :to="{ name: 'registro' }" class="auth-link block text-center">← Corregir correo</router-link>
    </form>
  </div>
</template>
