# Эпик 5 — Онлайн-демо Translator

Создан: 13.10.2026. Владелец: текущая самостоятельная Root-сессия. Статус: **RESEARCH_COMPLETE; DELIVERY_NOT_DONE; FORMAT_AND_HOST_PENDING**.

## Цель и текущий steering

Посетитель существующего лендинга пробует Translator без скачивания. Пользователь описал именно версию macOS, работающую на сервере. Настоящий native stream и отдельный web-клиент к общему движку — разные результаты; заменять первый вторым без согласования нельзя.

По новому поручению прежние задачи по памяти, README и FPS выполняет другая сессия. Здесь они не продолжаются. Нативный дизайн, логотип, действующие настройки и пользовательские данные сохраняются.

История требований и сделанного остаётся в эпике. Новые сведения добавляются датированными разделами, а завершённые пункты не удаляются.

## Подзадачи и приёмка

- [x] **D01. Восстановить контекст и проверить код.** Подтвердить текущую branch/HEAD, static site, локальный IPC, Apple helper и общий translation pipeline. Результат: [исследование](RESEARCH.md).
- [x] **D02. Найти готовые основы.** Сверить структуру и реальные лицензии AstroWind/Astroship/Cruip; проверить noVNC/Guacamole и границы Appetize/BrowserStack. Не считать наличие шаблона готовым native hosting.
- [ ] **D03. Зафиксировать вид демо.** Native UI либо web pipeline; перечень доступных features, источников, данных и честно отсутствующих возможностей. Вопрос отправлен пользователю.
- [ ] **D04. Подтвердить размещение.** Конкретный host, macOS/Apple Silicon при native, условия публичного использования, домен/HTTPS и ресурсы. Рабочий desktop пользователя не включать в публичный сервис.
- [ ] **D05. Создать страницу в текущем стиле.** Mono assets, system typography, blue/neutral tokens, одна колонка; одна область реального demo, короткий FAQ, GitHub/feedback/download links. Никаких fabricated translations/screens.
- [ ] **D06. Реализовать выбранный runtime.** Native: session broker + viewer + worker readiness + expiry/reset. Web: ограниченный async adapter к общему движку с правдивой индикацией источников. Авторизацию не помещать в static assets.
- [ ] **D07. Проверить успешные и ошибочные сценарии.** Запуск, загрузка, выделение/запрос, реальный результат, no-match, отказ provider, disconnect/reconnect, лимит сеансов, expiry, idempotent stop, отсутствие смешивания данных двух посетителей.
- [ ] **D08. Проверить страницу.** 390 px/desktop, light/dark, клавиатура/focus, reduced motion, root/subpath, Chromium и Safari отдельно. Для native также измерить stream latency/плавность на реальном Mac, не номинальный FPS в конфиге.
- [ ] **D09. Проверить бюджет.** Idle не запускает stream/worker. Конкурентность и память ограничены server-side; RSS browser/worker измеряются отдельно. Старый пользовательский ориентир 1 ГБ не распространять молча на всю macOS VM; бюджет выбранного runtime согласовать по измерениям.
- [ ] **D10. Доставить.** Логические English ASCII commits с named staging и штатными gates; authorized branch push, remote SHA, реальный CI, затем разрешённый deployment. Подтвердить public HTTPS URL и реальный сценарий извне.

## Условия завершения

Все D01–D10 приняты с evidence. Посетитель реально получает результат без установки; версия демо и её ограничения отражены честно. Статические исходники, build, CI, browser acceptance, серверный runtime и public delivery отмечаются отдельно. Без хоста и runtime эпик не считается выполненным.

## 13.10.2026 — новые знания

AstroWind — подходящая структурная основа, MIT подтверждён. Текущий HTML/CSS достаточен; миграция на template stack не требуется. Astroship имеет расхождение README/файла лицензии, Cruip не следует считать MIT. Браузерный remote client не предоставляет Mac и не решает публичное лицензирование, одновременное управление или очистку данных. Одна очередь посетителей не закрывает условия §2I macOS Tahoe. Полные источники и границы проверок — в RESEARCH.md.

## 13.10.2026 — пользовательская сцена с круговым текстом; вопросы до реализации

Новый steering уточняет интерфейс: посетитель видит сложную английскую фразу, расположенную слева направо по полукругу. Центральное свободное место имеет постоянный размер. Посетитель может заменить фразу своей; длинный текст продолжает окружность/спираль, шрифт постепенно уменьшается. После выделения в центре появляется результат в окне по образцу macOS-приложения. Нужен настоящий перевод введённого текста; видеозапись или заранее подготовленный ответ его не заменяют. Пользователь отдельно попросил сначала разобрать навыки и вопросы, **реализацию в этом ходе не начинать**.

Это новая явно заданная визуальная рамка сайта: Montserrat и указанные cloud/glass references заменяют прежний минимальный static-video подход для demo-сцены. Native-приложение, его системная типографика и принятый Mono branding сохраняются.

Указанные источники:

- [Spinning Text](https://21st.dev/@ibelick/components/spinning-text) — геометрия и круговое движение. Страница показывает React/framer-motion usage и MIT; произвольная спираль, изменяемый текст и selection не считаются готовыми возможностями компонента.
- [Cloudscape](https://21st.dev/@amanshakya307/components/cloudscape) — облачный фон; описание указывает WebGL. Нужны adaptive rendering, остановка в скрытой вкладке и статичный fallback для reduced motion/неподдерживаемого WebGL. Actual code/license ещё требуют проверки перед импортом.
- [MacOS Menu Bar](https://21st.dev/@dhmnpunit/components/mac-os-menu-bar) — укороченная верхняя панель: GitHub, скачивание, поддержка и переход к FAQ. Лишние системные часы/статусы не добавлять автоматически.
- [FAQs Two](https://21st.dev/@meschacirung/components/faqs-component/faqs-two) — нижний FAQ; тексты должны относиться к Translator.
- [Liquid Weather Glass](https://21st.dev/@uilayout.contact/components/liquid-weather-glass) — материал кнопок, не погодное содержимое компонента. Glass/refraction и contrast проверять поверх actual cloud background.

Локальный шрифт найден в `/Users/den/Downloads/Montserrat/` (путь без завершающего дефиса): upright и italic variable TTF. Перед переносом проверить OFL и подготовить self-hosted web assets; внешний Google Fonts запрос не требуется. До уточнения Montserrat относится к странице/круговой фразе, системная типографика popup сохраняет связь с приложением.

OS detection выбирает предлагаемый download, при этом все платформенные ссылки доступны вручную. Browser platform не доказывает Apple Silicon, Arch или GNOME. Для mobile/unknown не предлагать несовместимую установку как автоматически подтверждённую.

Используемые роли навыков: preserve-project-design — boundaries и принятые assets; apple-design — поведение glass/popup/input и reduced motion; design-system — единые tokens и component states; emil-design-eng/review-animations — последующая проверка качества interaction/motion. Установка новых библиотек или миграция проекта этими навыками не предписывается.

Отправлены три вопроса: общий pipeline или Mac/Apple engines; select-all по клику/тапу или выбор фрагментов; idle rotation с остановкой при работе или неподвижная дуга. Перед реализацией зафиксировать ответы, длину ввода/minimum readable font, состояние на 390 px и формат размещения demo-route. Без ответов эти решения не считать утверждёнными.

## 13.10.2026 — ответы и реализация v0

Пользователь принял серверный backend + browser frontend в Apple-стиле; предоставил SSH alias `collective-prod` и ingress guide. Native desktop stream больше не является целью этой итерации. Desktop — обычный drag selection фрагментов, touch — тап по всей фразе. Вращение исключено. Перевод запускается только кнопкой; хоткеи отложены. Присланный React-код адаптирован в отдельном `web/`: React/TS strict, Tailwind 4, shadcn structure; `web/AGENTS.md` постоянно требует apple-design для UI задач.

Сервер измеренно Linux: Apple-only frameworks там недоступны. Backend использует тот же общий translation pipeline, read-only primary/fallback/definitions SQLite и Google/Cambridge. Это отражено в FAQ/capabilities; Apple engines остаются в installed Mac app. Browser history — 12 записей в памяти вкладки. Anki посетителя и реальные донаты не подключены; placeholder поддержки разрешён пользователем, URL платежей ещё отсутствует.

D03 и выбор Linux host из D04 подтверждены. D05/D06 source готовы; D07 unit/local checks прошли. Полный исходный D04/D08/D10 требует HTTPS, deployed runtime, публичной browser acceptance и доставки, которые на этом checkpoint ещё не завершены.

Новые критерии: неизменная центральная область при изменении текста, геометрическое уменьшение шрифта при overflow без вращения, корректное сохранение touch selection после native compatibility click, отсутствие чёрного WebGL кадра при смене темы, client/server timeouts и защита от поздних ответов. Базы загружаются на сервер один раз и повторно используются при code-only deployments.
