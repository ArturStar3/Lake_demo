# InfoLake (демо)

Один контейнер: PostgreSQL, Django, TileServer GL, Nginx.
Карта, media и база монтируются с хоста.

## Env

Скопируйте шаблон и правьте только `.env.demo`. Его не коммитить.

```powershell
Copy-Item .\.env.demo.example .\.env.demo
```

Правила оформления:

- одна строка — `КЛЮЧ=значение`, без пробелов вокруг `=`
- значения `CHANGE_ME_*` заменить своими
- пути только абсолютные, на Windows со слэшем `/`: `D:/InfoLakeDemo/maps/map.mbtiles`
- кавычки не ставить
- списки через запятую без пробелов: `localhost,127.0.0.1,infolake-demo`
- origins со схемой и портом: `http://localhost:8080`
- `IS_EMPTY_DB=1` только на один старт с restore из `DB_DUMP_PATH`, потом `0`

Compose читает файл только так: `--env-file .env.demo`. Команды без этого флага не запускать. `restart` новые значения не подхватывает — нужен `--force-recreate`.

## Запуск

Файл `map.mbtiles` и каталог media должны существовать по путям из env.

```powershell
docker network create infolake-integration
docker compose -p infolake-demo --env-file .env.demo up -d --build
```

Офлайн, без сборки:

```powershell
.\export-offline-demo.ps1
.\import-and-start-demo.ps1 -Archive .\infolake_demo_offline.tar
```

Интерфейс: http://localhost:8080/  
Админка: http://localhost:8080/admin/

После правки env:

```powershell
docker compose -p infolake-demo --env-file .env.demo up -d --no-build --pull never --force-recreate
```

Не выполнять `docker compose down -v` — удалится база.
