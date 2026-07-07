import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { useAuth } from './AuthContext';
import { DEFAULT_AVATAR_CONFIG } from '../utils/avatarOptions';

const ProfileContext = createContext(null);

// In Fase A il profilo vive in localStorage, per-utente; in Fase B passerà a Supabase.
const profileKey = (userId) => `sv_profile_${userId || 'anon'}`;

const DEFAULT_PROFILE = {
  avatarConfig: DEFAULT_AVATAR_CONFIG,
  referencePhoto: null, // dataURL della foto di riferimento dell'utente
  onboarded: false,
};

function loadProfile(userId) {
  try {
    const stored = localStorage.getItem(profileKey(userId));
    if (stored) return { ...DEFAULT_PROFILE, ...JSON.parse(stored) };
  } catch (e) {
    console.warn('Failed to load profile:', e);
  }
  return DEFAULT_PROFILE;
}

/**
 * ProfileProvider - avatar configuration, reference photo, onboarding state.
 */
export function ProfileProvider({ children }) {
  const { user } = useAuth();
  const userId = user?.id;
  const [profile, setProfile] = useState(() => loadProfile(userId));

  // Ricarica il profilo quando cambia l'utente loggato
  useEffect(() => {
    setProfile(loadProfile(userId));
  }, [userId]);

  useEffect(() => {
    try {
      localStorage.setItem(profileKey(userId), JSON.stringify(profile));
    } catch (e) {
      // Tipico: quota localStorage superata per la foto di riferimento
      console.warn('Failed to save profile:', e);
    }
  }, [profile, userId]);

  const setAvatarConfig = useCallback((updates) => {
    setProfile((prev) => ({
      ...prev,
      avatarConfig: { ...prev.avatarConfig, ...updates },
    }));
  }, []);

  const setReferencePhoto = useCallback((dataUrl) => {
    setProfile((prev) => ({ ...prev, referencePhoto: dataUrl }));
  }, []);

  const completeOnboarding = useCallback(() => {
    setProfile((prev) => ({ ...prev, onboarded: true }));
  }, []);

  const value = {
    avatarConfig: profile.avatarConfig,
    referencePhoto: profile.referencePhoto,
    onboarded: profile.onboarded,
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
