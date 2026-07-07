import { createContext, useContext, useState, useEffect, useCallback } from 'react';

const AuthContext = createContext(null);

const AUTH_STORAGE_KEY = 'sv_auth_user';

/**
 * Generate a simple unique ID for mock users.
 */
function generateUserId() {
  return `user_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
}

/**
 * AuthProvider - manages user authentication state with localStorage persistence.
 */
export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [isLoading, setIsLoading] = useState(true);

  // Restore session on mount
  useEffect(() => {
    try {
      const stored = localStorage.getItem(AUTH_STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored);
        setUser(parsed);
      }
    } catch (e) {
      console.warn('Failed to restore auth session:', e);
      localStorage.removeItem(AUTH_STORAGE_KEY);
    } finally {
      setIsLoading(false);
    }
  }, []);

  /**
   * Mock login - simulates async authentication.
   * @param {string} email
   * @param {string} password
   * @returns {Promise<{ success: boolean, error?: string }>}
   */
  const login = useCallback(async (email, password) => {
    setIsLoading(true);

    // Simulate network delay
    await new Promise((resolve) => setTimeout(resolve, 500));

    if (!email || !password) {
      setIsLoading(false);
      return { success: false, error: 'Email e password sono obbligatori' };
    }

    // Check if user exists in localStorage (from registration)
    const registeredUsers = JSON.parse(localStorage.getItem('sv_registered_users') || '[]');
    const existingUser = registeredUsers.find((u) => u.email === email);

    if (existingUser) {
      if (existingUser.password !== password) {
        setIsLoading(false);
        return { success: false, error: 'Password non corretta' };
      }
      const userData = {
        id: existingUser.id,
        name: existingUser.name,
        email: existingUser.email,
        avatar: existingUser.avatar || null,
      };
      setUser(userData);
      localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(userData));
      setIsLoading(false);
      return { success: true };
    }

    // Auto-create mock user for any email/password combo
    const mockUser = {
      id: generateUserId(),
      name: email.split('@')[0],
      email,
      avatar: null,
    };

    setUser(mockUser);
    localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(mockUser));
    setIsLoading(false);
    return { success: true };
  }, []);

  /**
   * Mock registration - creates a new user.
   * @param {string} name
   * @param {string} email
   * @param {string} password
   * @returns {Promise<{ success: boolean, error?: string }>}
   */
  const register = useCallback(async (name, email, password) => {
    setIsLoading(true);

    // Simulate network delay
    await new Promise((resolve) => setTimeout(resolve, 500));

    if (!name || !email || !password) {
      setIsLoading(false);
      return { success: false, error: 'Tutti i campi sono obbligatori' };
    }

    if (password.length < 6) {
      setIsLoading(false);
      return { success: false, error: 'La password deve avere almeno 6 caratteri' };
    }

    // Check for existing user
    const registeredUsers = JSON.parse(localStorage.getItem('sv_registered_users') || '[]');
    if (registeredUsers.some((u) => u.email === email)) {
      setIsLoading(false);
      return { success: false, error: 'Un account con questa email esiste già' };
    }

    const newUser = {
      id: generateUserId(),
      name,
      email,
      password, // In a real app this would be hashed
      avatar: null,
    };

    // Store in registered users list
    registeredUsers.push(newUser);
    localStorage.setItem('sv_registered_users', JSON.stringify(registeredUsers));

    // Set as current user (without password)
    const userData = {
      id: newUser.id,
      name: newUser.name,
      email: newUser.email,
      avatar: null,
    };

    setUser(userData);
    localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(userData));
    setIsLoading(false);
    return { success: true };
  }, []);

  /**
   * Logout - clear session data.
   */
  const logout = useCallback(() => {
    setUser(null);
    localStorage.removeItem(AUTH_STORAGE_KEY);
  }, []);

  /**
   * Update user profile data (name, email, avatar).
   * @param {object} data - Partial user data to update
   * @returns {{ success: boolean }}
   */
  const updateProfile = useCallback((data) => {
    setUser((prev) => {
      if (!prev) return prev;
      const updated = { ...prev, ...data };
      localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(updated));

      // Also update registered users list
      const registeredUsers = JSON.parse(localStorage.getItem('sv_registered_users') || '[]');
      const idx = registeredUsers.findIndex((u) => u.id === prev.id);
      if (idx !== -1) {
        registeredUsers[idx] = { ...registeredUsers[idx], ...data };
        localStorage.setItem('sv_registered_users', JSON.stringify(registeredUsers));
      }

      return updated;
    });
    return { success: true };
  }, []);

  const value = {
    user,
    isAuthenticated: !!user,
    isLoading,
    login,
    register,
    logout,
    updateProfile,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

/**
 * Hook to access auth context.
 */
export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}

export default AuthContext;
