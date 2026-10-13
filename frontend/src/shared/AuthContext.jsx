import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { supabase } from './supabaseClient.js';
import { AuthContext } from './useAuth.js';
import { onSessionExpired } from './sessionExpired.js';

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null);
  const [loading, setLoading] = useState(true);
  const sessionRef = useRef(session);
  sessionRef.current = session;

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setLoading(false);
    });

    const { data: subscription } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
    });

    return () => subscription.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    // ADR 0015 (Blue Team #4): um 401 em qualquer chamada de API (ver
    // apiClient.js) dispara isso — força o logout local, o que cascateia
    // para a limpeza de IndexedDB já existente (OrganizationContext.jsx).
    // Ignora se já não houver sessão (evita signOut() redundante quando
    // várias chamadas em voo recebem 401 ao mesmo tempo).
    return onSessionExpired(() => {
      if (sessionRef.current) {
        supabase.auth.signOut();
      }
    });
  }, []);

  const signIn = useCallback(
    (email, password) => supabase.auth.signInWithPassword({ email, password }),
    [],
  );
  const signOut = useCallback(() => supabase.auth.signOut(), []);

  const user = session?.user ?? null;
  const accessToken = session?.access_token ?? null;

  const value = useMemo(
    () => ({ session, user, loading, accessToken, signIn, signOut }),
    [session, user, loading, accessToken, signIn, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
