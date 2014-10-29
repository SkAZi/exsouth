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

        def user_input(question, opts) do
            ret = IO.gets "#{question} [#{Keyword.keys(Keyword.delete(opts, :default)) |> Enum.join(", ")}]: "

            ret = try do
                String.to_existing_atom(ret |> String.downcase |> String.rstrip(?\n))
            rescue
                _e in ArgumentError -> :default
            end

            case opts[ret] do
                nil -> 
                    IO.puts "Hm, what?"
                    user_input(question, opts)
                answer -> answer
            end
        end

        def project_from_name(name) when is_atom(name), do: name
        def project_from_name(name) do
            try do
                String.to_existing_atom(name)
            rescue
                _e in ArgumentError ->
                    raise "No ExSouth settings for project #{name} found"
            end
        end

        def get_settings(project) do
            Application.get_all_env(:exsouth)
            |> Keyword.get(project, nil)
        end

        def get_all_projects() do
            Application.get_all_env(:exsouth)
            |> Keyword.delete(:included_applications)
            |> Keyword.keys
        end

        def init_pool(project) do
            settings = get_settings(project)
            case settings do
                nil -> raise "No ExSouth settings for project #{project} found"
                settings ->
                    :ok = ExSouth.astart(:emysql)
                    mysql = Keyword.get(settings, :mysql, :mysql)
                    mysql_settings = Keyword.put(Application.get_env(project, mysql, []), :pool, project)
                    SQL.init_pool Keyword.put(mysql_settings, :connect_timeout, :timer.seconds(120))
            end
        end

        def execute(cmd, project) do
            SQL.execute(cmd, [], project) |> ExSouth.get_execute_result
        end

        def dir(project) do
            settings = get_settings(project)
            case settings do
                nil -> raise "No ExSouth settings for project #{project} found"
                settings ->
                    Keyword.get(settings, :dir, "#{:code.priv_dir project}/database")
            end
        end

        def table_name(project) do
            settings = get_settings(project)
            case settings do
                nil -> raise "No ExSouth settings for project #{project} found"
                settings ->
                    Keyword.get(settings, :table_name, "exsouth_versions")
            end
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

        def install_south_db(project) do
            SQL.execute("CREATE TABLE IF NOT EXISTS #{table_name(project)} 
                (id VARCHAR(4), project VARCHAR(255), name VARCHAR(255), PRIMARY KEY(project, id)) ENGINE=InnoDB", [], project)
        end

        def bump_version_south_db(project, ver, name) do
            SQL.execute("INSERT #{table_name(project)} (id,project,name) VALUES (?,?,?);", [ver, Atom.to_string(project), name], project)
        end

        def get_current_south_db(project) do
          case SQL.run("SELECT id FROM #{table_name(project)} WHERE project=? ORDER BY id DESC LIMIT 1", [Atom.to_string(project)], project) do
              {:error, _} -> nil
              [] -> ""
              [[{:id, ver}]] -> ver
          end
      end

      def get_versions_south_db(project) do
          case SQL.run("SELECT id,name FROM #{table_name(project)} WHERE project=? ORDER BY id ASC", [Atom.to_string(project)], project) do
              {:error, _} -> nil
              [] -> nil
              list -> list
          end
      end

      def drop_south_db() do
          SQL.execute("DROP TABLE IF EXISTS #{table_name(project)}", [], project)
      end
 
       def drop_south_db(project) do
          SQL.execute("DELETE FROM #{table_name(project)} WHERE project=?;", [], project)
      end
 end