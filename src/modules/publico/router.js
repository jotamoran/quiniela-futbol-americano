export default [
  { path: '/', name: 'inicio', component: () => import('./views/Inicio.vue') },
  { path: '/clasificacion', name: 'clasificacion-temporada', component: () => import('./views/Clasificacion.vue') },
  { path: '/clasificacion/semana/:semanaId', name: 'clasificacion-semana', component: () => import('./views/Clasificacion.vue') },
];
