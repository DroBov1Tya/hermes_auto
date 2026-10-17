# Настройка Hermes для пентеста

English version: [README.md](README.md)

Интерактивный установщик на Bash создаёт отдельный профиль Hermes. В меню можно выбрать MCP-серверы, группы skills и `SOUL.md`. Сканирование целей и запуск Docker-контейнеров установщик не выполняет.

## Быстрый запуск

Сначала установите [Hermes Agent](https://hermes-agent.nousresearch.com/docs/getting-started/installation/), SQLite CLI (`sqlite3`) и Git. Docker и `uv` нужны при выборе kali-mcp; для Playwright нужны Node.js и `npx`. Пункт PentaCore требует `curl`, `jq`, `tar` и утилиту SHA-256. SQLite — дополнительная утилита просмотра данных; PentaCore включает SQLCipher.

Запуск из клонированного репозитория:

```sh
bash install.sh
```

После публикации публичного репозитория тот же установщик будет доступен одной командой:

```sh
curl -fsSL https://raw.githubusercontent.com/DroBov1Tya/hermes_auto/main/install.sh | bash
```

В меню выберите нужные MCP, категории skills и файлы профиля. Kali MCP и skill `kali-workbench` объединены в один пункт. Enter принимает предложенный выбор, `n` пропускает компонент. Настройки существующего профиля и уже существующие skills сохраняются.

Если выбрали Kali, перед запуском контейнера настройте прокси:

```sh
${EDITOR:-vi} ~/.local/share/hermes-pentest/kali-mcp/.env
cd ~/.local/share/hermes-pentest/kali-mcp
docker compose up -d --build
```

Укажите SOCKS5 listener, доступный из Docker, настройте провайдера Hermes и проверьте список MCP:

```sh
hermes -p <profile-name> setup
hermes -p <profile-name> mcp list
hermes -p <profile-name> chat
```

Вместо `<profile-name>` укажите имя, введённое в меню (по умолчанию `pentest`).

## Пункты меню

| Пункт | Что устанавливается | По умолчанию |
| --- | --- | --- |
| PentaCore | Последняя версия бинарника, skill `pentacore-memory` и MCP | Да |
| kali-mcp | Зафиксированный checkout, Python-окружение, MCP и upstream skill `kali-workbench` | Да |
| Playwright | Регистрация Microsoft Playwright MCP через `npx` | Нет |
| Strix playbooks | 29 skills по классам уязвимостей и зависимость `llm_applications` | Да |
| OWASP MCP review | Статическая проверка исходников и конфигурации MCP-серверов | Да |
| Bug bounty reporting | Подготовка отчётов и работа с evidence | Да |
| Пользовательские workflow skills | Skills из предоставленной папки без изменений | Да |
| `SOUL.md` | Предоставленные инструкции профиля без изменений | Да |

Будущие MCP и категории skills можно добавить отдельными пунктами меню. При отказе от kali-mcp не устанавливаются ни его исходники и зависимости, ни skill, ни MCP-регистрация.

## Размещение файлов

```text
Профиль Hermes: ~/.hermes/profiles/pentest
├── SOUL.md                         опциональные инструкции профиля
├── skills/                         выбранные пользовательские и upstream skills
└── MCP configuration                выбранные локальные серверы

Локальные файлы:
├── ~/.local/opt/hermes-pentest/     бинарник PentaCore
└── ~/.local/share/hermes-pentest/
    ├── kali-mcp/                    исходники и Compose-проект (по выбору)
    └── strix/                       исходники Strix с закреплённой ревизией
```

| Компонент | Назначение | Примечания |
| --- | --- | --- |
| Hermes profile | Отдельные настройки, память, skills и сессии | Профиль не изолирует локальный terminal от файлов пользователя. |
| PentaCore | Постоянная память через MCP | Архив сверяется с `SHA256SUMS` из того же релиза. |
| kali-mcp | Kali-инструменты через stdio MCP | Команды могут обращаться к сети; контейнеры не запускаются автоматически. |
| [Playwright MCP](https://github.com/microsoft/playwright-mcp) | Необязательное управление браузером | Настройки origin не ограничивают redirects и не заменяют egress-контроль. |
| Caido MCP | Ручное подключение отдельного Caido | Автоматически не устанавливается; изучите документацию перед подключением. |

## Источники skills

Установщик предлагает группы skills на выбор. Strix playbooks загружаются из `usestrix/strix` commit `972f5097c2bfaf8f1dd8b55744ab8861f0d6b6e5`. Включена зависимость `llm_applications.md`, на которую ссылается playbook про prompt injection. Skill OWASP MCP review закреплён на `65d4efd2cd0b081d52101e9708792b944e4ddebb`, а report-writing — на `securityskills/skills` commit `b2b6b5200ee91a249816df209a0b89ff01ae450a`. Skill Kali берётся из закреплённого checkout `DroBov1Tya/kali-mcp`. Пользовательские skills и `SOUL.md` копируются из этого репозитория.

Hermes загружает Strix playbooks по требованию. Некоторые описывают методы с высоким воздействием и предполагают инструменты, которые установщик не ставит. Skills не предоставляют разрешения и не ограничивают цели. Соблюдайте scope, отдельно настройте сетевые ограничения и проверяйте команды перед активным тестированием.

## Необязательный Caido MCP

Интеграция Caido в Strix работает внутри его sandbox и отличается от отдельного подключения MCP к Hermes. Для Hermes установите и проверьте Caido MCP по [документации Caido](https://docs.caido.io/app/tutorials/mcp), затем зарегистрируйте фактический бинарник и loopback URL в профиле. Оставьте listener на loopback и ограничьте проект Caido рамками engagement. Установщик не загружает и не регистрирует сторонний Caido-сервер.

## Платформы и ограничения

Bash-установщик поддерживает PentaCore для macOS Apple Silicon и Linux `x86_64`/`aarch64`. Intel Mac и Windows не поддерживаются. Linux нужна достаточно новая glibc (Ubuntu 24.04, Debian 13 или Fedora 40 и новее). Для kali-mcp нужны Docker и `uv`; для Playwright нужны Node.js и `npx`.

- Последний опубликованный PentaCore может быть prerelease; проверяйте release notes.
- `SHA256SUMS` загружается из того же релиза, что и архив. Это обнаруживает ошибки передачи, но не заменяет независимую подпись.
- Установщик не запускает контейнеры, не сканирует цели, не подтверждает уязвимости и не проверяет Docker runtime.
- kali-mcp принимает shell-команды. Его SOCKS5 маршрут может достигать адресов за пределами локальных правил контейнера. Ограничивайте egress отдельно от агента.
- upstream SSE-конфигурация kali-mcp монтирует Docker socket; этот установщик регистрирует только host stdio-режим.

## Лицензия

Репозиторий распространяется по MIT. Стороннее ПО остаётся под лицензиями upstream-проектов.
