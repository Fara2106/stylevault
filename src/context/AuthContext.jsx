import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { supabase, isSupabaseEnabled } from '../services/supabaseClient';
import { installNativeHooks, postToNative } from '../utils/nativeBridge';

const AuthContext = createContext(null);

const AUTH_STORAGE_KEY = 'sv_auth_user';

function generateUserId() {
  return `user_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
}

/**
 * Errore di rete (Supabase irraggiungibile, es. progetto Free in pausa dopo
 * inattività): diventa il marker 'service-unreachable' che la UI traduce in
 * un messaggio comprensibile invece del "Failed to fetch" tecnico.
 */
function isUnreachable(error) {
  return (
    error.name === 'AuthRetryableFetchError' ||
    error.status === 0 ||
    /fetch/i.test(error.message || '')
  );
}

/**
 * Errore Supabase → codice che la UI traduce (auth.errors.*). I messaggi
 * originali sono in inglese tecnico ("Invalid login credentials"); un codice
 * sconosciuto passa il messaggio grezzo come ultima risorsa.
 */
const SUPABASE_ERROR_CODES = {
  invalid_credentials: 'invalid-credentials',
  user_already_exists: 'email-taken',
  email_exists: 'email-taken',
  weak_password: 'password-too-short',
  email_not_confirmed: 'email-not-confirmed',
  over_email_send_rate_limit: 'rate-limited',
  over_request_rate_limit: 'rate-limited',
  validation_failed: 'invalid-email',
  email_address_invalid: 'invalid-email',
};

function authError(error) {
  if (isUnreachable(error)) return 'service-unreachable';
  return SUPABASE_ERROR_CODES[error.code] || error.message;
}

/** Mappa l'utente Supabase nella forma usata dall'app. */
function mapSupabaseUser(user) {
  if (!user) return null;
  return {
    id: user.id,
    email: user.email,
    name:
      user.user_metadata?.name ||
      user.user_metadata?.full_name ||
      user.email?.split('@')[0] ||
      '',
  };
}

/**
 * AuthProvider — due modalità:
 * - Supabase (variabili d'ambiente presenti): account veri, email+password e Google.
 * - Locale (Fase A): auth simulata su localStorage, nessun server.
 */
export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  // Il bottone Google compare solo se il provider è davvero attivo su
  // Supabase: prima compariva sempre e cliccarlo dava errore.
  const [googleAvailable, setGoogleAvailable] = useState(false);

  useEffect(() => {
    if (!isSupabaseEnabled) return;
    let alive = true;
    const key = import.meta.env.VITE_SUPABASE_ANON_KEY;
    fetch(`${import.meta.env.VITE_SUPABASE_URL}/auth/v1/settings`, { headers: { apikey: key } })
      .then((res) => (res.ok ? res.json() : null))
      .then((settings) => alive && setGoogleAvailable(Boolean(settings?.external?.google)))
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, []);

  // ── Sessione iniziale ──
  useEffect(() => {
    if (isSupabaseEnabled) {
      // Nell'app iOS il login è nativo: la sessione arriva da lì
      installNativeHooks({
        setSession: (accessToken, refreshToken) =>
          supabase.auth.setSession({ access_token: accessToken, refresh_token: refreshToken }),
      });
      supabase.auth.getSession().then(({ data }) => {
        setUser(mapSupabaseUser(data.session?.user));
        setIsLoading(false);
      });
      const { data: sub } = supabase.auth.onAuthStateChange((_event, session) => {
        setUser(mapSupabaseUser(session?.user));
      });
      return () => sub.subscription.unsubscribe();
    }

    // Modalità locale
    try {
      const stored = localStorage.getItem(AUTH_STORAGE_KEY);
      if (stored) setUser(JSON.parse(stored));
    } catch (e) {
      console.warn('Failed to restore auth session:', e);
      localStorage.removeItem(AUTH_STORAGE_KEY);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // ── Login ──
  const login = useCallback(async (email, password) => {
    if (!email || !password) {
      return { success: false, error: 'missing-fields' };
    }

    if (isSupabaseEnabled) {
      setIsLoading(true);
      const { error } = await supabase.auth.signInWithPassword({ email, password });
      setIsLoading(false);
      if (error) {
        return { success: false, error: authError(error) };
      }
      return { success: true };
    }

    // Modalità locale (mock)
    setIsLoading(true);
    await new Promise((resolve) => setTimeout(resolve, 400));
    const registeredUsers = JSON.parse(localStorage.getItem('sv_registered_users') || '[]');
    const existingUser = registeredUsers.find((u) => u.email === email);

    if (existingUser) {
      if (existingUser.password !== password) {
        setIsLoading(false);
        return { success: false, error: 'invalid-credentials' };
      }
      const userData = {
        id: existingUser.id,
        name: existingUser.name,
        email: existingUser.email,
      };
      setUser(userData);
      localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(userData));
      setIsLoading(false);
      return { success: true };
    }

    const mockUser = { id: generateUserId(), name: email.split('@')[0], email };
    setUser(mockUser);
    localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(mockUser));
    setIsLoading(false);
    return { success: true };
  }, []);

  // ── Registrazione ──
  const register = useCallback(async (name, email, password) => {
    if (!name || !email || !password) {
      return { success: false, error: 'missing-fields' };
    }
    if (password.length < 6) {
      return { success: false, error: 'password-too-short' };
    }

    if (isSupabaseEnabled) {
      setIsLoading(true);
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: { data: { name } },
      });
      setIsLoading(false);
      if (error) {
        return { success: false, error: authError(error) };
      }
      // Con la conferma email attiva non c'è ancora una sessione
      if (!data.session) return { success: true, needsConfirmation: true };
      return { success: true };
    }

    // Modalità locale (mock)
    setIsLoading(true);
    await new Promise((resolve) => setTimeout(resolve, 400));
    const registeredUsers = JSON.parse(localStorage.getItem('sv_registered_users') || '[]');
    if (registeredUsers.some((u) => u.email === email)) {
      setIsLoading(false);
      return { success: false, error: 'email-taken' };
    }

    const newUser = { id: generateUserId(), name, email, password };
    registeredUsers.push(newUser);
    localStorage.setItem('sv_registered_users', JSON.stringify(registeredUsers));

    const userData = { id: newUser.id, name, email };
    setUser(userData);
    localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(userData));
    setIsLoading(false);
    return { success: true };
  }, []);

  // ── Google OAuth (solo con Supabase) ──
  const loginWithGoogle = useCallback(async () => {
    if (!isSupabaseEnabled) {
      return { success: false, error: 'not-available' };
    }
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      // Su GitHub Pages l'app vive in /stylevault/: l'origin da solo è un 404
      options: { redirectTo: new URL(import.meta.env.BASE_URL, window.location.origin).href },
    });
    if (error) {
      return { success: false, error: authError(error) };
    }
    return { success: true }; // il browser viene rediretto
  }, []);

  // ── Logout ──
  const logout = useCallback(async () => {
    if (isSupabaseEnabled) {
      await supabase.auth.signOut();
      setUser(null);
      postToNative('signOut');
      return;
    }
    setUser(null);
    localStorage.removeItem(AUTH_STORAGE_KEY);
  }, []);

  const value = {
    user,
    isAuthenticated: !!user,
    isLoading,
    isCloud: isSupabaseEnabled,
    googleAvailable,
    login,
    register,
    loginWithGoogle,
    logout,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}

export default AuthContext;
