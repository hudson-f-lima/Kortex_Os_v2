BEGIN;
SELECT plan(3);

-- Behavior 1 (issue 055): todo pedido tem uma revisão corrente explícita.
-- O contrato começa pela coluna; o default e o backfill serão cobertos no
-- próximo ciclo, depois que esta presença física estiver GREEN.
SELECT has_column(
  'public',
  'orders',
  'current_revision',
  'orders exposes current_revision for versioned checkout'
);

-- Behavior 3 (issue 055): cada fechamento terá um registro histórico próprio.
SELECT has_table(
  'public',
  'order_revisions',
  'order_revisions stores immutable order-close snapshots'
);

-- Behavior 2 (issue 055): pagamentos também pertencem a uma revisão do pedido.
SELECT has_column(
  'public',
  'payments',
  'revision_number',
  'payments exposes revision_number for versioned checkout'
);

SELECT * FROM finish();
ROLLBACK;
