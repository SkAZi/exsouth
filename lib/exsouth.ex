defmodule ExSouth do
  def astart(name) when is_atom name do
    case Application.start(name) do
        :ok -> :ok
        {:error, {:not_started, need_name}} -> 
            astart(need_name)
            astart(name)
        {:error, {:already_started, _}} -> :ok
        {:error, error} -> 
            throw error
    end
  end

  def init_pool() do
    :ok = ExSouth.astart(:emysql)
    project = Application.get_env :exsouth, :project
    mysql = Application.get_env :exsouth, :mysql, :mysql
    SQL.init_pool Application.get_env project, mysql, []
  end

  def dir() do
    Application.get_env :exsouth, :dir, "database"
  end

  def get_execute_result({:ok_packet, _,_,_,_,_,_}), do: true
  def get_execute_result({:error_packet, _, _, _, message}) do 
    IO.puts "#{message}"
    false
  end

  def get_execute_result(list) do
    Enum.all? list, 
        fn({:ok_packet, _,_,_,_,_,_}) -> true;
          ({:error_packet, _, _, _, message}) -> 
            IO.puts "#{message}" 
            false
        end    
  end

  def install_south_db() do
        SQL.query("CREATE TABLE IF NOT EXISTS update_versions 
            (id VARCHAR(4) PRIMARY KEY, name VARCHAR(255)) ENGINE=InnoDB", [])
            |> SQL.execute
  end

  def bump_version_south_db(ver, name) do
        SQL.query("INSERT update_versions (id,name) VALUES (?,?);", [ver, name])
            |> SQL.execute
  end

  def get_current_south_db() do
      case SQL.run("SELECT id FROM update_versions ORDER BY id DESC LIMIT 1", []) do
          {:error, _} -> nil
          [] -> ""
          [[{:id, ver}]] -> ver
      end
  end

  def get_versions_south_db() do
      case SQL.run("SELECT id,name FROM update_versions ORDER BY id ASC", []) do
          {:error, _} -> nil
          [] -> nil
          list -> list
      end
  end

  def drop_south_db() do
      SQL.execute("DROP TABLE IF EXISTS update_versions")
  end
end