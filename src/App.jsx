import { useEffect } from 'react';
import { Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { useAuth } from './context/AuthContext';
import { useProfile } from './context/ProfileContext';
import AppLayout from './components/AppLayout/AppLayout';
import LoginPage from './pages/LoginPage/LoginPage';
import OnboardingPage from './pages/OnboardingPage/OnboardingPage';
import WardrobePage from './pages/WardrobePage/WardrobePage';
import ItemDetailPage from './pages/ItemDetailPage/ItemDetailPage';
import AddItemPage from './pages/AddItemPage/AddItemPage';
import OutfitPage from './pages/OutfitPage/OutfitPage';
import TryOnPage from './pages/TryOnPage/TryOnPage';
import CalendarPage from './pages/CalendarPage/CalendarPage';
import ProfilePage from './pages/ProfilePage/ProfilePage';

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
      </Route>
        <Route path="*" element={<Navigate to="/wardrobe" replace />} />
      </Routes>
    </>
  );
}
