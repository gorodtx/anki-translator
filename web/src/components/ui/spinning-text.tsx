import { useId, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { cn } from '@/lib/utils';

export interface SpinningTextProps {
  children: string;
  className?: string;
  onTap?: () => void;
}

// The supplied circular-text reference is deliberately static here. A single
// SVG text node preserves browser selection/copy and font kerning; glyph spans
// and an infinite rotation would break the agreed interaction.
export function curvedLayout(textWidth: number, radius: number, fontSize: number) {
  const sweep = Math.max(Math.PI, textWidth / radius + 0.06);
  const points: string[] = [];
  const steps = Math.ceil(sweep * 45);
  for (let step = 0; step <= steps; step++) {
    const angle = Math.PI + (sweep * step) / steps;
    const growth = Math.max(0, angle - Math.PI * 3) * fontSize * 1.8 / (Math.PI * 2);
    const r = radius + growth;
    points.push(`${step === 0 ? 'M' : 'L'} ${r * Math.cos(angle)} ${r * Math.sin(angle)}`);
  }
  return { path: points.join(' '), offset: Math.max(0, (Math.PI * radius - textWidth) / 2), outerRadius: radius + Math.max(0, sweep - Math.PI * 2) * fontSize * 1.8 / (Math.PI * 2) };
}

export function SpinningText({ children, className, onTap }: SpinningTextProps) {
  const host = useRef<SVGSVGElement>(null);
  const text = useRef<SVGTextElement>(null);
  const pathId = `arc-${useId().replace(/\W/g, '')}`;
  const [width, setWidth] = useState(920);
  const [fontReady, setFontReady] = useState(false);
  const mobile = width < 600;
  const count = Array.from(children).length;
  const preferredFontSize = mobile ? Math.max(13, 21 - count * 0.036) : Math.max(22, 38 - count * 0.075);
  const radius = width * (mobile ? 0.425 : 0.34);
  const layout = useMemo(() => {
    const context = document.createElement('canvas').getContext('2d');
    let fontSize = preferredFontSize;
    const compute = () => {
      if (context) context.font = `650 ${fontSize}px Montserrat`;
      return curvedLayout(context?.measureText(children).width ?? count * fontSize * 0.55, radius, fontSize);
    };
    let geometry = compute();
    while (geometry.outerRadius + fontSize > width / 2 - 8 && fontSize > 8) { fontSize -= 0.5; geometry = compute(); }
    return { ...geometry, fontSize };
  }, [children, count, preferredFontSize, radius, width, fontReady]);

  useLayoutEffect(() => {
    const element = host.current;
    if (!element) return;
    const observer = new ResizeObserver(([entry]) => { if (entry) setWidth(entry.contentRect.width); });
    observer.observe(element);
    let live = true;
    void document.fonts.ready.then(() => { if (live) setFontReady(true); });
    return () => { live = false; observer.disconnect(); };
  }, []);

  return (
    <svg ref={host} className={cn('curved-text', className)} viewBox={`0 0 ${width} ${width}`}>
      <defs><path id={pathId} d={layout.path} /></defs>
      <text ref={text} transform={`translate(${width / 2} ${width / 2})`} fontSize={layout.fontSize}
        onPointerUp={(event) => {
          if (event.pointerType === 'touch' && text.current) {
            event.preventDefault();
            // Apply after the browser's compatibility click, which otherwise
            // collapses touch selection back to a caret on SVG text.
            requestAnimationFrame(() => {
              if (!text.current) return;
              const range = document.createRange();
              range.selectNodeContents(text.current);
              const selection = window.getSelection();
              selection?.removeAllRanges(); selection?.addRange(range);
              onTap?.();
            });
          }
        }}>
        <textPath href={`#${pathId}`} startOffset={layout.offset}>{children}</textPath>
      </text>
    </svg>
  );
}
