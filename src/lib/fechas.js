const ZONA_CDMX = 'America/Mexico_City';

function formatear(valor, opciones) {
  if (!valor) return '';
  const fecha = new Date(valor);
  return Number.isNaN(fecha.getTime()) ? '' : new Intl.DateTimeFormat('es-MX', { ...opciones, timeZone: ZONA_CDMX }).format(fecha);
}

export function fechaHoraCDMX(valor) {
  return formatear(valor, { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
}

export function fechaCortaCDMX(valor) {
  return formatear(valor, { day: 'numeric', month: 'short', year: 'numeric' });
}

export function fechaInputCDMX(valor) {
  if (!valor) return '';
  const fecha = new Date(valor);
  if (Number.isNaN(fecha.getTime())) return '';
  const partes = new Intl.DateTimeFormat('en-CA', {
    year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23', timeZone: ZONA_CDMX,
  }).formatToParts(fecha).reduce((resultado, parte) => ({ ...resultado, [parte.type]: parte.value }), {});
  return `${partes.year}-${partes.month}-${partes.day}T${partes.hour}:${partes.minute}`;
}
