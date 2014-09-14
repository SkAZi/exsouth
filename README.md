ExSouth
=======

### MySQL DB migration tool for Elixir.

Settings:

```
config :exsouth,
    app_name: [mysql: :mysql, dir: "database", table_name: "exsouth_versions"]

config :app_name,
    mysql: [size: 10, host: 'localhost', db: 'database', user: 'root']
```

Commands:

```
mix db.install [project|all]
mix db.repair  [project|all] [ver]
mix db.ver     [project|all]
mix db.drop    [project|all]
mix db.update  [project|all] ver
```