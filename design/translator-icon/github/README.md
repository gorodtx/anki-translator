# Translator · Ресурсы для GitHub

Квадратная иконка и repository social card подготовлены в том же Penpot-файле `Translator · Mono icon system`. Сохранены существующие две панели, белый клубок, три строки, ivory/graphite и спокойная типографика без засечек. На карточке использован дополнительный знак «клубок → ровная линия».

Основная подпись соответствует продукту: **«Перевод рядом. Из хаоса — в ясность.»** Уточнение — английский → русский, macOS. Нет неподтверждённого обещания поддержки любых языков.

| Готовый файл | Размер | Назначение |
|---|---|---|
| [repo-card-ru.png](repo-card-ru.png) | 1280×640 | Основной Social preview на русском |
| [repo-card-en.png](repo-card-en.png) | 1280×640 | Английская версия |
| [avatar-500.png](avatar-500.png) | 500×500 | Квадратный логотип для профиля/README |
| [avatar-1024.png](avatar-1024.png) | 1024×1024 | Большой PNG |
| [avatar-dark-500.png](avatar-dark-500.png) | 500×500 | Тёмный вариант |
| [avatar.svg](avatar.svg), [avatar-dark.svg](avatar-dark.svg) | Вектор | Масштабируемые аватары |
| [profile/README-snippet.md](profile/README-snippet.md) и `profile/assets/` | Готовый фрагмент | Карточка с логотипом в README профиля |

Карта использует пользовательский шаблон 1280×640. Важные элементы лежат внутри отступа 80 px — это 40 pt на 2x шаблоне. Красные линии и розовый фон исходного template — guides; в готовой карточке они не рисуются. Оба файла social card имеют непрозрачный фон; все upload PNG меньше 1 MB. Точные размеры, bytes и SHA256 — в [asset-manifest.json](asset-manifest.json).

В Penpot добавлены `GITHUB · Repo card · RU`, `GITHUB · Repo card · EN`, `AVATAR · Light · 1024`, `AVATAR · Dark · 1024`. Текст, line mark и геометрия прежнего master редактируются. При масштабировании master отдельно масштабированы strokes, shadows и corner radii; исходные макеты сохранены. Font runs зафиксированы как Inter, чтобы экспорт не откатывался к serif fallback. Проверка margins и круглого кадрирования сохранена в `penpot/acceptance.json` и `preview/`.

Для установки Social preview откройте репозиторий на GitHub: **Settings → General → Social preview → Edit → Upload an image…** и выберите `repo-card-ru.png` или `repo-card-en.png`. GitHub рекомендует 1280×640 и файл меньше 1 MB: [официальная документация](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview).

У стандартных pinned repository cards нет отдельного поля для загрузки аватара репозитория. Social preview показывается при распространении ссылки, а не вместо значка в Pinned. Чтобы логотип появился в профиле, скопируйте `profile/assets/` в репозиторий профиля и вставьте [готовый фрагмент](profile/README-snippet.md) в его README. Это дополнительная карточка в README. Данные и настройки действующего профиля не менялись. Возможности описаны в [Pinning items](https://docs.github.com/en/account-and-profile/how-tos/profile-customization/pinning-items-to-your-profile) и [Profile README](https://docs.github.com/en/account-and-profile/concepts/personal-profile).

Все файлы подготовлены локально. Upload, commit, push и публикация профиля не выполнены.
