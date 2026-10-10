# Лендинг Translator

Минимальный русский сайт без сборщика/зависимостей, внешних fonts/analytics. Сейчас **LOGO_APPROVED_INTEGRATED; USER_VIDEO_INTEGRATED**: Translator Mono сохранён, пользовательская запись подключена к настоящему плееру. Generated demo/Canvas/fixture/DB endpoint в active site отсутствуют.

## Локальный preview

```bash
uv run --no-project python -m http.server 8765 --bind 127.0.0.1 --directory site
```

Открыть `http://127.0.0.1:8765/`. Это статическая presentation, не приложение и не публичный deployment. `file://` не подходит для ES modules. JavaScript проверяется `node --check site/app.js` и `node --check site/media.js`; HTML/assets/links и desktop/mobile/keyboard/media preferences проверяются отдельно в browser.

Поднимать preview только на время реальной разработки или проверки. После завершения остановить свой сервер через Ctrl+C либо по заранее подтверждённому собственному PID и проверить, что listener исчез. Фоновый preview «для просмотра» не оставлять.

## Реальное видео и логотип

Единая точка настройки — [media.js](media.js): `video` указывает на [пользовательский MP4](assets/translator-demo.mp4), `poster` — на [кадр этой записи](assets/translator-demo-poster.jpg), `captions=null` (готовых субтитров нет). `logo` указывает на [Small 64 px](assets/icon.png), рассчитанный для логического размера 32 px, `logoDark` — на [Dark Small SVG](assets/logo-dark-small.svg). `<picture>` выбирает тёмный вариант через `prefers-color-scheme`, без JavaScript theme listener. Пользователь принял artwork; после byte-match с утверждёнными exports/manifest `logoProvisional=false`. Файлы не перерисовывались. Источник и геометрия — [Mono icon system](../design/translator-icon/README.md).

Favicon [SVG](assets/favicon.svg) использует Tiny geometry; [ICO](assets/favicon.ico) содержит 16×16 и 32×32; [apple-touch PNG](assets/apple-touch-icon.png) — 180×180. Все пять файлов совпадают с `design/translator-icon/web/` по bytes/SHA256. Относительные URLs работают в root и поддиректории; internal SVG IDs изолированы `<img>`. Системная типографика, синяя/нейтральная палитра, layout и ссылки сохранены. Inter из GitHub card не подключается. Абсолютные canonical/OG image URLs не выдумываются до подтверждённого public hosting.

Видео использует native controls/playsinline/preload=metadata, без autoplay/loop/rate changes и без background timers. Неподдерживаемый/пропавший asset показывает error state. MP4 сохранён без перекодирования: 16 200 116 bytes, SHA256 `2f9df652afa0668c9a4cb3eb6d7860d2407a46657206171f9c94bd9858a8cbb2`, H.264, 1120×1080, 60 fps, 43,535 с, одна аудиодорожка. Poster — реальный кадр на 32,65 с; рамка повторяет пропорцию 28:27 без обрезки. Четыре контрольных кадра лично просмотрены; это запись пользователя, а не новый native acceptance этой сессии. Actual playback в Chromium/Safari отдельно не подтверждён. Ссылка под видео ведёт на Mac DMG. Нативные controls самостоятельны: видео не обёрнуто в ссылку, клик Play не скачивает installer. В README кадр ведёт к настоящему MP4; inline GitHub player не заявлен. Banner остаётся ссылкой скачивания.

## Статический hosting и границы

Публикуемая директория — `site/`, entry `index.html`; relative asset links поддерживают root/subpath hosting. Выбор host/DNS/deploy и Git delivery принадлежит Root. Из этого процесса ни deployment, ни публичный URL не создавались. На hosting нужны корректные MIME (`.js`, `.mp4`, `.webm`, `.vtt`), byte-range для video, HTTPS и cache policy после actual asset. Желательный CSP: default-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'. Проверить отдельно после публикации; static preview не доказывает headers/CDN/ranges.

Platform/download: Apple Silicon/macOS26+, v0.3.1-rc.2(332), DMG27,40МБ. CTA «Скачать для Mac», Linux — существующая ссылка GNOME/Arch. Поддержка двух платформ сверена с исходниками; Windows не заявлен. По прямому запросу 10.10.2026 длинный блок подписи/установки и дополнительные release/checksum links удалены из публичного описания. Реальные ограничения ad-hoc/noDeveloperID/noApple notarization остаются в [инструкции установки](https://github.com/gorodtx/selection_translator_anki/blob/mac/docs/macos.md); publicGatekeeper UNKNOWN. Это редактирование текста, не изменение подписи или релиза. DB corpus не входит в site; [paused research](../docs/presentation/RESEARCH.md) сохраняет actual readonly evidence и unknown rights.

Технологии представлены локальными SVG-бейджами с настоящими логотипами: SwiftUI, AppKit, Apple Translation, GTK4, Python, aiohttp, spaCy, SQLite/FTS5, AnkiConnect. [Происхождение, URLs и SHA256](assets/badges/provenance.json), [лицензии компонентов](assets/badges/README.md). Внешних загрузок badges при открытии сайта нет. Подпись страницы ссылается на MIT-лицензию проекта; лицензии корпусов и торговые марки этим не переопределяются.

История: 05.10.2026 Root опубликовал RC1; 08.10.2026 добавил preview→DMG, GNOME/Arch/feedback links при media=null. 10.10.2026 пользователь передал настоящий MP4 и попросил компактный текст, логотипы технологий и MIT footer. Ранее отменённые browser/CUA tests не возобновлялись; локальная source/HTTP проверка этой редакции фиксируется отдельно в журнале. Публичный сайт не развёрнут.

[Эпик](../docs/presentation/EPIC-03-PRESENTATION-LAYER.md) · [Журнал/evidence](../docs/presentation/PROGRESS-DELIVERY.md) · [Исследование](../docs/presentation/RESEARCH.md) · [Capture brief](../docs/presentation/VIDEO-BRIEF.md).
