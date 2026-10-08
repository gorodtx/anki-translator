# Установщик Translator на macOS: исследование EPIC-04

Дата: 08.10.2026. Статус: **B выбран пользователем; implementation отложена прямым указанием пользователя**. Код установщика, сборки и установленное приложение не изменялись.

## Решение пользователя после исследования

Пользователь: «зафиксируй вариант b но пока к реализации не переходим». Зафиксирован **B — DMG с PKG внутри и отдельным завершающим шагом для checkbox «Удалить установщик», ON по умолчанию**. Требование cleanup не отменено. Plain PKG без доказанного завершающего UX не считается готовым решением.

Ни реализация, ни установка, ни новые desktop tests этим выбором не разрешены. Повторный вопрос A/B/C не требуется. Первоначальная recommendation A и сравнительное исследование ниже сохранены как история обсуждения; текущий выбранный путь — B.

## Первоначальный вывод исследования

Первоначально исследователь рекомендовал **DMG с отдельным нативным приложением «Установить Translator»**. Пользователь открывает его, нажимает «Установить», затем видит результат и включённый checkbox «Удалить установщик». Это позволяло бы точно выполнить требование и сохранить SwiftUI/AppKit, утверждённые ресурсы и самостоятельный полный bundle Translator. После обсуждения пользователь выбрал B; этот текст не заменяет его решение.

Google Drive действительно использует **DMG с PKG внутри**: официальная инструкция администратора вызывает `installer` для `GoogleDrive.pkg`. Это подтверждает установку без перетаскивания, но не подтверждает конкретный завершающий checkbox и его default-on состояние. Текущий бинарный установщик Google не скачивался и его интерфейс лично не проверялся. [Google: установка Drive для организации](https://support.google.com/a/answer/7491144?hl=en), [Google: установка Drive пользователем](https://support.google.com/a/users/answer/13022292?hl=en).

Ни DMG, ни PKG, ни self-install сами по себе не устраняют Gatekeeper. По ответу пользователя Apple Developer Program отсутствует; это входной факт, а не результат аудита аккаунта. Для обычной внешней дистрибуции нужны Developer ID и notarization. До этого возможна ограниченная ad-hoc разработка, но беспрепятственный запуск скачанного установщика обещать нельзя. [Apple: Developer ID](https://developer.apple.com/developer-id/), [Apple: безопасное открытие приложений](https://support.apple.com/en-us/102445).

## Что измерено и что остаётся неизвестным

| Область | Доказательство и предел |
| --- | --- |
| Исходники | Чтение checkout `mac`, base `f7db5653ed7c503f554d4fadfc9e531bcda068b1`. В ходе работы Root добавил `1310b5f` и `ffbd50b`; финальный HEAD и hashes фиксируются в PROGRESS. |
| Google | Официальные инструкции прочитаны 08.10.2026. Английская admin-страница после ошибки обычного fetch прочитана через публичный Jina Reader по skill Agent Reach. Авторизация и браузер не использовались. |
| Apple | Официальные документы о подписи, notarization, Accessibility, FileManager и архивные Distribution XML/TN2206; локальный `man hdiutil`. Архивные справочники используются только в указанном узком объёме. |
| Google cleanup UX | **Не проверено**: фактический завершающий диалог, checkbox, значение по умолчанию и различия между версиями macOS. |
| Translator runtime | Только source review. Installed306, текущие grants, History/DB/Anki, first launch и Gatekeeper этой сессией не проверялись и не менялись. |
| Доставка | Первый frozen research уже в `ecd1da38406593f3b972433c95b177fc25fbc8d3`. Новый docs-only B/first-run checkpoint доставляется отдельным commit по переданному Git lease. Final commit/remote/public bytes/CI — в отдельном `INSTALLER-B-DELIVERY.json`/`.md`, без подмены runtime acceptance. Public RC `v0.3.1-rc.1` не пересобирается и не заменяется. |

Контекст сверён через CONTINUE и независимый history search. Старые записи о `scripts/install_macos.sh` исторические: такого файла в текущем checkout нет. Старые healthcheck/rollback результаты не перенесены в acceptance будущего установщика.

## Текущее устройство проекта

| Source | Факт, существенный для установщика |
| --- | --- |
| [`scripts/package_macos_dmg.sh`](../../scripts/package_macos_dmg.sh) | Проверяет полный arm64 bundle/macOS 26+, build-info, отсутствие SQLite payload и strict codesign; копирует `Translator.app`, добавляет ссылку `/Applications`, создаёт и проверяет DMG/checksum. Сейчас установка предполагает Finder drag. PKG/helper/транзакции установки нет. |
| [`scripts/build_macos_app.sh`](../../scripts/build_macos_app.sh) | Собирает native shell, embedded Python, backend launcher и Apple sidecar; переносит ресурсы до подписи. User DB не является частью app payload. Требуется копировать полный bundle, не один executable. |
| [`.github/workflows/macos.yml`](../../.github/workflows/macos.yml) | Есть DMG packaging и разделение ad-hoc RC / stable Developer ID + notarization. Подготовка и подпись PKG или нового helper ещё не реализованы. Читались только ссылки на inputs в source; credential stores не аудировались. |
| [`Resources/Info.plist`](../../macos/Translator/Resources/Info.plist) | Основная identity `com.translator.desktop`, `LSUIElement`, Services. Их сохранять; отдельный installer должен иметь собственную identity. |
| [`BackendBootstrap.swift`](../../macos/Translator/Sources/Translator/BackendBootstrap.swift) | App запускает свой backend из bundle; `stop()` завершает только принадлежащий этому экземпляру child Process. Возможен attach к совместимому чужому/legacy backend. Нельзя считать любой отвечающий backend своим. |
| [`TranslatorApp.swift`](../../macos/Translator/Sources/Translator/TranslatorApp.swift) | Native app владеет bootstrap и завершением child в `applicationWillTerminate`. Обновление требует завершения точного экземпляра app до замены файлов. |
| [`SelectionCapture.swift`](../../macos/Translator/Sources/Translator/SelectionCapture.swift) | Trust читается через AX API; запрос permission и выдача пользователем — отдельные действия. Services-путь не требует Accessibility. |
| [`AppDefaults.swift`](../../macos/Translator/Sources/Translator/AppDefaults.swift), [`LoginItem.swift`](../../macos/Translator/Sources/Translator/LoginItem.swift) | Настройки app сохраняются отдельно; login item управляется `SMAppService.mainApp`. Installer не регистрирует и не сбрасывает autostart. Исторический комментарий о backend launchd не доказывает текущую runtime-конфигурацию. |
| [`platform/paths.py`](../../desktop_app/platform/paths.py), [`locations.py`](../../translate_logic/infrastructure/language_base/locations.py) | User support находится в `~/Library/Application Support/Translator`, базы — отдельно от app, logs — в `~/Library/Logs/Translator`. Читались определения путей, не пользовательские данные и не фактические env overrides. |
| [`history_persistence.py`](../../desktop_app/infrastructure/services/history_persistence.py) | History записывается отдельно, с atomic replacement и финальным flush при close. Обновление должно дать backend штатно завершиться; installer не пересоздаёт history и не читает её содержимое. |

Дизайн: нативные окна, системные controls/checkbox, существующая типографика и approved AppIcon/MenuBar resources. Новый installer не требует смены стека или генерации artwork. [AFFiNE](https://github.com/toeverything/affine) — предоставленный пользователем смежный presentation reference; не доказательство устройства Google installer и не основание переносить его архитектуру в Translator.

## Три варианта

Оценки ниже — предварительный инженерный диапазон для одного исполнителя после выбора scope, включая целевые проверки ошибок. Это не измеренные сроки. Ожидание Developer Program, выдачи сертификатов и разрешённой проверки на отдельных Mac не включено.

| Вариант | UX и права | Соответствие требованию | Предварительный объём |
| --- | --- | --- | --- |
| **A. DMG + отдельный native installer helper — первоначальная рекомендация, не выбран** | Открыть «Установить Translator» → кнопка установки → завершение. Копирование без повышения прав в доступный `/Applications`; для новой установки возможен явно выбранный `~/Applications`. Если существующая системная app недоступна для замены, остановка с объяснением, без скрытой второй копии. | Точный default-on checkbox, свой контроль copy/verify/rollback/eject/Trash. Повышение прав — отдельное решение, не обещанный password prompt. | **6–10 рабочих дней**. Native target, state machine, безопасный handoff вне DMG, ресурсный packaging, scoped failure tests. |
| **B. DMG + PKG через Apple Installer, как у Google — выбран** | Двойной клик PKG → системный мастер. Для системной установки штатная авторизация администратора; per-user domain возможен только при совместимом продукте. | No-drag проще. Точный checkbox после успеха не подтверждён стандартным Installer; нельзя обещать управляемый default-on. Сохранённое требование будет выполнять отдельный завершающий helper. | **3–5 дней** для базового PKG; **6–10** с собственным завершающим helper. Добавляются receipts, package identity, root/user граница и собственный rollback. |
| **C. Самоустанавливающийся Translator.app** | Пользователь открывает Translator из DMG; app предлагает копирование, затем запускает установленную копию. | Checkbox реализуем. Сложнее отделить установку от backend/bootstrap/TCC/first-run и избежать двух экземпляров. | **8–12 дней**. Перестройка раннего app lifecycle, handoff/relaunch, работа с translocation, duplicate identity и failure recovery. |

Для A первый этап разумно ограничить доступной без root директорией. Если обязательна установка/замена в `/Applications` любым стандартным пользователем с системным запросом администратора, выбрать B либо отдельно расширить A; не добавлять привилегированный daemon ради простого копирования без обсуждения.

Для B архивная [Distribution XML Reference](https://developer.apple.com/library/archive/documentation/DeveloperTools/Reference/DistributionDefinitionRef/Chapters/Distribution_XML_Ref.html) описывает final `conclusion` как документ, package choices, installation domains и `must-close` app. Это не документированный контракт нужного завершающего checkbox. `currentUserHome` допускает user-scoped установку; его совместимость с Translator ещё не проверена. Из архивного справочника нельзя копировать старые architecture enums в текущий arm64 packaging.

## Подпись, notarization и TCC

App/helper используют **Developer ID Application**, подписанный PKG — **Developer ID Installer**. При добавлении нового исполняемого компонента проверяется весь вложенный код и конечный контейнер. Для custom installer Apple отдельно описывает notarization доставляемого payload и самого installer; одной проверки PNG, checksum или `codesign --verify` недостаточно для Gatekeeper. [Apple: notarization issues](https://developer.apple.com/documentation/security/resolving-common-notarization-issues), [Apple: custom notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

При отсутствии Developer Program helper не делает ad-hoc payload доверенным. В будущую реализацию не включаются отключение Gatekeeper, массовое удаление quarantine, сброс TCC или обход trust logic. Даже подписанный/notarized установщик может получить обычный системный first-open prompt; отсутствие перетаскивания не означает ноль действий пользователя.

Основной Bundle ID и путь установки сохраняются при update. Кодовая identity определяется также signature/designated requirement: одинаковый Bundle ID сам по себе не гарантирует сохранения разрешения при новой ad-hoc сборке. Вывод о риске повторного TCC-запроса — **инженерная оценка** по текущему ad-hoc режиму и принципам code identity, а не измерение grants installed306. Стабильные Developer ID/Team/DR уменьшают риск, но не заменяют проверку реального обновления. [Apple TN2206: code identity и policy subsystems](https://developer.apple.com/library/archive/technotes/tn2206/_index.html).

Accessibility выдаёт сам пользователь в Privacy & Security. Installer не получает это разрешение за Translator и не меняет базу TCC. После установки app может показать реальный статус и открыть системную страницу по действию пользователя. [Apple: разрешение Accessibility](https://support.apple.com/guide/mac-help/mh43185/mac).

## Обновление работающего приложения и rollback

Предлагаемый контракт для выбранного варианта; пока не реализован:

1. Проверить исходный полный payload, version/build, revision/resources, архитектуру, minimum OS и требуемую signature policy. Подготовить staging на том же filesystem, что и целевой bundle, до изменения старой app.
2. Определить installed target и running instance по Bundle ID **и точному пути/PID**, затем предложить штатное завершение. Дождаться native app и именно её backend child; legacy/чужой backend не завершать. При отказе, зависании или неизвестном ownership — не заменять app.
3. Убедиться в правах, отсутствии подмены target/symlink и конфликта двух installers. Сохранить точную старую app и журнал операции отдельно от user data. Переключить проверенные bundle через контролируемые rename; несколько rename не являются общей atomic transaction, поэтому нужен recovery-журнал.
4. Повторно проверить конечную app и не очищать backup до принятой политики rollback. Если копирование, switch или verification неуспешны, вернуть старую app и явно сообщить результат. Не удалять источник установщика после ошибки.
5. Запуск установленной app — отдельное действие. Ошибка выбранного запуска должна оставить backup и installer для восстановления. Готовность всех offline DB, grants и Anki не является обязательным доказательством успешного файлового копирования.

Rollback здесь возвращает **app bundle**, не содержимое БД/History. Если последующее app version меняет формат данных, обратная совместимость и миграционный rollback требуют отдельного контракта. Installer не обещает откат пользовательских данных и не перезаписывает их старой копией.

## «Удалить установщик»: безопасный контракт

Термин в UI означает **переместить точный скачанный installer в Корзину**, а не безвозвратно удалить его, очистить Downloads или удалить mounted volume. Для выбранного B это исходный `.dmg`; для отдельно обсуждаемого прямого PKG — конкретный `.pkg`. PKG внутри DMG и каталог `/Volumes/…` не являются скачанным файлом.

Сценарий: успешное копирование и verification → финальное окно с checkbox **ON** → пользователь нажимает «Готово» → освобождение image → подтверждённый detach → Trash точного исходного файла. Снятый checkbox оставляет скачанный файл; eject можно выполнить отдельно, без удаления.

Технические условия:

- Источник определяется через связь mounted device → backing image, а не по имени volume или поиску `Translator*.dmg` в Downloads. До/после операции проверяются identity файла и права текущего пользователя; неоднозначный источник, symlink или изменившийся файл означает пропуск cleanup.
- Сам helper, исполняемый с DMG, сначала требует проверенного handoff полной копии вне image и освобождения references/working directory. Возможность такого handoff с quarantine/App Translocation ещё предстоит проверить. Удалять образ, из которого ещё выполняется installer, заранее нельзя.
- Локальный `man hdiutil` различает `unmount` и `detach`: первый не отсоединяет image. `detach -force` игнорирует открытые files; для cleanup force не использовать. Busy image остаётся на месте с честным сообщением и возможностью ручного eject.
- После подтверждённого detach применяется user-scoped [`FileManager.trashItem(at:resultingItemURL:)`](https://developer.apple.com/documentation/foundation/filemanager/trashitem(at:resultingitemurl:)). Это recoverable Trash API; result URL позволяет зафиксировать фактический результат. Root postinstall не перемещает произвольный файл в чужую Корзину.
- Отказ доступа, отмена, неизвестный backing file или неудачный Trash **не превращают корректно установленную app в «не установлена»**. В UI отдельно: «Translator установлен» и «Установщик сохранён: …». Успех cleanup подтверждается собственным результатом, не checkbox или exit первого copy.
- Никогда не удаляются installed app, rollback copy, `Application Support/Translator`, History, Anki-профиль или другие образы/загрузки. Очистка временной копии helper имеет собственные точные границы и не даёт права на очистку Downloads.

## Критерии следующего этапа и зависимости

Подробный epic и будущая матрица проверок: [EPIC-04-INSTALLER.md](EPIC-04-INSTALLER.md). Каждый будущий PASS разделяет source/unit, artifact verification, реальную установку, cleanup, Gatekeeper и TCC. Сейчас real install acceptance отсутствует; computer-use остаётся остановлен.

До реализации выбранного B требуется отдельное разрешение пользователя, подтверждение destination/admin поведения и дизайн завершающего helper. До заявления о публичной удобной установке требуется Developer ID/notarization и отдельно разрешённая проверка downloaded/quarantined артефакта на поддерживаемом Mac. Новый public release и замена installed306 не входят в это исследование.

Исходный вопрос A/B/C закрыт ответом **B**. Следующая discussion — качество первого запуска и границы будущей реализации; implementation остаётся отложенной.

## Текущий сценарий нового пользователя

Дополнение после выбора B. Основано на текущих исходниках и [docs/macos.md](../macos.md), не на новом real install/GUI acceptance. Существующая установка, grant и пользовательские файлы не читались. B ещё не реализован; опубликованный путь остаётся **DMG → drag в Applications**.

### Установка и открытие сегодня

1. Нужны Apple Silicon и macOS 26+. Текущий bundle не рассчитан на Intel или более старую macOS.
2. Скачать DMG около 27,4 МБ, открыть его, перетащить `Translator.app` в Applications и запускать установленную копию. Embedded Python/backend/helper уже внутри: terminal, Python, uv и исходники пользователю не нужны.
3. Ad-hoc подпись без Developer ID/notarization может привести к блокировке первого открытия. Apple описывает ручной Open Anyway после попытки запуска через Privacy & Security; управляемый Mac может ограничивать этот путь. Это не беспрепятственная публичная установка. [Apple: первое открытие](https://support.apple.com/en-us/102445).
4. App сама запускает свой backend. По source [`openSetupIfUnfinished`](../../macos/Translator/Sources/Translator/TranslatorApp.swift) после короткого ожидания проверяет реальное состояние и при незавершённой настройке открывает General.
5. Дальнейшая настройка распределена между General, Sources, Anki и Advanced; текущие подписи Settings — английские. Это checklist, а не единый последовательный wizard.

### Минимум: получить перевод

| Путь | Что требуется | Предел |
| --- | --- | --- |
| Services | Выделить текст в поддерживающем Services приложении → Translate with Translator; доступный translation source и работающий backend. | Accessibility не нужна. Services зависит от поддержки исходным приложением; реальные свежие действия на чистом Mac не проверены. |
| Глобальная клавиша | Работающий Translator, AX grant через системные настройки и зарегистрированное сочетание; доступный source. | По fresh-profile source default **Option + Command + T (`⌥⌘T`)**. Существующий профиль восстанавливает сохранённое сочетание; его фактический config не читался. |
| Первый онлайн source | Включить Google в Sources; интернет. | [`google.py`](../../translate_logic/infrastructure/providers/google.py) обращается к внешнему endpoint без пользовательского API key и не читает offline DB. Это source факт о provider, а не подтверждение успешности полного pipeline на чистом Mac или гарантированной доступности Google. |
| Офлайн-перевод Apple | В Sources скачать English → Russian кнопкой Download… и подтвердить штатную загрузку Apple. | [`LanguagePairControl`](../../macos/Translator/Sources/Translator/SettingsSourcesPane.swift) вызывает `prepareTranslation()`. До загрузки пары системный API не доказывает готовность offline перевода. |

Разрешение Accessibility выдаёт пользователь. App может открыть системную страницу; installer не выдаёт grant и не меняет TCC. [Apple: Accessibility](https://support.apple.com/guide/mac-help/mh43185/mac).

Проверено в [`KeyCombo.swift`](../../macos/Translator/Sources/TranslatorCore/KeyCombo.swift): новый default `commandMask | optionMask`; [`AppModel.swift`](../../macos/Translator/Sources/Translator/AppModel.swift) подхватывает сохранённое значение, включая отключённую shortcut. Нельзя переносить прежнее пользовательское Shift + Command + T на все новые установки.

### Трение нынешнего checklist

[`SetupPlanner`](../../macos/Translator/Sources/TranslatorCore/Setup.swift) помечает **все три offline DB, Accessibility и shortcut как обязательные**. Поэтому пользователь видит незавершённый Setup даже при возможном использовании Services или отдельного online source. Backend может запуститься без баз; это не означает полной offline готовности.

Полный download для пустого профиля в текущей документации — **1 896 546 304 байта, около 1,90 ГБ**. DMG значительно меньше, поэтому размер загрузки ресурсов должен быть понятен до её начала. Checklist показывает недостающий объём и progress; updater не должен заставлять скачивать существующие базы заново.

Это UX-находка, а не разрешение изменить required gates. Возможный будущий путь «первый перевод сейчас, дополнительные ресурсы позже» требует отдельного решения. Чистый runtime без DB и фактический первый lookup этой сессией не проверялись.

### Максимум: подключить возможности приложения

| Возможность | Действие пользователя |
| --- | --- |
| Hotkey / popup под курсором | Выдать Accessibility, проверить shortcut в General и держать Translator открытым. |
| Google / Cambridge | Включить нужные Sources; нужен интернет. Ответ зависит от доступности внешних сервисов. |
| Apple offline phrases | Скачать language pair через Sources. |
| Локальные examples / definitions | Download… для трёх DB; дождаться загрузки и проверки SHA256. Базы хранятся отдельно от app. |
| Apple Dictionary | Проверить availability; при отсутствии нужных словарей открыть Dictionary.app и включить/загрузить их. Наличие framework не равно установленному словарю. |
| History | Специальный onboarding не нужен; backend сохраняет историю отдельно от bundle и восстанавливает при запуске. Это source contract, не новое измерение существующей истории. |
| Anki integration | Установить настольный Anki с AnkiConnect; открыть нужный профиль, оставить Anki работающим и проверить Connection в Settings → Anki. |
| Anki deck / note type / fields | Выбрать колоду; проще Create Note Type для типа Translator. Для собственного типа сопоставить Word, Translation, Example, Definitions, Image. Connected подтверждает connection, не правильность mapping. |
| Add / duplicate / merge / image | Выполнить пробное Add to Anki и проверить результат. Картинка выбирается файлом в окне Add to Anki. Реальные проверки коллекции и полного upsert не выполнены в этой сессии. |
| Open at login | Включить General → Open at login; при requiresApproval подтвердить через Login Items. Установщик не регистрирует это молча. |

Anki шаги проверены по [`SettingsAnkiPane.swift`](../../macos/Translator/Sources/Translator/SettingsAnkiPane.swift) и [`AnkiUpsertSheet.swift`](../../macos/Translator/Sources/Translator/AnkiUpsertSheet.swift). Фактические Anki add/merge/media и синхронизация пользователя здесь не тестировались. AnkiWeb — отдельная опциональная настройка Anki, не условие локального подключения Translator.

### Что изменит B и что останется после установки

Ожидаемый будущий flow: **DMG → PKG → системный мастер → при необходимости admin authorization → успешная установка → завершающий шаг с default-on cleanup → запуск Translator**. Детали helper ещё не спроектированы и не приняты runtime-проверкой.

B упростит установку файлов и завершение installer. Он не заменит Developer ID/notarization и не настроит автоматически Accessibility, Apple resources, Anki или login item. Эти действия останутся первым запуском app. Сейчас минимум после успешного открытия сравнительно короткий, а полный набор требует нескольких отдельных шагов и большой загрузки DB. Изменять onboarding, runtime и backend под видом выбранного packaging без отдельного scope нельзя.
