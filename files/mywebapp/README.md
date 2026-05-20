# Лабораторна робота №1 — mywebapp

Розгортання простого веб-сервісу (`Simple Inventory`) з автоматизацією, reverse-proxy (nginx), MariaDB та керуванням через systemd.

## 1. Варіант індивідуального завдання

Номер залікової книжки **N = 26**.

| Параметр | Формула | Значення | Наслідок |
|---|---|---|---|
| V2 | `(26 % 2) + 1` | **1** | конфігурація через **аргументи командного рядка**, СУБД — **MariaDB** |
| V3 | `(26 % 3) + 1` | **3** | застосунок — **Simple Inventory** (облік обладнання) |
| V5 | `(26 % 5) + 1` | **2** | порт застосунку — **5200** |

## 2. Архітектура

```
client → nginx (:80) → mywebapp (127.0.0.1:5200) → MariaDB (127.0.0.1:3306)
```

Усе працює на одній ВМ. Зовнішньо доступний лише nginx на 80 порту. Веб-застосунок і база даних слухають тільки на `127.0.0.1` і ззовні недоступні.

## 3. Веб-застосунок

### Призначення

`Simple Inventory` — сервіс обліку обладнання. Кожен запис інвентарю має поля `id`, `name`, `quantity`, `created_at`.

### API

| Метод | Шлях | Опис | Доступний через nginx |
|---|---|---|---|
| GET  | `/` | HTML-сторінка зі списком ендпоінтів бізнес-логіки | так |
| GET  | `/items` | список усіх предметів (`id`, `name`) | так |
| POST | `/items` | створити запис (поля `name`, `quantity`) | так |
| GET  | `/items/<id>` | детальна інформація (`id`, `name`, `quantity`, `created_at`) | так |
| GET  | `/health/alive` | завжди `200 OK` | **ні** (тільки 127.0.0.1:5200) |
| GET  | `/health/ready` | `200 OK` якщо БД доступна, інакше `500` з описом | **ні** (тільки 127.0.0.1:5200) |

### Узгодження формату (`Accept`-заголовок)

Бізнес-ендпоінти повертають JSON або HTML залежно від заголовка `Accept`:
- `Accept: application/json` — JSON-відповідь;
- `Accept: text/html` — проста HTML-сторінка (без JS, без CSS); списки рендеряться у `<table>`;
- інакше — `406 Not Acceptable`.

Кореневий `/` відповідає лише `text/html` і повертає список ендпоінтів бізнес-логіки.

### Конфігурація

V2 = 1 — конфігурація через CLI-аргументи. Підтримуються такі прапорці:

| Прапорець | За замовчуванням | Призначення |
|---|---|---|
| `--host` | `127.0.0.1` | адреса для прослуховування |
| `--port` | `5200` | TCP-порт |
| `--db-host` | `127.0.0.1` | хост MariaDB |
| `--db-port` | `3306` | порт MariaDB |
| `--db-user` | `mywebapp` | користувач БД |
| `--db-password` | `(порожньо)` | пароль БД |
| `--db-name` | `mywebapp` | назва бази даних |

Якщо застосунок запущено через systemd socket activation (виставлена змінна `LISTEN_FDS`), `--host`/`--port` ігноруються — використовується файловий дескриптор від systemd.

### Стек

- Node.js 18+ (на цільовій ВМ — версія з пакетів Ubuntu)
- Express 4
- mysql2 (драйвер MariaDB/MySQL)

## 4. Локальне середовище для розробки/тестування

### Передумови

- Node.js ≥ 18
- Локально запущена MariaDB (або MySQL) з порожньою БД `mywebapp` і користувачем з повними правами на неї.

Швидке створення БД для розробки:

```sql
CREATE DATABASE mywebapp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'mywebapp'@'127.0.0.1' IDENTIFIED BY 'devpass';
GRANT ALL PRIVILEGES ON mywebapp.* TO 'mywebapp'@'127.0.0.1';
FLUSH PRIVILEGES;
```

### Встановлення залежностей

```bash
cd app
npm install
```

### Міграція БД

```bash
node migrate.js \
  --db-host 127.0.0.1 --db-port 3306 \
  --db-user mywebapp --db-password devpass --db-name mywebapp
```

### Запуск застосунку

```bash
node server.js \
  --host 127.0.0.1 --port 5200 \
  --db-host 127.0.0.1 --db-port 3306 \
  --db-user mywebapp --db-password devpass --db-name mywebapp
```

### Перевірка

```bash
curl -H 'Accept: application/json' http://127.0.0.1:5200/items
curl http://127.0.0.1:5200/health/alive
curl http://127.0.0.1:5200/health/ready
```

## 5. Розгортання

### Базовий образ ВМ

Офіційний серверний образ Ubuntu:
- Версія: **Ubuntu Server 24.04 LTS** (Noble Numbat)
- Джерело: <https://releases.ubuntu.com/24.04/> — файл `ubuntu-24.04.x-live-server-amd64.iso`

### Вимоги до ресурсів ВМ

| Ресурс | Мінімум |
|---|---|
| CPU | 1 vCPU |
| RAM | 1 ГБ (рекомендовано 2 ГБ для запасу під MariaDB) |
| Диск | 10 ГБ |
| Мережа | 1 інтерфейс з NAT/Bridge, доступ до Інтернету для встановлення пакетів |

### Налаштування при встановленні ОС

Жодних особливих вимог. Стандартна автоматична розбивка диску (LVM або без — байдуже). Під час інсталяції створюється один користувач — нехай це буде типовий `ubuntu` (його заблокує наш `install.sh` у кінці). OpenSSH server можна обрати під час інсталяції — це зручно для подальшого віддаленого доступу.

### Вхід на ВМ

Одразу після встановлення ОС логінитесь користувачем, якого створили в інсталяторі (звичайно `ubuntu`), його паролем — через консоль гіпервізора або по SSH. Після запуску `install.sh` цей користувач буде заблокований, і подальші входи можливі тільки під `student`, `teacher` або `operator` (пароль за замовчуванням — `12345678`, треба змінити при першому вході).

### Запуск автоматизації

```bash
# на ВМ, з-під початкового користувача:
sudo apt-get update && sudo apt-get install -y git
git clone <URL_РЕПОЗИТОРІЮ> mywebapp
cd mywebapp
sudo bash deploy/install.sh
```

Що зробить скрипт:
1. встановить пакети (`nginx`, `mariadb-server`, `nodejs`, `npm`, …);
2. створить системного користувача `mywebapp` і людських `student`, `teacher`, `operator`;
3. підніме MariaDB, прив'яже її до `127.0.0.1`, створить БД `mywebapp` і її користувача;
4. розгорне код у `/opt/mywebapp` і виконає `npm install`;
5. встановить systemd-юніти `mywebapp.service` і `mywebapp.socket` (socket activation), запустить сервіс — міграція БД виконається через `ExecStartPre` перед першим запуском;
6. налаштує nginx як reverse-proxy на 80 порту, відкриє назовні лише `/` та `/items*`;
7. встановить `/etc/sudoers.d/operator` з обмеженим набором команд;
8. створить `/home/student/gradebook` з вмістом `26` і заблокує користувача `ubuntu`.

Скрипт ідемпотентний у тому сенсі, що повторні запуски не зламають вже створені обʼєкти (`CREATE ... IF NOT EXISTS`, перевірки `id -u` для користувачів тощо).

## 6. Користувачі системи

| Користувач | Пароль | Права | Призначення |
|---|---|---|---|
| `student` | `12345678` (просрочений) | sudo | повсякденна робота над проєктом |
| `teacher` | `12345678` (просрочений) | sudo | перевірка роботи |
| `operator` | `12345678` (просрочений) | обмежений sudo | управління сервісом і nginx |
| `mywebapp` | — (nologin) | мінімум | системний користувач, від якого працює застосунок |

Користувачу `operator` через `/etc/sudoers.d/operator` дозволено лише такі команди:

```
sudo systemctl start    mywebapp.service     # запуск
sudo systemctl stop     mywebapp.service     # зупинку
sudo systemctl restart  mywebapp.service     # перезапуск
sudo systemctl status   mywebapp.service     # перегляд статусу
sudo systemctl reload   nginx                # reload конфігурації nginx
```

(аналогічні команди для `mywebapp.socket` теж дозволені — потрібно для повного управління при socket-activation).

## 7. Інструкція з тестування розгорнутої системи

Усі команди виконуються або з самої ВМ, або з зовнішнього хосту (там, де явно вказано `http://<VM_IP>`).

### 7.1. Базова доступність

```bash
# зовні через nginx:
curl -i http://<VM_IP>/                                                      # 200, HTML зі списком ендпоінтів
curl -i -H 'Accept: application/json' http://<VM_IP>/items                   # 200, []
```

### 7.2. Бізнес-логіка (CRUD)

```bash
# створити запис
curl -i -X POST -H 'Accept: application/json' \
     -d 'name=screwdriver&quantity=5' http://<VM_IP>/items

# список
curl -s -H 'Accept: application/json' http://<VM_IP>/items
# → [{"id":1,"name":"screwdriver"}]

# деталі
curl -s -H 'Accept: application/json' http://<VM_IP>/items/1
# → {"id":1,"name":"screwdriver","quantity":5,"created_at":"..."}

# та сама деталь у HTML:
curl -s -H 'Accept: text/html' http://<VM_IP>/items/1
```

### 7.3. Узгодження формату

```bash
curl -s -H 'Accept: application/json' http://<VM_IP>/items   # JSON
curl -s -H 'Accept: text/html'         http://<VM_IP>/items   # HTML-таблиця
curl -i -H 'Accept: text/csv'          http://<VM_IP>/items   # 406 Not Acceptable
```

### 7.4. Health-ендпоінти не назовні

```bash
# З ВМ — працює:
curl http://127.0.0.1:5200/health/alive        # OK
curl http://127.0.0.1:5200/health/ready        # OK

# Через nginx — 404 (правильно, не випустили назовні):
curl -i http://<VM_IP>/health/alive            # 404
```

### 7.5. БД доступна лише з ВМ

```bash
# На ВМ — підключення працює:
mysql -h 127.0.0.1 -u mywebapp -p mywebapp

# Зовні (з вашого ноутбука):
nc -vz <VM_IP> 3306                            # connection refused / timeout
```

### 7.6. systemd / socket activation

```bash
systemctl status mywebapp.socket
systemctl status mywebapp.service

# Зупинити сервіс, але залишити сокет:
sudo systemctl stop mywebapp.service
ss -tlnp | grep 5200                           # сокет на 5200 тримається systemd-ом
curl -H 'Accept: application/json' http://127.0.0.1/items   # перший запит підніме сервіс автоматично
systemctl status mywebapp.service              # active (running)
```

### 7.7. Права operator

```bash
# під operator:
sudo systemctl restart mywebapp.service        # дозволено
sudo systemctl reload nginx                    # дозволено
sudo systemctl stop mariadb                    # ЗАБОРОНЕНО (sudo відмовить)
sudo cat /etc/shadow                           # ЗАБОРОНЕНО
```

### 7.8. Перевірка `gradebook` і блокування дефолтного користувача

```bash
cat /home/student/gradebook                    # → 26

# спроба зайти як ubuntu:
su - ubuntu                                    # відмова (account locked)
```

## 8. Структура репозиторію

```
.
├── README.md                  — ця документація
├── .gitignore
├── app/                       — код веб-застосунку
│   ├── package.json
│   ├── server.js              — точка входу (підтримує socket activation)
│   ├── migrate.js             — скрипт міграції БД
│   ├── lib/
│   │   ├── config.js          — парсинг CLI-аргументів
│   │   ├── db.js              — пул зʼєднань з MariaDB
│   │   └── render.js          — HTML-хелпери (escape, table)
│   └── routes/
│       ├── root.js            — GET /
│       ├── health.js          — /health/alive, /health/ready
│       └── items.js           — /items, /items/:id
├── deploy/
│   └── install.sh             — єдина точка входу для розгортання (Лаб №1)
├── Dockerfile                 — образ застосунку (Лаб №2)
├── docker-entrypoint.sh       — запуск міграції + сервера в контейнері
├── docker-compose.yml         — стек із трьох сервісів (Лаб №2)
├── .dockerignore
└── nginx/
    └── nginx.conf             — конфіг nginx для контейнерного запуску
```

## 9. Запуск через Docker Compose (Лабораторна №2, практична частина)

Альтернатива bare-metal-розгортанню з лаби №1 — повністю контейнерний запуск через Docker Compose. Не потребує `install.sh`, системних користувачів і `systemd` — все ізольовано в контейнерах.

### Передумови

- Docker Engine 20.10+ і Docker Compose v2 (входить у Docker Desktop / пакет `docker-compose-plugin`)
- ~1 ГБ RAM, ~500 МБ диску

### Запуск

```bash
git clone <URL_РЕПОЗИТОРІЮ> mywebapp
cd mywebapp
docker compose up -d --build
```

Перший запуск збере образ застосунку і стягне `mariadb` + `nginx` (~250 МБ сумарно). Подальші старти — за 5–10 сек.

### Архітектура контейнерів

| Сервіс | Образ | Порти | Призначення |
|---|---|---|---|
| `db` | `mariadb:10.11` | (тільки внутрішня мережа) | MariaDB з persistent volume `mywebapp_db_data` |
| `app` | збирається з `./Dockerfile` | (тільки внутрішня мережа, :5200) | веб-застосунок; міграція БД виконується у `docker-entrypoint.sh` перед стартом сервера |
| `nginx` | `nginx:1.27-alpine` | **80:80** | reverse-proxy, єдина точка входу ззовні |

Усе працює в окремій мережі `mywebapp_net` (не default). Дані БД лежать у named volume `mywebapp_db_data` — переживають `docker compose down`, видалення контейнерів, рестарт Docker і перезавантаження хоста.

### Налаштування паролів (опціонально)

```bash
# .env у корені репо
DB_PASSWORD=mySecretPassword
DB_ROOT_PASSWORD=rootSecretPassword
```

Compose автоматично підхопить ці значення (див. `${DB_PASSWORD:-...}` у `docker-compose.yml`).

### Перевірка

```bash
curl -H 'Accept: application/json' http://localhost/
curl -H 'Accept: application/json' http://localhost/items
curl -X POST -d 'name=hammer&quantity=3' http://localhost/items

docker compose ps                  # стан контейнерів
docker compose logs app            # логи застосунку
docker compose logs nginx          # логи nginx
```

### Перевірка persistence БД

```bash
curl -X POST -d 'name=test&quantity=1' http://localhost/items
docker compose down                # контейнери видалені, volume залишився
docker compose up -d
curl -H 'Accept: application/json' http://localhost/items   # → запис на місці
```

### Зупинка / повне очищення

```bash
docker compose down               # зупинити контейнери (volume лишається)
docker compose down -v            # зупинити і ВИДАЛИТИ volume з даними БД
```

## 10. CI/CD (Лабораторна №3)

Конвеєр GitHub Actions автоматизує статичний аналіз, тестування, збірку образу і розгортання на target-вузол через self-hosted runner.

### Архітектура pipeline

```
push в main / PR в main / annotated tag (v*)
    │
    ▼
┌────────┐    ┌────────┐
│  lint  │    │  test  │   (паралельно, на ubuntu-latest)
└───┬────┘    └───┬────┘
    └──────┬──────┘
           ▼
       ┌────────┐                          (тільки push, не PR)
       │ build  │ → ghcr.io з тегами:
       └───┬────┘    main: latest, sha-<hash>
           │         tag : stable, <tag>
           ▼
       (тільки на анотовані теги v*)
       ┌────────┐
       │ deploy │  ← self-hosted runner; ssh на target
       └───┬────┘
           ▼
       ┌────────┐
       │ verify │  ← self-hosted runner; curl-перевірки публічної поверхні
       └────────┘
```

### Що перевіряється

| Job | Інструменти | На що падає |
|---|---|---|
| `lint`   | ESLint, Hadolint, Shellcheck, Yamllint | будь-яка помилка лінтера |
| `test`   | Jest + supertest | хоч один тест fail; покриття < 40% |
| `build`  | docker buildx + GHCR | проблеми збірки/пушу |
| `deploy` | ssh + sudo + systemd | помилка SSH або systemd restart |
| `verify` | curl + python3 (валідація JSON) | сервіс недоступний, або health-ендпоінти видно ззовні, або content negotiation зламана |

### Налаштування репозиторію

Перед першим запуском треба:
1. Додати у `Settings → Secrets and variables → Actions` секрети `TARGET_HOST`, `TARGET_USER`, `TARGET_SSH_KEY` — деталі у [.github/SECRETS.md](.github/SECRETS.md).
2. Увімкнути branch protection на `main` з вимогою passing checks для `Lint` і `Test`.

### Налаштування ВМ

Дві окремі ВМ Ubuntu 24.04:
- **Runner VM** — на ній буде self-hosted runner. Запустити `sudo bash deploy/runner-setup.sh`, далі вручну зареєструвати ранер за інструкцією, яку виведе скрипт.
- **Target VM** — сюди розгортається застосунок. Запустити `sudo bash deploy/target-setup.sh`, відредагувати `/opt/mywebapp/.env` (вписати `GITHUB_REPO=<owner>/<repo>` у lower case), додати публічний ключ ранера у `/home/deploy/.ssh/authorized_keys`.

### Тригери деплою

Тільки **анотовані теги** виду `v*`:

```bash
git tag -a v0.1.0 -m "first release"
git push --tags
```

Це запускає `lint → test → build → deploy → verify`. Якщо будь-який крок впав — наступний не виконується.

### Покриття коду

Jest конфігурація вимагає мінімум 40% покриття (рядки + statements). Артефакт `coverage-report` завантажується на кожному прогоні `test` job-а і доступний у вкладці Actions → конкретний прогін → Artifacts.

### Команди для локального запуску

```bash
cd app
npm install
npm run lint      # ESLint
npm test          # Jest, без coverage
npm run coverage  # Jest з coverage звітом (відкрити coverage/lcov-report/index.html)
```
