export default [
  { path: '/', redirect: { name: 'clasificacion-temporada' } },
  { path: '/clasificacion', name: 'clasificacion-temporada', component: () => import('./views/Clasificacion.vue') },
  { path: '/clasificacion/semana/:semanaId', name: 'clasificacion-semana', component: () => import('./views/Clasificacion.vue') },
];
