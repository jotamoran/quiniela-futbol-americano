import Swal from 'sweetalert2';
import { quinielaColors } from '@/theme/quiniela.js';

const base = {
  confirmButtonColor: quinielaColors.azul,
  cancelButtonColor: '#6b7280',
  customClass: {
    container: 'swal-sobre-modal',
    popup: 'swal-responsive rounded-2xl',
    confirmButton: 'swal-boton',
    cancelButton: 'swal-boton',
  },
};

export function alertaExito(title, text = '') {
  return Swal.fire({ ...base, icon: 'success', title, text });
}

export function alertaError(error, title = 'No se pudo completar') {
  return Swal.fire({ ...base, icon: 'error', title, text: error?.message ?? String(error) });
}

export function alertaAdvertencia(title, text = '') {
  return Swal.fire({ ...base, icon: 'warning', title, text });
}

export async function confirmarAccion({ title, text, confirmText = 'Confirmar', danger = false }) {
  const result = await Swal.fire({ ...base, icon: 'question', title, text, showCancelButton: true, reverseButtons: true, focusCancel: danger, confirmButtonText: confirmText, cancelButtonText: 'Cancelar', confirmButtonColor: danger ? quinielaColors.error : base.confirmButtonColor });
  return result.isConfirmed;
}
