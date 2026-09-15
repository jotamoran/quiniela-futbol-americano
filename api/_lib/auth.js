import { getSupabaseAdmin } from './supabaseAdmin.js';

export class ErrorHttp extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export async function requireAdmin(req) {
  const token = String(req.headers.authorization ?? '').replace(/^Bearer\s+/i, '');
  if (!token) throw new ErrorHttp(401, 'Falta el token de autenticación');

  const supabase = getSupabaseAdmin();
  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) throw new ErrorHttp(401, 'Token inválido o expirado');

  const { data: perfil, error: perfilError } = await supabase.from('perfiles').select('rol').eq('id', user.id).maybeSingle();
  if (perfilError) throw perfilError;
  if (perfil?.rol !== 'admin') throw new ErrorHttp(403, 'Requiere rol de administrador');
  return user;
}
