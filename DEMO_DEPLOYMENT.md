# Демонстрационная поставка

Поставка запускается одним контейнером `demo`. В нём находятся PostgreSQL 17,
Django/Gunicorn, TileServer GL и Nginx. В образ не входят карта, media и база:
они переживают обновление образа.

Инструкция ниже является единственной инструкцией запуска и обслуживания
демонстрационной поставки.

## Сборка и запуск

1. Скопируйте `.env.demo.example` в `.env.demo`, задайте секреты и абсолютные
   пути к `map.mbtiles` и к каталогу `media`. Для первого показа с пустой БД
   поставьте `DEMO_SEED=1`, затем после наполнения верните `DEMO_SEED=0`.
2. Один раз создайте сеть для интеграций:

   ```powershell
   docker network create infolake-integration
   ```

3. Соберите и запустите. Compose обязан читать `.env.demo` явно:

   ```powershell
   docker compose -p infolake-demo --env-file .env.demo config --quiet
   docker compose -p infolake-demo --env-file .env.demo up -d --build
   ```

Интерфейс доступен на `http://localhost:8080/`, админ-панель — на
`http://localhost:8080/admin/`. Браузер автоматически получает ограниченную
демонстрационную сессию: формы входа и пароль для показа не используются.
Администратор входит в `/admin/` своей учётной записью из базы.

В `/admin/` откройте «Сценарии демонстрации» и в блоке «Автозапуск
демонстрации» включите «Запускать демонстрацию по умолчанию». То же действие
доступно прямо из списка сценариев. Отмеченный сценарий стартует автоматически
при открытии главной страницы; при назначении нового предыдущий снимается.
Выбор хранится в PostgreSQL, поэтому сохраняется при перезапуске и смене
образа.

## Восстановление рабочей базы

### Автоматическое восстановление при старте

Укажите путь к custom-дампу PostgreSQL (`pg_dump -Fc`) в `DB_DUMP_PATH` и
установите `IS_EMPTY_DB=1` в `.env.demo`. При следующем запуске контейнер:

1. завершит подключения к текущей demo-БД;
2. удалит только `DB_NAME` (volume PostgreSQL и другие БД не удаляются);
3. создаст `DB_NAME` заново с UTF-8 и `C.UTF-8`;
4. восстановит содержимое из `DB_DUMP_PATH` командой `pg_restore`;
5. применит миграции и запустит демонстрацию.

После успешного запуска сразу верните `IS_EMPTY_DB=0`, иначе база будет
перезаписываться из дампа при каждом последующем перезапуске контейнера.
Файл дампа монтируется в контейнер только для чтения.

Перед restore установите `DEMO_MAINTENANCE=1` в `.env.demo` и перезапустите
контейнер. В этом режиме работает только PostgreSQL: приложение, миграции и
seed-команды не запускаются.

```powershell
docker compose -p infolake-demo --env-file .env.demo up -d --no-build --pull never --force-recreate
dropdb -h 127.0.0.1 -p 55432 -U postgres -W --maintenance-db=postgres --if-exists --force infolake_demo
createdb -h 127.0.0.1 -p 55432 -U postgres -W -O infolake -T template0 --encoding=UTF8 --locale=C.UTF-8 infolake_demo
pg_restore -h 127.0.0.1 -p 55432 -U infolake -W -d infolake_demo --no-owner --no-acl --exit-on-error --single-transaction D:/InfoLakeDemo/backups/working.dump
```

Сначала выполните такой restore в отдельную тестовую БД. Не используйте
`docker compose down -v`, `flush` или удаление PGDATA: это удалит данные
демонстрации. После успешного восстановления переключите
`DEMO_MAINTENANCE=0` и выполните
`docker compose -p infolake-demo --env-file .env.demo up -d --no-build --pull never --force-recreate`.

Порт PostgreSQL опубликован только на loopback (`127.0.0.1:55432`) специально
для `pg_restore` с хоста. Docker показывает такое соединение как адрес шлюза
сети (например `172.18.0.1`); entrypoint разрешает его через `pg_hba.conf` с
аутентификацией SCRAM, не `trust`.

## Офлайн-передача

На машине для сборки выполните `./export-offline-demo.ps1`; на целевой —
`./import-and-start-demo.ps1 -Archive <путь-к-tar>`. Эти команды не выполняют
сборку или загрузку образов на целевой машине.
