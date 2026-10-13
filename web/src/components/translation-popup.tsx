import { Copy, RefreshCw, X } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { motion, useReducedMotion } from 'framer-motion';
import { Button } from '@/components/ui/button';
import { LiquidGlassCard } from '@/components/ui/liquid-weather-glass';
import type { Translation } from '@/lib/api';

interface Props { query: string; result: Translation | null; loading: boolean; error: string; onClose: () => void; onRefresh: () => void; }
export function TranslationPopup({ query, result, loading, error, onClose, onRefresh }: Props) {
  const reduce = useReducedMotion();
  const closeRef = useRef<HTMLButtonElement>(null);
  const [copied, setCopied] = useState(false);
  const [copyError, setCopyError] = useState('');
  useEffect(() => { closeRef.current?.focus({ preventScroll: true }); }, []);
  useEffect(() => { setCopied(false); setCopyError(''); }, [result]);
  return <motion.div className="popup-slot" initial={reduce ? false : { opacity: 0, scale: 0.97 }} animate={{ opacity: 1, scale: 1 }} transition={{ duration: 0.15, ease: [0.23, 1, 0.32, 1] }}>
    <LiquidGlassCard className="translation-popup" role="region" aria-labelledby="popup-title" aria-busy={loading}>
      <div className="popup-header"><h2 id="popup-title">{query}</h2><Button ref={closeRef} size="icon" variant="ghost" onClick={onClose} aria-label="Закрыть перевод"><X aria-hidden="true" /></Button></div>
      <div className="popup-body" tabIndex={0} aria-label="Содержимое перевода">
        {loading && <p role="status" className="popup-status">Переводим…</p>}
        {error && <p role="alert" className="popup-error">{error}</p>}
        {!loading && result && <>
          <p className="translation">{result.translation || 'Перевод не найден.'}</p>
          {result.lexical && <div className="dictionary"><p className="ipa">{[result.lexical.ipa_uk, result.lexical.ipa_us].filter(Boolean).join(' · ')}</p>
            {result.lexical.entries.map((entry, i) => <div key={i}><p className="part-of-speech">{entry.pos}</p>{entry.senses.map(sense => <p key={sense.index}>{sense.index}. {sense.translation} {sense.label && <span className="secondary">({sense.label})</span>}</p>)}</div>)}
          </div>}
          {result.definitions.length > 0 && <section><h3>Definitions</h3>{result.definitions.map((definition, i) => <p key={i}>{definition}</p>)}</section>}
          {result.examples.length > 0 && <section><h3>Examples</h3>{result.examples.map((example, i) => <p key={i}>{example}</p>)}</section>}
        </>}
      </div>
      <div className="popup-footer">
        <Button size="sm" variant="ghost" disabled={!result?.translation || loading} onClick={() => {
          void navigator.clipboard.writeText(result?.translation ?? '').then(() => setCopied(true)).catch(() => setCopyError('Не удалось скопировать. Выделите перевод вручную.'));
        }}><Copy data-icon="inline-start" aria-hidden="true" />{copied ? 'Скопировано' : 'Копировать'}</Button>
        <Button size="sm" variant="ghost" onClick={onRefresh} disabled={loading} aria-label="Повторить перевод и обновить примеры"><RefreshCw aria-hidden="true" /></Button>
      </div>
      {copyError && <p role="status" className="copy-error">{copyError}</p>}
    </LiquidGlassCard>
  </motion.div>;
}
