[![Translator — перевод под курсором, из английского в русский](docs/assets/translator-banner.png)](https://github.com/gorodtx/selection_translator_anki/releases/download/v0.3.1-rc.2/Translator-0.3.1-macos-arm64.dmg)

<p align="center">
  <a href="https://github.com/gorodtx/selection_translator_anki/releases/download/v0.3.1-rc.2/Translator-0.3.1-macos-arm64.dmg"><strong>🍎 Скачать для Mac</strong></a> ·
  <a href="https://github.com/gorodtx/selection_translator_anki/tree/gnome#русский"><strong>🐧 GNOME / Arch Linux</strong></a> ·
  <a href="https://github.com/gorodtx/selection_translator_anki/issues">💬 Обратная связь</a>
</p>

<p align="center">Apple Silicon · macOS 26+ · DMG 27,40 МБ</p>

Выделите английский текст и вызовите Translator сочетанием клавиш или через macOS «Службы». Русский перевод появится под курсором; история и добавление в Anki — рядом.

[Установка на Mac](docs/macos.md#установка) · [Linux-релиз](https://github.com/gorodtx/selection_translator_anki/releases/tag/v0.2.8) · [Версия и контрольные суммы](https://github.com/gorodtx/selection_translator_anki/releases/tag/v0.3.1-rc.2)

<sub>Mac-сборка подписана ad-hoc, без Developer ID и заверения Apple: при первом открытии macOS может её заблокировать. Подробности — в инструкции установки. Python, uv и исходники пользователю не нужны.</sub>

## 🛠 Технологии

[SwiftUI](https://developer.apple.com/documentation/swiftui) · [AppKit](https://developer.apple.com/documentation/appkit) · [Apple Translation](https://developer.apple.com/documentation/translation) · [Python](https://www.python.org/) · [aiohttp](https://docs.aiohttp.org/) · [spaCy](https://spacy.io/) · [SQLite / FTS5](https://sqlite.org/fts5.html) · [AnkiConnect](https://github.com/amikey/anki-connect)

Нативное приложение macOS, встроенный Python backend, локальный поиск и карточки Anki. [Код и разработка](docs/development.md).

## 📚 Офлайн-базы

| База | Содержимое |
| --- | --- |
| [`primary.sqlite3`](https://github.com/gorodtx/selection_translator_anki/releases/download/db-a6f07d1e1c28/primary.sqlite3) | Основные англо-русские примеры и лексикон |
| [`fallback.sqlite3`](https://github.com/gorodtx/selection_translator_anki/releases/download/db-a6f07d1e1c28/fallback.sqlite3) | Дополнительные англо-русские примеры |
| [`definitions_pack.sqlite3`](https://github.com/gorodtx/selection_translator_anki/releases/download/db-a6f07d1e1c28/definitions_pack.sqlite3) | Английские определения |

Базы скачиваются из настроек приложения и хранятся локально; с каждым обновлением приложения повторная загрузка не нужна. [Готовый комплект и SHA256](https://github.com/gorodtx/selection_translator_anki/releases/tag/db-a6f07d1e1c28).

Источники данных: [OPUS](https://opus.nlpl.eu/) — параллельные корпуса, включая [Tatoeba](https://tatoeba.org/); [Kaikki / Wiktionary](https://kaikki.org/dictionary/English/index.html) — лексикон. Apple English/Russian language pair загружается отдельно через штатный интерфейс macOS.
