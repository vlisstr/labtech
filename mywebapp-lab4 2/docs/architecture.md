# Архітектура

## Загальна схема

```
                ┌─────────── vm-worker ───────────┐    ┌── vm-db ──┐
client ─:80──► │ nginx ──:5200──► mywebapp (Node) │──► │ MariaDB   │
                │   (reverse proxy)  (Express)    │    │  :3306    │
                └─────────────────────────────────┘    └───────────┘
                       │   ▲                                  ▲
                       │   │   доступні зовні                 │
                       │   ╰── тільки 80 (nginx)              │
                       │                                       │
                       ╰─ /health/alive, /health/ready         │
                          доступні лише з самого worker        │
                                                               │
                          UFW на vm-db дозволяє :3306 ─────────╯
                          ТІЛЬКИ з IP vm-worker
```

## Мережеві обмеження

| Компонент | Bind | Доступний |
|---|---|---|
| nginx          | `0.0.0.0:80`        | усі |
| mywebapp       | `127.0.0.1:5200`    | тільки локально на vm-worker (через nginx) |
| MariaDB        | `<vm-db-ip>:3306`   | UFW відкриває порт лише для IP vm-worker |
| SSH (sshd)     | `0.0.0.0:22`        | усі (для адміністрування ansible/teacher) |

## Як IP-адреси потрапляють у конфіги

1. Libvirt DHCP видає адреси з мережі `default` (за замовч. 192.168.122.0/24) для обох ВМ
2. Terraform читає ці IP з `libvirt_domain.*.network_interface[0].addresses[0]` та підставляє у згенерований `ansible/inventory.ini`
3. Ansible під час `gather_facts` дізнається `ansible_default_ipv4.address` кожного хосту
4. У `group_vars/workers.yml` змінна `db_host` обчислюється як `hostvars[groups['db'][0]].ansible_default_ipv4.address` — тобто реальний IP vm-db
5. Шаблон `mywebapp.service.j2` підставляє цей IP у CLI-аргумент `--db-host`, шаблон `99-mywebapp.cnf.j2` (на vm-db) — у `bind-address`
6. UFW-правило на vm-db використовує IP vm-worker (`hostvars[groups['workers'][0]].ansible_default_ipv4.address`)

## Декларативність

Усі задачі написані через стандартні модулі: `apt`, `user`, `template`, `copy`, `systemd`, `ufw`, `mysql_db`, `mysql_user`, `npm`, `file`. `ansible.builtin.command` використовується лише для запуску `migrate.js` (немає стандартного модуля для виклику довільного скрипта) з явним `changed_when: false`.

## Ідемпотентність

- `apt` — ставить пакет лише якщо його ще немає
- `user`, `template`, `copy`, `file` — порівнюють бажаний стан з фактичним
- `systemd` — змінює стан лише якщо потрібно
- `ufw` — порівнює правила з заявленими
- `mysql_db`, `mysql_user` — CREATE IF NOT EXISTS під капотом
- `command` для migrate.js — `changed_when: false`, скрипт сам ідемпотентний

Повторний запуск playbook → `changed=0` (типовий результат).

## Обмеження безпеки

- Пароль `12345678` для teacher і operator — за вимогою завдання, дефолт; у реальному житті — ansible-vault або env
- `db_password` зараз у відкритому вигляді у `group_vars/all.yml` — теж demo; у проді — ansible-vault
- UFW з default deny — мережево захищає тільки те, що явно дозволено
- App user — system, nologin, мінімальні права; systemd unit має `NoNewPrivileges`, `ProtectSystem=full`, `ProtectHome`, `PrivateTmp`
