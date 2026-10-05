# Translator-Brand-GitHub — внедрение

Дата: 05.10.2026. Полная самостоятельная Orca-сессия, native ID `01a1030e-0fcc-7430-8c9d-070c3f569b23`, handle `term_d2396908-a619-4d51-8870-c7db61de6df1`. Cwd `/Users/den/Documents/dev/selection_translator_anki`, branch `mac`, base `6931540ad76a6ab7a5abe70d49c513e93e881d36`. Восстановление из cwd проекта: `codex resume 01a1030e-0fcc-7430-8c9d-070c3f569b23`, только если ID не запущен одновременно. Registry и фактическая история — [PROGRESS](../PROGRESS.md).

Owned paths: root README, design кроме соседних macOS/Web reports, Social preview и доступный profile README. Runtime приложение и production site изменяют отдельные владельцы. Доставку в mac координирует эта сессия, Git operations сериализованы.

| Уровень | Результат | Доказательство |
|---|---|---|
| Assets/source | PASS | 12/12 final manifest SHA256/bytes/source equality; [receipt](github-assets.json); artwork не перерисован |
| README local | PASS | Новый final PNG и утверждённая русская подпись; старые download/platform/ad-hoc факты сохранены |
| README GitHub render | NOT_DONE | Проверяется после общей Git-доставки |
| GitHub account/repo access | PASS | forge-access user HTTP200 gorodtx; целевой repo admin/push=true, default mac |
| Social preview upload/save | PASS | Штатный Settings/file picker; выбран утверждённый RU PNG; карта просмотрена после upload |
| Social preview persistence/image | PASS | GraphQL custom=true и [public image](https://repository-images.githubusercontent.com/1123960100/5166e0fa-be57-4ed3-8f02-de94d7fb5ef1); HTTP200/image/png/104880 bytes; точное совпадение SHA256 с источником |
| Внешнее распространение ссылки/кеши | NOT_DONE | Не выполнялась отправка в сторонние платформы |
| Profile README | NOT_DONE | `gorodtx/gorodtx` GET404, среди всех 12 доступных repo profile отсутствует. Нужен отдельный profile repo; готовый [snippet](../translator-icon/github/profile/README-snippet.md) сохранён |
| Pinned/общая аватарка | NOT_DONE | Не изменены; штатная Pinned card не объявлена носителем кастомной иконки |
| Commit/push/remote SHA/CI | NOT_DONE | Ожидается приёмка macOS/Web |
| Public site/new release | NOT_DONE | Новый hosting/domain/release этой задачей не выбран; существующий v0.3.0 сохраняется |

Фактическое изображение после доставки на CDN:

![Проверенный Social preview с GitHub](https://repository-images.githubusercontent.com/1123960100/5166e0fa-be57-4ed3-8f02-de94d7fb5ef1)

Локальное evidence: [CDN PNG](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/published-social-preview.png>), [GraphQL](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/saved-open-graph.json>), [первое пустое наблюдение после reload](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/social-preview-after-reload.png>). Пустое наблюдение сохранено как ограничение UI, не скрыто положительным CDN результатом. Команды: `forge-access remote/auth github`, scoped `gh api repos/...`, `gh repo list ...`, GraphQL только двух полей, actual CDN curl и SHA256/equality через `uv run --no-project python`.
