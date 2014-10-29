defmodule ExSouth do

  @timeout 12000000

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

        def execute(cmd, args \\ [], project) do
            try do
                case args do
                    [] -> :emysql.execute(project, cmd, @timeout) 
                    args -> :emysql.execute(project, cmd, args, @timeout) 
                end
                |> get_execute_result
            catch
                :exit, _ -> 
                    IO.puts "[ERROR] Init migration DB firstly"
                    :error
            end
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

        def get_execute_result(list) when is_list(list) do
            Enum.map(list, &get_execute_result/1)
        end
        def get_execute_result({:result_packet, _, fields, data, _}) do
            fields = get_field(fields) 
            Enum.map(data, fn(list)->
                Enum.zip(fields, list) |> Enum.into(%{})
            end)
        end
        def get_execute_result({:ok_packet, _,_,_,_,_,_}), do: :ok
        def get_execute_result({:error_packet, _, _, _, message}) do 
            IO.puts "#{message}"
            :error
        end

        def execute_ok?(list) when is_list(list) do
            Enum.all? list, &execute_ok?/1
        end
        def execute_ok?(:error), do: false
        def execute_ok?(_), do: true

        def get_field(list) when is_list(list), do: Enum.map(list, &get_field/1)
        def get_field({:field, _, _, _, _, _, name, _, _, _, _, _, _, _, _}) do
            name
        end

        def install_south_db(project) do
            execute("CREATE TABLE IF NOT EXISTS #{table_name(project)} 
                (id VARCHAR(4), project VARCHAR(255), name VARCHAR(255), PRIMARY KEY(project, id)) ENGINE=InnoDB", [], project)
        end

        def bump_version_south_db(project, ver, name) do
            execute("INSERT #{table_name(project)} (id,project,name) VALUES (?,?,?);", [ver, Atom.to_string(project), name], project)
        end

        def get_current_south_db(project) do
          res = execute("SELECT id FROM #{table_name(project)} WHERE project=? ORDER BY id DESC LIMIT 1", [Atom.to_string(project)], project)
          case execute_ok?(res) do
            true -> 
                [%{"id" => ver}] = res
                ver
            false -> nil
          end
      end

      def get_versions_south_db(project) do
          res = execute("SELECT id,name FROM #{table_name(project)} WHERE project=? ORDER BY id ASC", [Atom.to_string(project)], project)
          case execute_ok?(res) do
            true -> res
            false -> nil
          end
      end

      def drop_south_db(project) do
          execute("DELETE FROM #{table_name(project)} WHERE project=?;", [project], project)
      end
 
      def drop_south_db(project, :all) do
          execute("DROP TABLE IF EXISTS #{table_name(project)}", [], project)
      end

 end