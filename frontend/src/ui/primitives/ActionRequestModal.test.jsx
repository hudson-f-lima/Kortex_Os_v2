import { render, screen, fireEvent } from '@testing-library/react';
import { describe, test, expect, vi } from 'vitest';
import { ActionRequestModal } from './ActionRequestModal.jsx';

describe('ActionRequestModal Component', () => {
  const mockRequest = {
    title: 'Perdoar Taxa de No-Show',
    description: 'Cliente justificou ausência devido a emergência médica.',
    category: 'No-Show',
    impactCents: 5000,
    requestedBy: 'Kortex.ai Assistant',
  };

  test('renders modal content when open', () => {
    render(
      <ActionRequestModal
        isOpen={true}
        onClose={vi.fn()}
        onApprove={vi.fn()}
        onReject={vi.fn()}
        request={mockRequest}
      />
    );

    expect(screen.getByText('Perdoar Taxa de No-Show')).toBeInTheDocument();
    expect(screen.getByText('R$ 50,00')).toBeInTheDocument();
  });

  test('calls onApprove when approve button is clicked', () => {
    const handleApprove = vi.fn();
    render(
      <ActionRequestModal
        isOpen={true}
        onClose={vi.fn()}
        onApprove={handleApprove}
        onReject={vi.fn()}
        request={mockRequest}
      />
    );

    fireEvent.click(screen.getByText('Aprovar Ação'));
    expect(handleApprove).toHaveBeenCalledTimes(1);
  });
});
