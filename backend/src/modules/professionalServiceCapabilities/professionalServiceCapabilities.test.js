import { describe, it, expect, beforeAll } from 'vitest';
import supertest from 'supertest';
import { createApp } from '../../app.js';
import { setupTest } from '../../../tests/helpers/localSupabase.js';

describe('Professional Service Capabilities', () => {
  let request;
  let app;
  let org;
  let auth;
  let professional;
  let service;
  let manager;

  beforeAll(async () => {
    const test = await setupTest();
    request = supertest(createApp(test.env, test.supabaseAdmin));
    auth = test.auth;
    org = test.org;

    // Create manager membership
    const managerRes = await auth.supabase.auth.signUpWithPassword({
      email: 'manager@test.com',
      password: 'testpass123',
    });
    manager = managerRes.data.user;

    // Add manager to org
    const { data: membershipData } = await test.supabaseAdmin
      .from('memberships')
      .insert({
        organization_id: org.id,
        user_id: manager.id,
        role: 'manager',
      })
      .select()
      .single();

    // Create professional
    const profRes = await test.supabaseAdmin
      .from('professionals')
      .insert({
        organization_id: org.id,
        name: 'Ana Silva',
      })
      .select()
      .single();
    professional = profRes.data;

    // Create service
    const serviceRes = await test.supabaseAdmin
      .from('services')
      .insert({
        organization_id: org.id,
        name: 'Haircut',
        price_cents: 5000,
        duration_minutes: 30,
      })
      .select()
      .single();
    service = serviceRes.data;
  });

  describe('GET /professional-service-capabilities', () => {
    it('should list all capabilities for an org', async () => {
      // Create a capability
      await test.supabaseAdmin
        .from('professional_service_capabilities')
        .insert({
          organization_id: org.id,
          professional_id: professional.id,
          service_id: service.id,
          duration_override_minutes: 45,
          buffer_before_min: 10,
        })
        .select()
        .single();

      const res = await request
        .get('/api/v1/professional-service-capabilities')
        .set('Authorization', `Bearer ${auth.session.access_token}`)
        .set('X-Organization-Id', org.id);

      expect(res.status).toBe(200);
      expect(res.body.capabilities).toBeInstanceOf(Array);
      expect(res.body.capabilities.length).toBeGreaterThan(0);
      expect(res.body.capabilities[0].duration_override_minutes).toBe(45);
    });

    it('should filter by professional_id', async () => {
      const res = await request
        .get(`/api/v1/professional-service-capabilities?professional_id=${professional.id}`)
        .set('Authorization', `Bearer ${auth.session.access_token}`)
        .set('X-Organization-Id', org.id);

      expect(res.status).toBe(200);
      expect(res.body.capabilities).toBeInstanceOf(Array);
      res.body.capabilities.forEach((cap) => {
        expect(cap.professional_id).toBe(professional.id);
      });
    });
  });

  describe('POST /professional-service-capabilities', () => {
    it('should create a capability', async () => {
      const res = await request
        .post('/api/v1/professional-service-capabilities')
        .set('Authorization', `Bearer ${auth.session.access_token}`)
        .set('X-Organization-Id', org.id)
        .send({
          professional_id: professional.id,
          service_id: service.id,
          duration_override_minutes: 50,
          buffer_before_min: 15,
          buffer_after_min: 10,
          price_override_cents: 6000,
        });

      expect(res.status).toBe(201);
      expect(res.body.capability).toBeDefined();
      expect(res.body.capability.duration_override_minutes).toBe(50);
      expect(res.body.capability.buffer_before_min).toBe(15);
      expect(res.body.capability.price_override_cents).toBe(6000);
    });

    it('should reject duplicate capability', async () => {
      // Create first capability
      await request
        .post('/api/v1/professional-service-capabilities')
        .set('Authorization', `Bearer ${auth.session.access_token}`)
        .set('X-Organization-Id', org.id)
        .send({
          professional_id: professional.id,
          service_id: service.id,
          duration_override_minutes: 40,
        });

      // Try to create duplicate
      const res = await request
        .post('/api/v1/professional-service-capabilities')
        .set('Authorization', `Bearer ${auth.session.access_token}`)
        .set('X-Organization-Id', org.id)
        .send({
          professional_id: professional.id,
          service_id: service.id,
          duration_override_minutes: 50,
        });

      expect(res.status).toBe(409);
      expect(res.body.code).toBe('capability_duplicate');
    });

    it('should reject invalid duration', async () => {
      const res = await request
        .post('/api/v1/professional-service-capabilities')
        .set('Authorization', `Bearer ${auth.session.access_token}`)
        .set('X-Organization-Id', org.id)
        .send({
          professional_id: professional.id,
          service_id: service.id,
          duration_override_minutes: 2, // Too short
        });

      expect(res.status).toBe(400);
      expect(res.body.code).toBe('invalid_payload');
    });

    it('should require role', async () => {
      // Create reception user (read-only)
      const recRes = await auth.supabase.auth.signUpWithPassword({
        email: 'reception@test.com',
        password: 'testpass123',
      });
      const reception = recRes.data.user;

      await test.supabaseAdmin
        .from('memberships')
        .insert({
          organization_id: org.id,
          user_id: reception.id,
          role: 'reception',
        });

      const sessionRes = await auth.supabase.auth.signInWithPassword({
        email: 'reception@test.com',
        password: 'testpass123',
      });

      const res = await request
        .post('/api/v1/professional-service-capabilities')
        .set('Authorization', `Bearer ${sessionRes.data.session.access_token}`)
        .set('X-Organization-Id', org.id)
        .send({
          professional_id: professional.id,
          service_id: service.id,
        });

      expect(res.status).toBe(403);
    });
  });

  describe('PATCH /professional-service-capabilities/:id', () => {
    it('should update a capability', async () => {
      const createRes = await request
        .post('/api/v1/professional-service-capabilities')
        .set('Authorization', `Bearer ${auth.session.access_token}`)
        .set('X-Organization-Id', org.id)
        .send({
          professional_id: professional.id,
          service_id: service.id,
          duration_override_minutes: 40,
        });

      const capabilityId = createRes.body.capability.id;

      const updateRes = await request
        .patch(`/api/v1/professional-service-capabilities/${capabilityId}`)
        .set('Authorization', `Bearer ${auth.session.access_token}`)
        .set('X-Organization-Id', org.id)
        .send({
          duration_override_minutes: 60,
          buffer_before_min: 20,
        });

      expect(updateRes.status).toBe(200);
      expect(updateRes.body.capability.duration_override_minutes).toBe(60);
      expect(updateRes.body.capability.buffer_before_min).toBe(20);
    });

    it('should return 404 for nonexistent capability', async () => {
      const res = await request
        .patch('/api/v1/professional-service-capabilities/00000000-0000-0000-0000-000000000000')
        .set('Authorization', `Bearer ${auth.session.access_token}`)
        .set('X-Organization-Id', org.id)
        .send({
          duration_override_minutes: 60,
        });

      expect(res.status).toBe(404);
    });
  });

  describe('DELETE /professional-service-capabilities/:id', () => {
    it('should delete a capability', async () => {
      const createRes = await request
        .post('/api/v1/professional-service-capabilities')
        .set('Authorization', `Bearer ${auth.session.access_token}`)
        .set('X-Organization-Id', org.id)
        .send({
          professional_id: professional.id,
          service_id: service.id,
          duration_override_minutes: 40,
        });

      const capabilityId = createRes.body.capability.id;

      const deleteRes = await request
        .delete(`/api/v1/professional-service-capabilities/${capabilityId}`)
        .set('Authorization', `Bearer ${auth.session.access_token}`)
        .set('X-Organization-Id', org.id);

      expect(deleteRes.status).toBe(204);

      // Verify it's deleted
      const getRes = await request
        .get(`/api/v1/professional-service-capabilities/${capabilityId}`)
        .set('Authorization', `Bearer ${auth.session.access_token}`)
        .set('X-Organization-Id', org.id);

      expect(getRes.status).toBe(404);
    });

    it('should require owner/admin role', async () => {
      const createRes = await request
        .post('/api/v1/professional-service-capabilities')
        .set('Authorization', `Bearer ${auth.session.access_token}`)
        .set('X-Organization-Id', org.id)
        .send({
          professional_id: professional.id,
          service_id: service.id,
        });

      const capabilityId = createRes.body.capability.id;

      // Manager cannot delete
      const managerSessionRes = await auth.supabase.auth.signInWithPassword({
        email: 'manager@test.com',
        password: 'testpass123',
      });

      const deleteRes = await request
        .delete(`/api/v1/professional-service-capabilities/${capabilityId}`)
        .set('Authorization', `Bearer ${managerSessionRes.data.session.access_token}`)
        .set('X-Organization-Id', org.id);

      expect(deleteRes.status).toBe(403);
    });
  });
});
