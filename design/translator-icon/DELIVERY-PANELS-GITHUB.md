# Translator · Панель, аватар и GitHub card

Два связанных дополнения к прежнему Mono icon system, выполненные в одном локальном файле Penpot.

- `menu-bar/translator-line-white.svg` и `menu-bar/translator-line-white.png` — белая линия «клубок → ровная горизонталь», прозрачный фон.
- `menu-bar/macOS/TranslatorMenuBar.imageset` — Xcode template artwork 1x/2x/3x для маленькой панели.
- `github/avatar-500.png` — основной квадратный аватар; рядом 1024 и Dark.
- `github/repo-card-ru.png` — 1280×640, основной repository Social preview. `repo-card-en.png` — английский вариант.
- `github/profile/` — assets и фрагмент README для карточки с логотипом в профиле.
- `Translator-Mono.penpot` в архиве — полный редактируемый проект, 23 макета.

Просмотр: `menu-bar/preview/index.html` и `github/preview/index.html`. Полные инструкции находятся в README соответствующих папок. Белый logo не содержит тёмный фон его preview.

Проверено: один непрерывный Path в panel artwork; прозрачность и RGB готовых PNG; фактический native AppKit load трёх scales; совпадение геометрии с Penpot; SVG XML и отсутствие повторных IDs; 1280×640 и файлы GitHub меньше 1 MB; margins 80 px; сохранение основных элементов аватара внутри круга; font runs Inter; previews без переполнения на 390 px; новые макеты внутри server-exported `.penpot`; CRC архивов. Действующие приложение и GitHub-профиль не менялись.

GitHub Social preview загружается через Settings → General → Social preview → Edit → Upload an image… . Штатные Pinned cards не имеют отдельной аватарки репозитория. Для изображения проекта на странице профиля передан готовый фрагмент README и его локальные assets.
