defmodule Mix.Tasks.Db.Repair do
    use Mix.Task
    @shortdoc "Устанавливает версию базы дынных без внесения изменений"

    def run(["all", ver]) do
        ExSouth.get_all_projects() 
        |> Enum.each fn(project)->
            run([project, ver])
        end
    end

    def run([project, ver]) do
        IO.puts "Repairing #{project} to #{ver}..."
        project = ExSouth.project_from_name(project)

        ExSouth.init_pool(project)
        
        ExSouth.drop_south_db(project)
        ExSouth.install_south_db(project)

        File.ls!("./#{ExSouth.dir(project)}/") 
            |> Enum.sort
            |> Enum.each fn(name)->
                [iver, uname] = String.split(name, "_", parts: 2)
                uname = String.split(uname, ".", parts: 2) |> List.first
                if iver <= ver and iver != "9999" do
                    ExSouth.bump_version_south_db(project, iver, uname)
                end
            end
    end

    def run([arg]) do
        operation = try do
            _ = String.to_integer(arg)
            :ver
        rescue
            _e in ArgumentError -> :project
        end

        case operation do
            :project -> 
                IO.put "Repairing #{arg} to 0000..."
                project = ExSouth.project_from_name(arg)
                ExSouth.init_pool(project)
                ExSouth.drop_south_db(project)
                ExSouth.install_south_db(project)
                ExSouth.bump_version_south_db(project, "0000", "initial")

            :ver -> 
                case ExSouth.user_input("Do you wish to repair all projects to version #{arg}?", [yes: :yes, no: :no, default: :no]) do
                    :no -> nil
                    :yes -> run(["all", arg])
                end
        end
    end

    def run(_) do
        case ExSouth.user_input("Do you wish to repair every project to version 0000?", [yes: :yes, no: :no, default: :no]) do
            :no -> nil
            :yes -> run(["all", "0000"])
        end
    end
end


defmodule Mix.Tasks.Db.Install do
    use Mix.Task

    @shortdoc "Устанавливает базу данных"

    def run(["all"]) do
        ExSouth.get_all_projects() 
        |> Enum.each fn(project)->
            run([project])
        end
    end

    def run([project]) do
        project = ExSouth.project_from_name(project)

        IO.puts "Installing DB for #{project}..." 
        ExSouth.init_pool(project)
        is_ok = "./#{ExSouth.dir(project)}/0000_init.sql" 
        |> File.read! 
        |> ExSouth.execute(project)
        

        if is_ok do
            ExSouth.install_south_db(project)
            ExSouth.bump_version_south_db(project, "0000", "initial")
            IO.puts "DB for project #{project} installed."
        else 
            IO.puts "Errors in DB installation for project #{project}."
        end
    end

    def run(_) do
        case ExSouth.user_input("Do you wish to install DB for every project?", [yes: :yes, no: :no, default: :no]) do
            :no -> nil
            :yes -> run(["all"])
        end
    end

end


defmodule Mix.Tasks.Db.Update do
    use Mix.Task

    @shortdoc "Обновляет базу данных"

    def run(["all"]), do: run([])

    def run(["all", ver]) do
        ExSouth.get_all_projects() 
        |> Enum.each fn(project)->
            run([project, ver])
        end
    end

    def run([project, ver]) do
        filename = File.ls!("./#{ExSouth.dir(project)}/") 
            |> Enum.find &(String.starts_with?(&1, "#{ver}_"))

        case File.exists?("./#{ExSouth.dir(project)}/#{filename}") do
            true when filename != nil -> 
                ExSouth.init_pool(project)

                cver = ExSouth.get_current_south_db(project)

                cond do
                    cver == nil -> 
                        IO.puts "DB for project #{project} doesn't installed..."

                    cver >= ver -> 
                        IO.puts "Version for project #{project} allready installed..."

                    true -> 
                        IO.puts "Updating DB for project #{project} up to v.#{ver}..." 

                        is_failed = File.ls!("./#{ExSouth.dir(project)}/") 
                            |> Enum.sort
                            |> Enum.any? fn(name)->
                                [iver, uname] = String.split(name, "_", parts: 2)
                                uname = String.split(uname, ".", parts: 2) |> List.first
                                
                                if iver > cver and iver <= ver and iver != "9999" do 
                                    is_ok = "./#{ExSouth.dir(project)}/#{name}" 
                                    |> File.read! 
                                    |> ExSouth.execute(project)

                                    if is_ok do
                                        ExSouth.bump_version_south_db(project, iver, uname)
                                        false
                                    else true end
                                else false end
                            end

                        if is_failed do 
                            IO.puts "Errors at updating DB for project #{project}..." 
                        else 
                            IO.puts "DB for project #{project} is now v.#{ver}" 
                        end
                end

            false -> 
                IO.puts "Version for project #{project} is not found..."

        end
    end

    def run([ver]) do
        case ExSouth.user_input("Do you wish to update DB for every project to v.#{ver}?", [yes: :yes, no: :no, default: :no]) do
            :no -> nil
            :yes -> run(["all", ver])
        end        
    end

    def run(_) do
        IO.puts "You must provide project and version number."
    end
end


defmodule Mix.Tasks.Db.Ver do
    use Mix.Task

    @shortdoc "Выводит состояние базы данных"

    def run(["all"]), do: run([])

    def run([project]) do
        IO.puts "DB for project #{project}..."

        ExSouth.init_pool(project)
        result = ExSouth.get_versions_south_db(project)

        case result do
            nil -> 
                File.ls!("./#{ExSouth.dir(project)}/") 
                |> Enum.each fn(name)->
                    ver = String.split(name, "_") |> List.first
                    if ver != "9999", do: IO.puts "( ) #{String.split(name, ".") |> List.first}"
                end

            vers -> 
                cver = vers |> 
                Enum.map(fn([{:id, ver}, {:name, name}])-> IO.puts "(*) #{ver}_#{name}"; ver end)
                |> Enum.reverse |> List.first

                File.ls!("./#{ExSouth.dir(project)}/") 
                |> Enum.each(fn(name)->
                    ver = String.split(name, "_") |> List.first
                    if ver > cver and ver != "9999", do: IO.puts "( ) #{String.split(name, ".") |> List.first}"
                end)
        end
    end

    def run(_) do
        ExSouth.get_all_projects() 
        |> Enum.each fn(project)->
            run([project])
        end
    end
end



defmodule Mix.Tasks.Db.Drop do
    use Mix.Task

    @shortdoc "Удаляет базу данных"

    def run("all"), do: run([])

    def run([project]) do
        project = ExSouth.project_from_name(project)

        IO.puts "Dropping DB for project #{project}..."
        ExSouth.init_pool(project)

        "./#{ExSouth.dir(project)}/9999_remove.sql" 
            |> File.read! 
            |> ExSouth.execute(project)

        ExSouth.drop_south_db(project)
        IO.puts "DB for project #{project} dropped."
    end

    def run(_) do
        case ExSouth.user_input("Do you wish to drop DB for every project?", [yes: :yes, no: :no, default: :no]) do
            :no -> nil
            :yes ->
                ExSouth.get_all_projects() 
                |> Enum.each fn(project)->
                    run([project])
                end
        end
    end

end