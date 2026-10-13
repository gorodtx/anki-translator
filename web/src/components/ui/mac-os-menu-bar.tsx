import { Download, Heart, HelpCircle, History } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { repository } from '@/lib/platform';

interface MacOSMenuBarProps { onHistory: () => void; download: string; }
export default function MacOSMenuBar({ onHistory, download }: MacOSMenuBarProps) {
  return <header className="menu-bar">
    <nav aria-label="Главное меню" className="menu-inner">
      <a className="brand" href="./" aria-label="Translator — начало страницы"><img src="./assets/icon.png" alt="" width="26" height="26" /><span>Translator</span></a>
      <div className="menu-links">
        <a href={repository} target="_blank" rel="noreferrer">GitHub <span aria-hidden="true">↗</span></a>
        <Button variant="ghost" size="sm" onClick={onHistory} aria-label="История переводов"><History aria-hidden="true" data-icon="inline-start" /><span className="menu-label">История</span></Button>
        <a href="#faq" aria-label="Частые вопросы"><HelpCircle aria-hidden="true" /><span className="menu-label">FAQ</span></a>
        <Button variant="ghost" size="sm" disabled title="Ссылка поддержки появится позже" aria-label="Поддержать — скоро"><Heart aria-hidden="true" data-icon="inline-start" /></Button>
        <a href={download} className="menu-download" aria-label="Скачать приложение"><Download aria-hidden="true" /></a>
      </div>
    </nav>
  </header>;
}
