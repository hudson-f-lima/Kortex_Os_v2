import { describe, it, expect } from 'vitest';
import { modulesForRole } from './nav.js';

describe('modulesForRole', () => {
  it('owner sees the full module set including organizacao', () => {
    const slugs = modulesForRole('owner').map((module) => module.slug);
    expect(slugs).toContain('organizacao');
    expect(slugs).toContain('agenda');
    expect(slugs).toContain('caixa');
  });

  it('manager sees everything except organizacao', () => {
    const slugs = modulesForRole('manager').map((module) => module.slug);
    expect(slugs).not.toContain('organizacao');
    expect(slugs).toContain('estoque');
  });

  it('professional sees only agenda and comanda', () => {
    const slugs = modulesForRole('professional').map((module) => module.slug);
    expect(slugs).toEqual(['agenda', 'comanda']);
  });

  it('an unknown role sees no modules', () => {
    expect(modulesForRole('bogus')).toEqual([]);
    expect(modulesForRole(null)).toEqual([]);
  });
});
