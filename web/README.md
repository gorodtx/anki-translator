# Браузерное демо Translator

React + TypeScript strict, Vite, Tailwind 4, shadcn/Radix. Страница использует действующий translation pipeline через FastAPI; встроенных ответов и удалённого desktop stream нет. Круговой текст неподвижен. Desktop выделяет фрагменты стандартным browser selection, touch-тап выбирает всю фразу. Запрос отправляется только кнопкой; глобальные хоткеи отложены.

## Структура и установка

`src/components/ui/` — общий путь компонентов, `src/lib/utils.ts` — `cn()`, `src/index.css` — Tailwind/tokens/styles. Alias `@/` означает `src/`; это `/components/ui` внутри frontend-проекта, а не Python-корня репозитория. Размещение сохраняет импорты присланных компонентов и совместимость shadcn CLI.

```sh
cd web
npm ci
npx shadcn@latest info --json
npm run check
npm test -- --maxWorkers=1
npm run build
```

В новом Vite-проекте для настройки shadcn используется `npx shadcn@latest init`, для компонентов — `npx shadcn@latest add <name>`. Здесь config и компоненты уже подготовлены: повторный init не требуется. Версии зависимостей закреплены package-lock. Next.js не нужен: исходный `next/link` заменён обычными ссылками; Next-specific `style jsx` перенесён в CSS.

Локальный backend из корня:

```sh
uv sync --frozen --dev --group web
uv run --no-sync uvicorn web_backend.app:app --host 127.0.0.1 --port 8766 --no-access-log
```

Отдельно `npm run dev` из `web/`: Vite проксирует `/api` к этому loopback backend. Production image собирает `dist` и обслуживает frontend/API одним процессом. Preview/backend после проверки останавливать; постоянные localhost workers не оставлять.

## Дизайн и происхождение

Для каждого UI-изменения действуют [AGENTS.md](AGENTS.md), apple-design и preserve-project-design. Оба навыка присутствуют в общем каталоге `/Users/den/.agents/skills/`; автоматический hook этим не заявляется.

Пользователь передал код [Spinning Text](https://21st.dev/@ibelick/components/spinning-text), [Cloudscape](https://21st.dev/@amanshakya307/components/cloudscape), [MacOS Menu Bar](https://21st.dev/@dhmnpunit/components/mac-os-menu-bar), [FAQs Two](https://21st.dev/@meschacirung/components/faqs-component/faqs-two), [Liquid Weather Glass](https://21st.dev/@uilayout.contact/components/liquid-weather-glass). Применены необходимые изменения: SVG textPath без вращения и отдельных glyph spans; bounded WebGL и cleanup; укороченная доступная навигация; FAQ о Translator; уникальные SVG filter IDs; удалён `@ts-nocheck`. Погодное содержимое, фиктивные системные статусы и изображения из demo snippets не используются.

Montserrat получен из пользовательской папки, преобразован в self-hosted WOFF2; [OFL](public/assets/Montserrat-OFL.txt) сохранён. Mono-иконки скопированы из принятых site assets. Сетевых загрузок шрифтов/фото нет. Системная типографика и читабельный foreground popup сохраняются в обеих темах.

WebGL ограничен 900 000 pixels и DPR≤1.25, отрисовка облаков до 30 fps; reduced motion оставляет один неподвижный кадр. SVG текст не имеет animation loop. Скрытая вкладка/невидимый фон останавливают render; context loss показывает CSS fallback. Backend ограничен Compose memory limit 512 MiB; базы подключаются read-only и не скачиваются браузером.

## Границы демо

Онлайн-сервис Linux использует общий движок, Google/Cambridge и установленные primary/fallback/definitions базы. Apple Dictionary/Translation остаются функциями Mac-приложения. AnkiConnect посетителя не подключается. История ограничена 12 записями в памяти вкладки, не сохраняется на сервере/localStorage. Кнопка поддержки — явно неактивный placeholder до выбора настоящего платёжного URL.

API: `/api/health`, `/api/capabilities`, `POST /api/translate` с `{ "text": "bank" }`. Только en→ru, 200 characters, body≤4096 bytes, 3 concurrent requests, 60 requests/min для всего demo, engine timeout 8s/client 12s. Provider outage/no-match/error отображаются отдельно; поздний ответ отменённого запроса не заменяет новый.

Изолированная browser acceptance: `node scripts/browser-acceptance.mjs <URL> --live`; fixtures не подменяют production API. Статический локальный прогон без `--live` проверяет только UI/selection. Evidence и текущие результаты — `docs/demo/PROGRESS.md`. Native desktop/CUA не используются.
