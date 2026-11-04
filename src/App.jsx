import { lazy, Suspense, useEffect } from 'react';
import { Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { useAuth } from './context/AuthContext';
import { useProfile } from './context/ProfileContext';
import AppLayout from './components/AppLayout/AppLayout';
import LoginPage from './pages/LoginPage/LoginPage';
import LegalPage from './pages/LegalPage/LegalPage';
import OnboardingPage from './pages/OnboardingPage/OnboardingPage';
import WardrobePage from './pages/WardrobePage/WardrobePage';

// Le pagine dopo il Guardaroba si scaricano al primo uso: all'apertura (su
// telefono, spesso in 4G) arriva solo quello che serve per la prima schermata.
// Dopo un nuovo deploy i vecchi file spariscono da GitHub Pages: chi aveva
// l'app aperta (o in background su iPhone) ricarica una volta la pagina
// invece di restare su una schermata bianca.
const RELOAD_FLAG = 'sv_chunk_reload';
function lazyPage(load) {
  return lazy(() =>
    load()
      .then((mod) => {
        sessionStorage.removeItem(RELOAD_FLAG);
        return mod;
      })
      .catch((err) => {
        if (sessionStorage.getItem(RELOAD_FLAG)) throw err;
        sessionStorage.setItem(RELOAD_FLAG, '1');
        window.location.reload();
        return new Promise(() => {});
      })
  );
}

const ItemDetailPage = lazyPage(() => import('./pages/ItemDetailPage/ItemDetailPage'));
const AddItemPage = lazyPage(() => import('./pages/AddItemPage/AddItemPage'));
const OutfitPage = lazyPage(() => import('./pages/OutfitPage/OutfitPage'));
const TryOnPage = lazyPage(() => import('./pages/TryOnPage/TryOnPage'));
const CalendarPage = lazyPage(() => import('./pages/CalendarPage/CalendarPage'));
const ProfilePage = lazyPage(() => import('./pages/ProfilePage/ProfilePage'));
const ArmocromiaPage = lazyPage(() => import('./pages/ArmocromiaPage/ArmocromiaPage'));
const FeedbackPage = lazyPage(() => import('./pages/FeedbackPage/FeedbackPage'));

/** Riporta lo scroll in cima a ogni cambio pagina. */
function ScrollToTop() {
  const { pathname } = useLocation();
  useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);
  return null;
}

/** Richiede login; il primo accesso passa dall'onboarding. */
function Protected({ children }) {
  const { isAuthenticated, isLoading } = useAuth();
  const { onboarded, profileLoading } = useProfile();
  if (isLoading || profileLoading) return null;
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  if (!onboarded) return <Navigate to="/onboarding" replace />;
  return children;
}

/** Richiede solo il login (per l'onboarding stesso). */
function AuthOnly({ children }) {
  const { isAuthenticated, isLoading } = useAuth();
  if (isLoading) return null;
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  return children;
}

export default function App() {
  return (
    <>
      <ScrollToTop />
      <Routes>
      <Route path="/login" element={<LoginPage />} />
      {/* Pubbliche, senza login: i link vanno in App Store Connect */}
      <Route path="/privacy" element={<LegalPage kind="privacy" />} />
      <Route path="/supporto" element={<LegalPage kind="support" />} />
      <Route path="/elimina-account" element={<LegalPage kind="deletion" />} />
      <Route
        path="/onboarding"
        element={
          <AuthOnly>
            <OnboardingPage />
          </AuthOnly>
        }
      />
      <Route
        element={
          <Protected>
            <AppLayout />
          </Protected>
        }
      >
        <Route path="/wardrobe" element={<WardrobePage />} />
        <Route path="/wardrobe/:itemId" element={<ItemDetailPage />} />
        <Route path="/add" element={<AddItemPage />} />
        <Route path="/outfit" element={<OutfitPage />} />
        <Route path="/tryon" element={<TryOnPage />} />
        <Route path="/calendar" element={<CalendarPage />} />
        <Route path="/profile" element={<ProfilePage />} />
        <Route path="/armocromia" element={<ArmocromiaPage />} />
        <Route path="/feedback" element={<FeedbackPage />} />
      </Route>
        <Route path="*" element={<Navigate to="/wardrobe" replace />} />
      </Routes>
    </>
  );
}
