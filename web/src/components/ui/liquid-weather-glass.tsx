import { useId, type HTMLAttributes, type ReactNode } from 'react';
import { cn } from '@/lib/utils';

interface LiquidGlassCardProps extends HTMLAttributes<HTMLDivElement> {
  children: ReactNode;
  borderRadius?: string;
}

// The supplied Bend / Face / Edge / Content layering is retained. Cards are
// fixed rather than draggable, matching the centre of the demonstration.
export function LiquidGlassCard({ children, className, borderRadius = '24px', style, ...props }: LiquidGlassCardProps) {
  const filterId = `glass-${useId().replace(/\W/g, '')}`;
  return (
    <div className={cn('liquid-glass', className)} style={{ borderRadius, ...style }} {...props}>
      <svg width="0" height="0" aria-hidden="true" className="glass-definitions"><defs>
        <filter id={filterId} x="0" y="0" width="100%" height="100%" filterUnits="objectBoundingBox">
          <feTurbulence type="fractalNoise" baseFrequency="0.003 0.007" numOctaves="1" result="turbulence" />
          <feDisplacementMap in="SourceGraphic" in2="turbulence" scale="18" xChannelSelector="R" yChannelSelector="G" />
        </filter>
      </defs></svg>
      <div aria-hidden="true" className="glass-bend" style={{ filter: `url("#${filterId}")` }} />
      <div aria-hidden="true" className="glass-face" />
      <div aria-hidden="true" className="glass-edge" />
      <div className="glass-content">{children}</div>
    </div>
  );
}
