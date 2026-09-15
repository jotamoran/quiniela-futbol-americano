export default [
  { path: '/admin/jornadas', name: 'admin-jornadas', component: () => import('./views/ConfigurarNFL.vue'), meta: { requiresAuth: true, requiresAdmin: true } },
  { path: '/admin/participantes', name: 'admin-participantes', component: () => import('./views/ParticipantesTemporada.vue'), meta: { requiresAuth: true, requiresAdmin: true } },
  { path: '/admin/sincronizar', name: 'admin-sincronizar', component: () => import('./views/ResultadosNFL.vue'), meta: { requiresAuth: true, requiresAdmin: true } },
];
