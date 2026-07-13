import { randomUUID } from 'node:crypto';

// Well-known Supabase local-dev demo credentials (identical on every
// `supabase start`, documented publicly). Never used outside local tests.
const LOCAL_API_URL = 'http://127.0.0.1:54321';
const LOCAL_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
const LOCAL_SERVICE_ROLE_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

export function localTestEnv(overrides = {}) {
  return {
    nodeEnv: 'test',
    port: 0,
    logLevel: 'silent',
    supabaseUrl: process.env.SUPABASE_URL ?? LOCAL_API_URL,
    supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY ?? LOCAL_SERVICE_ROLE_KEY,
    supabaseJwksUrl: `${process.env.SUPABASE_URL ?? LOCAL_API_URL}/auth/v1/.well-known/jwks.json`,
    corsOrigins: ['http://localhost:5173'],
    ...overrides,
  };
}

export async function signUpTestUser(email, password) {
  const apiUrl = process.env.SUPABASE_URL ?? LOCAL_API_URL;
  const anonKey = process.env.SUPABASE_PUBLISHABLE_KEY ?? LOCAL_ANON_KEY;
  const response = await fetch(`${apiUrl}/auth/v1/signup`, {
    method: 'POST',
    headers: { apikey: anonKey, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const data = await response.json();
  if (!response.ok || !data.access_token) {
    throw new Error(`signUpTestUser failed: ${response.status} ${JSON.stringify(data)}`);
  }
  return { accessToken: data.access_token, userId: data.user.id };
}

// Creates a fresh organization with an owner, then optionally a second member
// with the requested role. Returns the credentials tests should act as
// (owner's own, when role === 'owner'), plus the owner's credentials
// separately so tests can perform further privileged setup either way.
export async function setUpOrgWithRole(supabaseAdmin, role) {
  const ownerEmail = `test-owner-${randomUUID()}@test.local`;
  const owner = await signUpTestUser(ownerEmail, 'S3nhaForte!123');
  const { data: org, error } = await supabaseAdmin.rpc('create_organization', {
    p_actor_user_id: owner.userId,
    p_name: 'Test Org',
    p_slug: `test-org-${randomUUID()}`,
  });
  if (error) throw new Error(`create_organization failed: ${error.message}`);

  const base = {
    organizationId: org.id,
    ownerUserId: owner.userId,
    ownerAccessToken: owner.accessToken,
  };

  if (role === 'owner') {
    return { ...base, accessToken: owner.accessToken, userId: owner.userId };
  }

  const memberEmail = `test-member-${randomUUID()}@test.local`;
  const member = await signUpTestUser(memberEmail, 'S3nhaForte!123');
  const { error: memberError } = await supabaseAdmin.rpc('membership_set', {
    p_organization_id: org.id,
    p_actor_user_id: owner.userId,
    p_target_user_id: member.userId,
    p_role: role,
  });
  if (memberError) throw new Error(`membership_set failed: ${memberError.message}`);

  return { ...base, accessToken: member.accessToken, userId: member.userId };
}
