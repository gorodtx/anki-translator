# Лендинг Translator

Минимальный русский сайт без сборщика/зависимостей, внешних fonts/analytics. Сейчас **LOGO_APPROVED_INTEGRATED; WAITING_USER_VIDEO**: пользователь принял Translator Mono; настоящий screencast ещё ожидается. Пустой video slot честно сообщает об отсутствии записи; generated demo/Canvas/fixture/DB endpoint в active site отсутствуют.

## Локальный preview

```bash
uv run --no-project python -m http.server 8765 --bind 127.0.0.1 --directory site
```

Открыть `http://127.0.0.1:8765/`. Это статическая presentation, не приложение и не публичный deployment. `file://` не подходит для ES modules. JavaScript проверяется `node --check site/app.js` и `node --check site/media.js`; HTML/assets/links и desktop/mobile/keyboard/media preferences проверяются отдельно в browser.

Поднимать preview только на время реальной разработки или проверки. После завершения остановить свой сервер через Ctrl+C либо по заранее подтверждённому собственному PID и проверить, что listener исчез. Фоновый preview «для просмотра» не оставлять.

## Реальное видео и логотип

Единая точка настройки — [media.js](media.js): `video`, `poster`, `captions` пока null; `logo` указывает на [Small 64 px](assets/icon.png), рассчитанный для логического размера 32 px, `logoDark` — на [Dark Small SVG](assets/logo-dark-small.svg). `<picture>` выбирает тёмный вариант через `prefers-color-scheme`, без JavaScript theme listener. Пользователь принял artwork; после byte-match с утверждёнными exports/manifest `logoProvisional=false`. Файлы не перерисовывались. Источник и геометрия — [Mono icon system](../design/translator-icon/README.md).

Favicon [SVG](assets/favicon.svg) использует Tiny geometry; [ICO](assets/favicon.ico) содержит 16×16 и 32×32; [apple-touch PNG](assets/apple-touch-icon.png) — 180×180. Все пять файлов совпадают с `design/translator-icon/web/` по bytes/SHA256. Относительные URLs работают в root и поддиректории; internal SVG IDs изолированы `<img>`. Системная типографика, синяя/нейтральная палитра, layout и ссылки сохранены. Inter из GitHub card не подключается. Абсолютные canonical/OG image URLs не выдумываются до подтверждённого public hosting.

Видео использует native controls/playsinline/preload=metadata, без autoplay/loop/rate changes и без background timers. Неподдерживаемый/пропавший asset показывает error state. Poster только из реальной записи; пока poster отсутствует. Actual playback в Chromium/Safari ещё не подтверждён без footage. Для README после получения реального poster добавить один preview/link к записанному видео; не рисовать подмену кадра.

## Статический hosting и границы

Публикуемая директория — `site/`, entry `index.html`; relative asset links поддерживают root/subpath hosting. Выбор host/DNS/deploy и Git delivery принадлежит Root. Из этого процесса ни deployment, ни публичный URL не создавались. На hosting нужны корректные MIME (`.js`, `.mp4`, `.webm`, `.vtt`), byte-range для video, HTTPS и cache policy после actual asset. Желательный CSP: default-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'. Проверить отдельно после публикации; static preview не доказывает headers/CDN/ranges.

Platform/download: Apple Silicon/macOS26+, v0.3.0(295),25 229 806bytes. Рядом с CTA сохранена правда: ad-hoc/noDeveloperID/noApple notarization/publicGatekeeper UNKNOWN; [условия](https://github.com/gorodtx/selection_translator_anki/blob/mac/docs/macos.md). DB corpus не входит в site; [paused research](../docs/presentation/RESEARCH.md) сохраняет actual readonly positive/negative evidence и unknown rights.

[Эпик](../docs/presentation/EPIC-03-PRESENTATION-LAYER.md) · [Журнал/evidence](../docs/presentation/PROGRESS-DELIVERY.md) · [Исследование](../docs/presentation/RESEARCH.md) · [Capture brief](../docs/presentation/VIDEO-BRIEF.md).
