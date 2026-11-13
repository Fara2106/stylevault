// Edge Function: manda per email (Resend) le segnalazioni della pagina Feedback.
// Deploy: `supabase functions deploy send-feedback --no-verify-jwt` (o dalla
// dashboard con "Verify JWT" spento): l'utente lo controlla la funzione stessa,
// perché la chiave pubblicabile `sb_publishable_…` non è un JWT.
// Secret (Dashboard → Edge Functions → Secrets):
//   RESEND_API_KEY  chiave di Resend
//   FEEDBACK_TO     indirizzo che riceve le segnalazioni (non sta nel repo)
//   FEEDBACK_FROM   facoltativo, mittente; di base onboarding@resend.dev, che
//                   col piano gratuito scrive solo all'email dell'account Resend
import { allowSend, buildEmail, parseFeedback } from './feedback.ts';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const sent = new Map<string, number[]>();

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

/** Utente dal token della sessione (null se manca o è scaduto). */
async function currentUserId(req: Request): Promise<string | null> {
  const auth = req.headers.get('Authorization') ?? '';
  const url = Deno.env.get('SUPABASE_URL');
  // La chiave pubblicabile che manda il client; la legacy anon key può essere spenta
  const key = req.headers.get('apikey') ?? Deno.env.get('SUPABASE_ANON_KEY');
  if (!auth.startsWith('Bearer ') || !url || !key) return null;
  const res = await fetch(`${url}/auth/v1/user`, {
    headers: { Authorization: auth, apikey: key },
  });
  if (!res.ok) return null;
  const user = await res.json();
  return typeof user?.id === 'string' ? user.id : null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return reply(405, { error: 'feedback-invalid' });

  const userId = await currentUserId(req);
  if (!userId) return reply(401, { error: 'feedback-auth' });

  const feedback = parseFeedback(await req.json().catch(() => null));
  if (!feedback) return reply(400, { error: 'feedback-invalid' });

  if (!allowSend(sent, userId, Date.now())) return reply(429, { error: 'feedback-limit' });

  const apiKey = Deno.env.get('RESEND_API_KEY');
  const to = Deno.env.get('FEEDBACK_TO');
  if (!apiKey || !to) return reply(500, { error: 'feedback-failed' });

  const { subject, text } = buildEmail(feedback, new Date());
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: Deno.env.get('FEEDBACK_FROM') ?? 'StyleVault <onboarding@resend.dev>',
      to: [to],
      subject,
      text,
    }),
  });
  if (!res.ok) {
    // Nei log della funzione solo lo stato: il testo della segnalazione no
    console.error('resend', res.status);
    return reply(502, { error: 'feedback-failed' });
  }
  return reply(200, { ok: true });
});
