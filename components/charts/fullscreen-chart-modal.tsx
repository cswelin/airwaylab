'use client';

import { useEffect, useCallback } from 'react';
import { createPortal } from 'react-dom';
import { X } from 'lucide-react';
import { useFocusTrap } from '@/hooks/use-focus-trap';

interface FullscreenChartModalProps {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
}

export function FullscreenChartModal({ title, onClose, children }: FullscreenChartModalProps) {
  const focusTrapRef = useFocusTrap(true);

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [onClose]);

  const handleOverlayClick = useCallback(
    (e: React.MouseEvent) => {
      if (e.target === focusTrapRef.current) onClose();
    },
    [onClose, focusTrapRef]
  );

  return createPortal(
    <div
      ref={focusTrapRef}
      className="fixed inset-0 z-50 flex items-stretch justify-center bg-black/70 p-3 backdrop-blur-sm animate-fade-in-up sm:p-6"
      onClick={handleOverlayClick}
      role="dialog"
      aria-modal="true"
      aria-label={`${title} — expanded view`}
    >
      <div className="flex w-full flex-col overflow-hidden rounded-2xl border border-border bg-card shadow-2xl">
        <div className="flex shrink-0 items-center justify-between border-b border-border/50 px-5 py-3">
          <h2 className="text-sm font-semibold text-foreground">{title}</h2>
          <button
            onClick={onClose}
            className="rounded-lg p-1.5 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
            aria-label="Close expanded view"
          >
            <X className="h-4 w-4" />
          </button>
        </div>
        <div className="flex-1 overflow-auto p-4">{children}</div>
      </div>
    </div>,
    document.body
  );
}
