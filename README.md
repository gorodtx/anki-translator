[![Translator — перевод под курсором, из английского в русский](docs/assets/translator-banner.png)](https://github.com/gorodtx/selection_translator_anki/releases/download/v0.3.1-rc.2/Translator-0.3.1-macos-arm64.dmg)

<p align="center">
  <a href="https://github.com/gorodtx/selection_translator_anki/releases/download/v0.3.1-rc.2/Translator-0.3.1-macos-arm64.dmg"><strong>🍎 Скачать для Mac</strong></a> ·
  <a href="https://github.com/gorodtx/selection_translator_anki/tree/gnome#русский"><strong>🐧 GNOME / Arch Linux</strong></a> ·
  <a href="https://github.com/gorodtx/selection_translator_anki/issues">💬 Обратная связь</a>
</p>

<p align="center">Apple Silicon · macOS 26+ · DMG 27,40 МБ</p>

Выделите английский текст и вызовите Translator сочетанием клавиш. Русский перевод появится под курсором; история и добавление в Anki — рядом.

## ▶ Демонстрация

[![Посмотреть видео: перевод выделенного текста в Translator](site/assets/translator-demo-poster.jpg)](site/assets/translator-demo.mp4)

[Смотреть демо · 44 секунды](site/assets/translator-demo.mp4)

## 🛠 Технологии

[![SwiftUI](site/assets/badges/swiftui.svg)](https://developer.apple.com/documentation/swiftui)
[![AppKit](site/assets/badges/appkit.svg)](https://developer.apple.com/documentation/appkit)
[![Apple Translation](site/assets/badges/translation.svg)](https://developer.apple.com/documentation/translation)
[![GTK4](site/assets/badges/gtk.svg)](https://www.gtk.org/)
[![Python](site/assets/badges/python.svg)](https://www.python.org/)
[![aiohttp](site/assets/badges/aiohttp.svg)](https://docs.aiohttp.org/)
[![spaCy](site/assets/badges/spacy.svg)](https://spacy.io/)
[![SQLite / FTS5](site/assets/badges/sqlite.svg)](https://sqlite.org/fts5.html)
[![AnkiConnect](site/assets/badges/anki.svg)](https://github.com/amikey/anki-connect)

macOS и Linux · Python backend · SQLite · Anki. [Код и разработка](docs/development.md).

## 📚 Офлайн-базы

| База | Содержимое |
| --- | --- |
| [`primary.sqlite3`](https://github.com/gorodtx/selection_translator_anki/releases/download/db-a6f07d1e1c28/primary.sqlite3) | Основные англо-русские примеры и лексикон |
| [`fallback.sqlite3`](https://github.com/gorodtx/selection_translator_anki/releases/download/db-a6f07d1e1c28/fallback.sqlite3) | Дополнительные англо-русские примеры |
| [`definitions_pack.sqlite3`](https://github.com/gorodtx/selection_translator_anki/releases/download/db-a6f07d1e1c28/definitions_pack.sqlite3) | Английские определения |

Базы скачиваются из настроек приложения и хранятся локально; с каждым обновлением приложения повторная загрузка не нужна. [Готовый комплект и SHA256](https://github.com/gorodtx/selection_translator_anki/releases/tag/db-a6f07d1e1c28).

---

© 2026 Translator contributors · [Лицензия MIT](LICENSE)
