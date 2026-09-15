<script setup>
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { registrar, usernameDisponible, traducirErrorAuth } from '../services/authService';
import { alertaError } from '@/lib/alertas';
import CampoPassword from '@/components/CampoPassword.vue';
import { obtenerDatosBancariosNFL, obtenerTemporadaActiva } from '@/services/nflService';

const nombreCompleto = ref('');
const email = ref('');
const username = ref('');
const password = ref('');
const confirmarPassword = ref('');
const cargando = ref(false);
const temporada = ref(null);
const opcionPago = ref('pendiente');
const referenciaPago = ref('');
const datosBancarios = ref(null);
const router = useRouter();

const PATRON_USERNAME = /^[a-z0-9_]{3,20}$/;

async function onSubmit() {
  cargando.value = true;
  try {
    const usernameNormalizado = username.value.trim().toLowerCase();
    if (!PATRON_USERNAME.test(usernameNormalizado)) {
      await alertaError(new Error('Usa de 3 a 20 caracteres: letras minúsculas, números o guion bajo.'), 'Usuario no válido');
      return;
    }
    if (!(await usernameDisponible(usernameNormalizado))) {
      await alertaError(new Error('Elige otro nombre para continuar.'), 'Ese usuario ya está en uso');
      return;
    }
    if (!temporada.value) throw new Error('No hay una temporada abierta para inscripciones.');
    if (opcionPago.value === 'reportar' && referenciaPago.value.trim().length < 3) {
      await alertaError(new Error('Escribe la referencia o últimos dígitos de la transferencia.'), 'Falta la referencia');
      return;
    }
    if (password.value !== confirmarPassword.value) {
      await alertaError(new Error('Las contraseñas no coinciden.'), 'Verifica tu contraseña');
      return;
    }
    await registrar({
      email: email.value,
      password: password.value,
      nombreCompleto: nombreCompleto.value,
      username: usernameNormalizado,
      temporadaId: temporada.value.id,
      reportarPago: opcionPago.value === 'reportar',
      referenciaPago: referenciaPago.value.trim(),
    });
    router.push({ name: 'verificar-codigo', query: { email: email.value } });
  } catch (e) {
    const mensaje = /database error/i.test(e.message) ? 'Ese nombre de usuario ya está en uso. Elige otro.' : traducirErrorAuth(e.message);
    await alertaError(new Error(mensaje), 'No se pudo crear la cuenta');
  } finally {
    cargando.value = false;
  }
}

onMounted(async () => {
  try { [temporada.value, datosBancarios.value] = await Promise.all([obtenerTemporadaActiva(), obtenerDatosBancariosNFL()]); }
  catch (e) { await alertaError(e, 'No se pudo cargar la temporada'); }
});
</script>

<template>
  <div class="auth-page">
    <form @submit.prevent="onSubmit" class="auth-card">
      <img src="@assets/logo.webp" alt="Quiniela NFL" class="auth-logo" />
      <div class="space-y-1"><h1 class="auth-title">Únete a la temporada</h1><p class="auth-description">{{ temporada ? `${temporada.nombre} · Cuota $${Number(temporada.cuota).toLocaleString('es-MX')}` : 'No hay una temporada abierta' }}</p></div>
      <label class="form-label">Nombre completo<input v-model="nombreCompleto" type="text" autocomplete="name" placeholder="Tu nombre" required class="form-control min-h-11" /></label>
      <label class="form-label">Correo<input v-model="email" type="email" autocomplete="email" placeholder="correo@ejemplo.com" required class="form-control min-h-11" /></label>
      <label class="form-label">Nombre de usuario<input v-model="username" type="text" autocomplete="username" placeholder="letras, números y _ (3-20)" required minlength="3" maxlength="20" pattern="[a-z0-9_]{3,20}" class="form-control min-h-11" @input="username = username.toLowerCase()" /></label>
      <CampoPassword v-model="password" autocomplete="new-password" placeholder="Mínimo 6 caracteres" :minlength="6" />
      <CampoPassword v-model="confirmarPassword" label="Confirmar contraseña" autocomplete="new-password" placeholder="Repite tu contraseña" :minlength="6" />
      <fieldset v-if="temporada" class="space-y-2 rounded-xl border border-gray-200 p-3">
        <legend class="px-1 text-sm font-semibold text-gray-700">Pago de temporada</legend>
        <label class="flex cursor-pointer gap-2 text-sm"><input v-model="opcionPago" type="radio" value="pendiente" /> Lo pagaré después</label>
        <label class="flex cursor-pointer gap-2 text-sm"><input v-model="opcionPago" type="radio" value="reportar" /> Ya hice la transferencia</label>
        <dl v-if="opcionPago === 'reportar' && datosBancarios?.clabe" class="rounded-lg bg-blue-50 p-3 text-sm"><div><dt class="text-gray-500">Banco</dt><dd class="font-semibold">{{ datosBancarios.banco }}</dd></div><div class="mt-1"><dt class="text-gray-500">CLABE</dt><dd class="break-all font-semibold">{{ datosBancarios.clabe }}</dd></div><div class="mt-1"><dt class="text-gray-500">Titular</dt><dd class="font-semibold">{{ datosBancarios.titular }}</dd></div></dl>
        <p v-else-if="opcionPago === 'reportar'" class="rounded-lg bg-amber-50 p-3 text-xs text-amber-800">Los datos de transferencia todavía no están publicados. Puedes registrarte y dejar el pago pendiente.</p>
        <label v-if="opcionPago === 'reportar'" class="form-label">Referencia o últimos dígitos<input v-model="referenciaPago" maxlength="200" class="form-control min-h-11" required /></label>
        <p class="text-xs text-gray-500">El administrador confirmará el pago. Puedes participar mientras llega la fecha límite.</p>
      </fieldset>
      <button type="submit" :disabled="cargando || !temporada" class="primary-action">
        {{ cargando ? 'Creando...' : 'Registrarme' }}
      </button>
      <p class="text-center text-sm text-gray-600">¿Ya tienes cuenta? <router-link :to="{ name: 'login' }" class="auth-link">Inicia sesión</router-link></p>
    </form>
  </div>
</template>
