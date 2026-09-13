import { useEffect, useState } from 'react';
import { BrowserRouter, Navigate, Routes, Route } from 'react-router-dom';
import { ThemeProvider } from './context/ThemeContext';
import { AuthProvider } from './context/AuthContext';
import ProtectedRoute from './components/auth/ProtectedRoute';
import ErrorBoundary from './components/ErrorBoundary';
import Header from './components/Header/Header';
import Formular from './components/Formular/Formular';
import './config/axios';

function AppShell() {
  const [mapFullscreen, setMapFullscreen] = useState(false);

  useEffect(() => {
    document.body.classList.toggle('fullscreen-mode', mapFullscreen);
    return () => document.body.classList.remove('fullscreen-mode');
  }, [mapFullscreen]);

  return (
    <div className={`app${mapFullscreen ? ' app--map-fullscreen' : ''}`}>
      {!mapFullscreen && <Header />}
      <main className={mapFullscreen ? 'main--map-fullscreen' : undefined}>
        <Formular onMapFullscreenChange={setMapFullscreen} />
      </main>
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <ThemeProvider>
      <AuthProvider>
        <ErrorBoundary>
          <Routes>
            <Route element={<ProtectedRoute />}>
              <Route path="/" element={<AppShell />} />
            </Route>
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </ErrorBoundary>
      </AuthProvider>
      </ThemeProvider>
    </BrowserRouter>
  );
}
