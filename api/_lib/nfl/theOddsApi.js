const API_URL = 'https://api.the-odds-api.com/v4/sports/americanfootball_nfl/odds';
const REQUEST_TIMEOUT_MS = 8000;
const MAX_RETRIES = 2;

function apiKey() {
  const key = process.env.THE_ODDS_API_KEY?.trim();
  if (!key) throw new Error('Falta configurar la clave del servicio de momios');
  return key;
}

function normalizarNombre(nombre) {
  const nombreNormalizado = String(nombre ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
  const alias = {
    lachargers: 'losangeleschargers',
    larams: 'losangelesrams',
    sf49ers: 'sanfrancisco49ers',
    sanfran49ers: 'sanfrancisco49ers',
    nygiants: 'newyorkgiants',
    nyjets: 'newyorkjets',
    nepatriots: 'newenglandpatriots',
    tennesseetitans: 'tennesseetitans',
  };
  return alias[nombreNormalizado] ?? nombreNormalizado;
}

async function request() {
  let ultimoError;
  for (let intento = 0; intento <= MAX_RETRIES; intento += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
    try {
      const url = new URL(API_URL);
      url.search = new URLSearchParams({ apiKey: apiKey(), regions: 'us', markets: 'h2h,spreads', oddsFormat: 'decimal', dateFormat: 'iso' });
      const response = await fetch(url, { signal: controller.signal });
      if (response.status === 429 || response.status >= 500) throw new Error(`Respuesta temporal ${response.status}`);
      if (!response.ok) throw new Error(`El servicio de momios respondió ${response.status}`);
      return await response.json();
    } catch (error) {
      ultimoError = error.name === 'AbortError' ? new Error('El servicio de momios tardó demasiado en responder') : error;
      if (intento === MAX_RETRIES) throw ultimoError;
      await new Promise((resolve) => setTimeout(resolve, 250 * (intento + 1)));
    } finally {
      clearTimeout(timeout);
    }
  }
  throw ultimoError;
}

function promedioValores(valores) {
  return valores.length ? valores.reduce((total, valor) => total + valor, 0) / valores.length : null;
}

export function determinarUnderdog(evento) {
  const mercados = (evento?.bookmakers ?? []).flatMap((bookmaker) => bookmaker.markets ?? []);
  const spreads = mercados.filter((mercado) => mercado.key === 'spreads');
  const h2h = mercados.filter((mercado) => mercado.key === 'h2h');
  const puntos = new Map();
  for (const mercado of spreads) {
    for (const outcome of mercado.outcomes ?? []) {
      const punto = Number(outcome.point);
      if (Number.isFinite(punto)) puntos.set(outcome.name, [...(puntos.get(outcome.name) ?? []), punto]);
    }
  }
  const candidatosSpread = [...puntos.entries()]
    .map(([nombre, valores]) => ({ nombre, valor: promedioValores(valores) }))
    .filter((candidato) => candidato.valor !== null)
    .sort((a, b) => b.valor - a.valor);
  if (candidatosSpread.length >= 2 && candidatosSpread[0].valor !== candidatosSpread[1].valor) return candidatosSpread[0].nombre;

  const precios = new Map();
  for (const mercado of h2h) {
    for (const outcome of mercado.outcomes ?? []) {
      const precio = Number(outcome.price);
      if (Number.isFinite(precio)) precios.set(outcome.name, [...(precios.get(outcome.name) ?? []), precio]);
    }
  }
  const candidatosH2H = [...precios.entries()]
    .map(([nombre, valores]) => ({ nombre, valor: promedioValores(valores) }))
    .filter((candidato) => candidato.valor !== null)
    .sort((a, b) => b.valor - a.valor);
  return candidatosH2H.length >= 2 && candidatosH2H[0].valor !== candidatosH2H[1].valor ? candidatosH2H[0].nombre : null;
}

export function emparejarEvento(eventos, juego) {
  const visitante = normalizarNombre(juego.equipo_visitante);
  const local = normalizarNombre(juego.equipo_local);
  const fechaPartido = new Date(juego.fecha_partido).getTime();
  return (eventos ?? []).find((evento) => {
    const mismosEquipos = normalizarNombre(evento.away_team) === visitante && normalizarNombre(evento.home_team) === local;
    const fechaEvento = new Date(evento.commence_time).getTime();
    return mismosEquipos && Number.isFinite(fechaPartido) && Number.isFinite(fechaEvento) && Math.abs(fechaEvento - fechaPartido) <= 36 * 60 * 60 * 1000;
  }) ?? null;
}

export async function obtenerUnderdogs(juegos) {
  const eventos = await request();
  return juegos.map((juego) => {
    const evento = emparejarEvento(eventos, juego);
    const equipo = determinarUnderdog(evento);
    if (!evento || !equipo) return { gameId: juego.id, underdog: null, underdogTeam: null };
    return {
      gameId: juego.id,
      underdog: normalizarNombre(equipo) === normalizarNombre(evento.home_team) ? 'L' : 'V',
      underdogTeam: equipo,
    };
  });
}
