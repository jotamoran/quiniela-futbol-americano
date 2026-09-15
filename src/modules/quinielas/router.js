export default [
  { path: '/mi-temporada', name: 'mi-temporada', component: () => import('./views/MiTemporada.vue'), meta: { requiresAuth: true } },
  { path: '/mis-quinielas', redirect: { name: 'mi-temporada' } },
  { path: '/semana/:semanaId?', name: 'llenar-quiniela', component: () => import('./views/LlenarQuiniela.vue') },
];
