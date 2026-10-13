import { useEffect, useRef, useState } from 'react';
import { ArrowDown, ArrowLeft, Check, Pencil, X } from 'lucide-react';
import Cloudscape from '@/components/ui/cloudscape';
import { SpinningText } from '@/components/ui/spinning-text';
import MacOSMenuBar from '@/components/ui/mac-os-menu-bar';
import FAQs from '@/components/ui/faqs-component';
import { Button } from '@/components/ui/button';
import { LiquidGlassCard } from '@/components/ui/liquid-weather-glass';
import { TranslationPopup } from '@/components/translation-popup';
import { translate, type Translation } from '@/lib/api';
import { detectPlatform, linuxDownload, macDownload, repository } from '@/lib/platform';

const initialText = 'It’s all Greek to me, but I’ll cross that bridge when I come to it.';
interface HistoryEntry { query: string; result: Translation; }

export default function App() {
  const [text, setText] = useState(initialText);
  const [selected, setSelected] = useState('');
  const [editing, setEditing] = useState(false);
  const [query, setQuery] = useState('');
  const [result, setResult] = useState<Translation | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [dark, setDark] = useState(matchMedia('(prefers-color-scheme: dark)').matches);
  const sceneRef = useRef<HTMLDivElement>(null);
  const abortRef = useRef<AbortController | null>(null);
  const generation = useRef(0);
  const translateRef = useRef<HTMLButtonElement>(null);
  const platform = detectPlatform(navigator.userAgent, navigator.platform, navigator.maxTouchPoints);
  const download = platform === 'linux' ? linuxDownload : macDownload;

  const closePopup = () => {
    generation.current++; abortRef.current?.abort(); setQuery(''); setLoading(false); setResult(null); setError('');
    translateRef.current?.focus({ preventScroll: true });
  };
  useEffect(() => {
    const onSelection = () => {
      const selection = window.getSelection();
      const node = sceneRef.current?.querySelector('.curved-text');
      if (node && selection?.anchorNode && selection.focusNode && node.contains(selection.anchorNode) && node.contains(selection.focusNode) && selection.toString().trim()) setSelected(selection.toString().trim());
    };
    const theme = matchMedia('(prefers-color-scheme: dark)');
    const onTheme = () => setDark(theme.matches);
    document.addEventListener('selectionchange', onSelection); theme.addEventListener('change', onTheme);
    return () => { document.removeEventListener('selectionchange', onSelection); theme.removeEventListener('change', onTheme); abortRef.current?.abort(); };
  }, []);
  useEffect(() => { setSelected(''); window.getSelection()?.removeAllRanges(); generation.current++; abortRef.current?.abort(); setQuery(''); setLoading(false); }, [text]);

  const lookup = async (value: string) => {
    if (!value.trim()) return;
    abortRef.current?.abort(); const controller = new AbortController(); abortRef.current = controller;
    const deadline = setTimeout(() => controller.abort('deadline'), 12_000);
    const id = ++generation.current; setQuery(value); setLoading(true); setResult(null); setError('');
    try {
      const translated = await translate(value, controller.signal);
      if (id !== generation.current) return;
      setResult(translated); setHistory(entries => [{ query: value, result: translated }, ...entries.filter(entry => entry.query !== value)].slice(0, 12));
    } catch (caught) {
      if (id === generation.current && controller.signal.reason === 'deadline') setError('Переводчик не ответил вовремя. Попробуйте ещё раз.');
      if (id === generation.current && !controller.signal.aborted) setError(caught instanceof Error ? caught.message : 'Перевод недоступен. Попробуйте ещё раз.');
    } finally { clearTimeout(deadline); if (id === generation.current) setLoading(false); }
  };

  return <>
    <a className="skip-link" href="#main">К демо</a>
    <Cloudscape colorBottom={dark ? '#203346' : '#87ceeb'} colorMid={dark ? '#3c4b5c' : '#f8f8f8'} colorTop={dark ? '#7f8994' : '#ffffff'}>
      <MacOSMenuBar download={download} onHistory={() => setHistoryOpen(value => !value)} />
      <main id="main" tabIndex={-1}>
        <div ref={sceneRef} className="demo-scene" data-long={Array.from(text).length > 85} onPointerDown={event => {
          if (query && event.target instanceof Element && !event.target.closest('.popup-slot')) {
            generation.current++; abortRef.current?.abort(); setQuery(''); setLoading(false); setResult(null); setError('');
          }
        }}>
          <SpinningText onTap={() => setSelected(text.trim())}>{text}</SpinningText>
          {!query && !historyOpen && <div className="hero-center"><img src="./assets/icon.png" width="64" height="64" alt="" /><h1>Translator</h1><p>Английский → русский.<br />Выделите текст. Нажмите «Перевести».</p></div>}
          {query && !historyOpen && <TranslationPopup key={query} query={query} result={result} loading={loading} error={error} onClose={closePopup} onRefresh={() => void lookup(query)} />}
          {historyOpen && <div className="popup-slot"><LiquidGlassCard className="history-popup" role="region" aria-labelledby="history-title"><div className="popup-header"><h2 id="history-title">История</h2><Button variant="ghost" size="icon" onClick={() => setHistoryOpen(false)} aria-label="Закрыть историю"><X aria-hidden="true" /></Button></div><div className="history-body">{history.length === 0 ? <p>Здесь появятся ваши переводы.</p> : history.map(entry => <button key={entry.query} className="history-entry" onClick={() => { generation.current++; abortRef.current?.abort(); setQuery(entry.query); setResult(entry.result); setLoading(false); setError(''); setHistoryOpen(false); }}><strong>{entry.query}</strong><span>{entry.result.translation}</span></button>)}</div></LiquidGlassCard></div>}
        </div>
        <div className="demo-controls">
          <Button ref={translateRef} disabled={!selected || loading} onPointerDown={event => { if (event.pointerType === 'mouse') event.preventDefault(); }} onClick={() => { setHistoryOpen(false); void lookup(selected); }}>Перевести <ArrowLeft aria-hidden="true" data-icon="inline-end" /></Button>
          <Button variant="outline" onClick={() => setEditing(value => !value)} aria-expanded={editing} aria-controls="text-editor">{editing ? <Check aria-hidden="true" data-icon="inline-start" /> : <Pencil aria-hidden="true" data-icon="inline-start" />}{editing ? 'Готово' : 'Свой текст'}</Button>
        </div>
        <p className="selection-hint" aria-live="polite">{selected ? `Выбрано: ${selected}` : 'На компьютере — зажмите и потяните. На телефоне — тап по фразе.'}</p>
        {editing && <div id="text-editor" className="text-editor"><label htmlFor="english-text">Ваша фраза на английском</label><textarea id="english-text" value={text} maxLength={200} rows={3} onChange={event => setText(event.target.value)} autoFocus spellCheck={false} /><span>{Array.from(text).length} / 200</span></div>}
        <section className="download-section" aria-label="Скачать приложение"><Button asChild variant="outline"><a href={download}><ArrowDown aria-hidden="true" data-icon="inline-start" />{platform === 'linux' ? 'GNOME / Arch Linux' : platform === 'mac' ? 'Скачать для Mac' : 'Версия для Mac'}</a></Button><p>{platform === 'linux' ? 'GNOME · Arch Linux' : 'Apple Silicon · macOS 26+'}</p><div className="other-platforms"><a href={macDownload}>macOS</a><span aria-hidden="true">·</span><a href={linuxDownload}>GNOME / Arch Linux</a></div></section>
        <FAQs />
      </main>
      <footer><a href={`${repository}/issues`}>Обратная связь ↗</a><a href={`${repository}/blob/mac/LICENSE`}>MIT</a><span>Translator · 2026</span></footer>
    </Cloudscape>
  </>;
}
