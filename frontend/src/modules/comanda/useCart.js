import { useMemo, useState } from 'react';

function newLineKey() {
  return crypto.randomUUID();
}

// Estado e derivações do carrinho da comanda — extraído de ComandaPage.jsx.
// catalogItems vem de fora porque addPackage precisa resolver o nome de cada
// serviço do pacote. onLineAdded (opcional) dispara só quando uma linha NOVA
// de serviço/pacote entra no carrinho (não em incrementos de quantidade) —
// usado pela página para abrir o modal de atribuição de profissional.
export function useCart(apiClient, catalogItems, { onLineAdded } = {}) {
  const [cart, setCart] = useState([]);

  const subtotalCents = useMemo(
    () => cart.reduce((sum, line) => sum + (line.kind === 'package' ? line.unitPriceCents : line.unitPriceCents * line.quantity), 0),
    [cart],
  );

  // Espelha o invariante do backend (checkout_close, docs/adr/0006): gorjeta
  // só é aceita se houver ao menos um item que vira order_items.kind='service'
  // — serviço avulso ou pacote (que expande em linhas de serviço na RPC).
  const hasServiceLine = cart.some((line) => line.kind === 'service' || line.kind === 'package');

  const cartIsReady =
    cart.length > 0 &&
    cart.every((line) => {
      if (line.kind === 'service') return Boolean(line.professionalId);
      if (line.kind === 'package') return line.components.every((component) => Boolean(component.professionalId));
      return true;
    });

  function addServiceOrProduct(item) {
    const existing = cart.find((line) => line.kind === item.kind && line.catalogId === item.id);
    if (existing) {
      setCart((current) => current.map((line) => (line === existing ? { ...line, quantity: line.quantity + 1 } : line)));
      return;
    }
    const newLine = {
      key: newLineKey(),
      kind: item.kind,
      catalogId: item.id,
      name: item.name,
      unitPriceCents: item.price_cents,
      quantity: 1,
      professionalId: item.kind === 'service' ? '' : undefined,
      stockOnHand: item.kind === 'product' ? item.stock_on_hand : undefined,
    };
    setCart((current) => [...current, newLine]);
    onLineAdded?.(newLine);
  }

  async function addPackage(item) {
    const { package: pkg } = await apiClient.get(`/packages/${item.id}`);
    const components = pkg.items.map((packageItem) => {
      const service = catalogItems.find((catalogItem) => catalogItem.kind === 'service' && catalogItem.id === packageItem.service_id);
      return { serviceId: packageItem.service_id, serviceName: service?.name ?? 'Serviço', professionalId: '' };
    });
    const newLine = {
      key: newLineKey(),
      kind: 'package',
      catalogId: item.id,
      name: item.name,
      unitPriceCents: item.price_cents,
      components,
    };
    setCart((current) => [...current, newLine]);
    onLineAdded?.(newLine);
  }

  function updateLineQuantity(key, delta) {
    setCart((current) =>
      current
        .map((line) => (line.key === key ? { ...line, quantity: line.quantity + delta } : line))
        .filter((line) => line.kind === 'package' || line.quantity > 0),
    );
  }

  function removeLine(key) {
    setCart((current) => current.filter((line) => line.key !== key));
  }

  function setLineProfessional(key, professionalId) {
    setCart((current) => current.map((line) => (line.key === key ? { ...line, professionalId } : line)));
  }

  function setPackageComponentProfessional(key, serviceId, professionalId) {
    setCart((current) =>
      current.map((line) =>
        line.key === key
          ? {
              ...line,
              components: line.components.map((component) =>
                component.serviceId === serviceId ? { ...component, professionalId } : component,
              ),
            }
          : line,
      ),
    );
  }

  function resetCart() {
    setCart([]);
  }

  return {
    cart,
    setCart,
    subtotalCents,
    hasServiceLine,
    cartIsReady,
    addServiceOrProduct,
    addPackage,
    updateLineQuantity,
    removeLine,
    setLineProfessional,
    setPackageComponentProfessional,
    resetCart,
  };
}
