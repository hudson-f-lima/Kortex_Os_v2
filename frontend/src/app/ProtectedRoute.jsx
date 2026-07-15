import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../shared/useAuth.js';

export function ProtectedRoute() {
  const { session, loading } = useAuth();

  if (loading) return <div className="full-page-loading">Carregando…</div>;
  if (!session) return <Navigate to="/login" replace />;

  return <Outlet />;
}
