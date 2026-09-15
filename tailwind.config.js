import aspectRatio from '@tailwindcss/aspect-ratio';
import forms from '@tailwindcss/forms';
import { quinielaColors } from './src/theme/quiniela.js';

/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{vue,js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        quiniela: {
          azulOscuro: quinielaColors.azulOscuro,
          azul: quinielaColors.azul,
          azulAcento: quinielaColors.azulAcento,
          rojo: quinielaColors.rojo,
          rojoOscuro: quinielaColors.rojoOscuro,
          grisClaro: quinielaColors.grisClaro,
          grisTexto: quinielaColors.grisTexto,
          error: quinielaColors.error,
          advertencia: quinielaColors.advertencia,
        }
      }
    },
  },
  plugins: [aspectRatio, forms],
}
