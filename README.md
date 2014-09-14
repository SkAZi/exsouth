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
mix db.install [project]
mix db.repair  [project] [ver]
mix db.ver     [project]
mix db.drop    [project]
mix db.update  [project] ver
```