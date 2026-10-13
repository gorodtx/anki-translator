# Размещение онлайн-демо

Проект изолирован в `/opt/translator/`, Compose project `translator`. Новый адрес: `https://translator.94.156.237.179.nip.io/`. Развёртывание выполняется только после source checks; доступность URL подтверждается отдельно.

Источник — подтверждённый Git snapshot. Archive содержит только `web/`, `web_backend/`, `translate_logic/`, pyproject/lock и собственные deployment files; credentials, `.env`, `.git`, design drafts и пользовательские данные не передаются. Для сборки copy `deploy/translator/.dockerignore` в корень отдельного source snapshot.

```sh
cd /opt/translator/releases/<confirmed-source-sha>
TRANSLATOR_REVISION=<confirmed-source-sha> docker compose -p translator -f deploy/translator/compose.yaml up -d --build
```

Контейнер не публикует host ports, в том числе 80/443. Внешняя существующая сеть `collective-front-migration_default` объявлена в нашем Compose и имеет уникальный alias `translator-api`; её не пересоздавать. Нужный блок [Caddyfile.block](Caddyfile.block) добавляется к общему Caddyfile только после hash guard и backup. Existing kt/app blocks сохраняются байт-в-байт. Затем `caddy validate` и graceful `caddy reload` в существующем контейнере. Другие Collective containers, volumes, SSH и firewall не менять.

Первичная установка БД: [prepare-db.sh](prepare-db.sh) получает подтверждённый public release download URL аргументом, сверяет pinned SHA256 и атомарно переименовывает `.part`. При повторном запуске совпавшие базы отмечаются REUSE и не загружаются. Кодовые обновления не включают базы в image и не меняют `/opt/translator/db`; Compose монтирует их read-only. Имена репозитория в script/Compose не зашиты; после rename разрешать canonical repository отдельно.

Runtime: один непривилегированный UID10001, read-only root, tmpfs32MiB, cap_drop ALL, no-new-privileges, 512MiB memory limit, 1.5 CPU, pids limit96. Frontend обслуживается FastAPI/StaticFiles; Node нужен только на build stage. Uvicorn access log выключен; текст запроса/ответа в production logs не записывается adapter-ом.

Откат: запустить только проект translator с предыдущим подтверждённым revision/source snapshot. Caddy-backup восстанавливать только при совпадении current hash с нашей неудачной редакцией; не перезаписывать параллельные изменения владельца ingress. Для проверки нужны новый HTTPS URL, `/api/health`, actual translation, все три DB queries, asset MIME и повторные HTTP200 у `kt`/`app`. Публичный site не доказывает новый release macOS; DMG/tag этой задачей не меняются.

Серверный резерв: `prepare-model.sh translator-demo:<confirmed-sha>` устанавливает отдельную модель OPUS-MT en-ru, Apache-2.0 по [официальной карточке](https://huggingface.co/Helsinki-NLP/opus-mt-en-ru). Исходный архив закреплён SHA256; converter4.8.2/int8 и file manifest проверяются. Повторный запуск выдаёт REUSE. `/opt/translator/models/en-ru` монтируется read-only; веса не входят в Git/image. Серверный API использует модель только при отказе/отсутствии перевода основного pipeline, возвращает source `local-opus-mt`; popup показывает этот источник. Native app/общий движок не меняются. Inference ограничен одним CPU worker даже после timeout/cancel. HTTP429 Google не обходится прокси или подменой пользователя.
