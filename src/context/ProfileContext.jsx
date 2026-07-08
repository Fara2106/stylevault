import {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  useRef,
} from 'react';
import { useAuth } from './AuthContext';
import { useSettings } from './SettingsContext';
import { isSupabaseEnabled } from '../services/supabaseClient';
import { fetchProfile, upsertProfile } from '../services/db';
import { DEFAULT_AVATAR_CONFIG } from '../utils/avatarOptions';

const ProfileContext = createContext(null);

// Modalità locale: profilo per-utente in localStorage (Fase A)
const profileKey = (userId) => `sv_profile_${userId || 'anon'}`;

const DEFAULT_PROFILE = {
  avatarConfig: DEFAULT_AVATAR_CONFIG,
  referencePhoto: null,
  onboarded: false,
};

function loadLocalProfile(userId) {
  try {
    const stored = localStorage.getItem(profileKey(userId));
    if (stored) return { ...DEFAULT_PROFILE, ...JSON.parse(stored) };
  } catch (e) {
    console.warn('Failed to load profile:', e);
  }
  return DEFAULT_PROFILE;
}

/**
 * ProfileProvider — avatar, foto di riferimento, onboarding.
 * In modalità cloud il profilo (incluse lingua e città predefinita) vive nella
 * tabella `profiles` di Supabase e la foto di riferimento su Storage.
 */
export function ProfileProvider({ children }) {
  const { user } = useAuth();
  const settings = useSettings();
  const userId = user?.id;

  const [profile, setProfile] = useState(() =>
    isSupabaseEnabled ? DEFAULT_PROFILE : loadLocalProfile(userId)
  );
  // In cloud il profilo arriva in ritardo: finché carica, i redirect aspettano
  const [profileLoading, setProfileLoading] = useState(isSupabaseEnabled);
  // In cloud: true quando il profilo remoto è stato caricato (evita sync premature)
  const loadedRef = useRef(!isSupabaseEnabled);
  const applyingRemoteRef = useRef(false);

  // Modalità locale: il profilo dell'utente va caricato nello stesso render in
  // cui compare lo userId (la sessione arriva da un effect), altrimenti
  // Protected legge onboarded=false stantio e rimbalza sull'onboarding a ogni
  // refresh di una pagina protetta.
  const [profileUserId, setProfileUserId] = useState(userId);
  if (!isSupabaseEnabled && profileUserId !== userId) {
    setProfileUserId(userId);
    setProfile(loadLocalProfile(userId));
  }

  // ── Caricamento al cambio utente (cloud) ──
  useEffect(() => {
    if (!isSupabaseEnabled) return;
    loadedRef.current = false;
    if (!userId) {
      setProfile(DEFAULT_PROFILE);
      setProfileLoading(false);
      return;
    }
    setProfileLoading(true);
    let alive = true;
    fetchProfile(userId)
      .then((remote) => {
        if (!alive) return;
        if (remote) {
          setProfile({
            avatarConfig: remote.avatarConfig || DEFAULT_AVATAR_CONFIG,
            referencePhoto: remote.referencePhoto,
            onboarded: remote.onboarded,
          });
          // Applica lingua e città salvate sul cloud
          applyingRemoteRef.current = true;
          if (remote.language) settings.setLanguage(remote.language);
          if (remote.defaultCity) settings.setDefaultCity(remote.defaultCity);
          queueMicrotask(() => {
            applyingRemoteRef.current = false;
          });
        }
        loadedRef.current = true;
        setProfileLoading(false);
      })
      .catch((e) => {
        console.warn('Profile load failed:', e);
        loadedRef.current = true;
        setProfileLoading(false);
      });
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId]);

  // ── Persistenza locale (solo Fase A) ──
  useEffect(() => {
    if (isSupabaseEnabled) return;
    try {
      localStorage.setItem(profileKey(userId), JSON.stringify(profile));
    } catch (e) {
      console.warn('Failed to save profile:', e);
    }
  }, [profile, userId]);

  // ── Sync impostazioni → cloud (lingua e città) ──
  useEffect(() => {
    if (!isSupabaseEnabled || !userId || !loadedRef.current) return;
    if (applyingRemoteRef.current) return;
    upsertProfile(userId, {
      language: settings.language,
      defaultCity: settings.defaultCity,
    }).catch((e) => console.warn('Settings sync failed:', e));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [settings.language, settings.defaultCity, userId]);

  const persistCloud = useCallback(
    (updates) => {
      if (!isSupabaseEnabled || !userId) return;
      upsertProfile(userId, updates).catch((e) =>
        console.warn('Profile sync failed:', e)
      );
    },
    [userId]
  );

  const setAvatarConfig = useCallback(
    (updates) => {
      setProfile((prev) => {
        const merged = { ...prev.avatarConfig, ...updates };
        persistCloud({ avatarConfig: merged });
        return { ...prev, avatarConfig: merged };
      });
    },
    [persistCloud]
  );

  const setReferencePhoto = useCallback(
    (dataUrl) => {
      // Ottimistico: il dataURL si vede subito; il cloud risponde con l'URL firmata
      setProfile((prev) => ({ ...prev, referencePhoto: dataUrl }));
      if (isSupabaseEnabled && userId) {
        upsertProfile(userId, { referencePhoto: dataUrl })
          .then((signed) => {
            if (signed) setProfile((prev) => ({ ...prev, referencePhoto: signed }));
          })
          .catch((e) => console.warn('Reference photo sync failed:', e));
      }
    },
    [userId]
  );

  const completeOnboarding = useCallback(() => {
    setProfile((prev) => ({ ...prev, onboarded: true }));
    persistCloud({ onboarded: true });
  }, [persistCloud]);

  const value = {
    avatarConfig: profile.avatarConfig,
    referencePhoto: profile.referencePhoto,
    onboarded: profile.onboarded,
    profileLoading,
    setAvatarConfig,
    setReferencePhoto,
    completeOnboarding,
  };

  return (
    <ProfileContext.Provider value={value}>{children}</ProfileContext.Provider>
  );
}

export function useProfile() {
  const context = useContext(ProfileContext);
  if (!context) {
    throw new Error('useProfile must be used within a ProfileProvider');
  }
  return context;
}

export default ProfileContext;
