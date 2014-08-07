defmodule Mix.Tasks.Db.Repair do
    
    def run([ver]) do
        ExSouth.init_pool()
        
        ExSouth.drop_south_db()
        ExSouth.install_south_db()
                
        File.ls!("./#{ExSouth.dir}/") 
            |> Enum.sort
            |> Enum.find fn(name)->
                [iver, uname] = String.split(name, "_", parts: 2)
                uname = String.split(uname, ".", parts: 2) |> List.first
                if iver <= ver and iver != "9999" do
                    ExSouth.bump_version_south_db(iver, uname)
                end
            end
    end

    def run(_) do
        ExSouth.init_pool()
        ExSouth.drop_south_db()
        ExSouth.install_south_db()
        ExSouth.bump_version_south_db("0000", "initial")
    end

end


defmodule Mix.Tasks.Db.Install do
  use Mix.Task

  @shortdoc "Устанавливает базу данных"

  @moduledoc """
  A test task.
  """
  def run(_) do
    IO.puts "Installing DB..." 
    ExSouth.init_pool()
    is_ok = "./#{ExSouth.dir}/0000_init.sql" |> File.read! |> SQL.execute 
        |> ExSouth.get_execute_result

    if is_ok do
        ExSouth.install_south_db()
        ExSouth.bump_version_south_db("0000", "initial")
        IO.puts "DB installed."
    else 
        IO.puts "Errors in DB installation."
    end
  end
end


defmodule Mix.Tasks.Db.Update do
  use Mix.Task

  @shortdoc "Обновляет базу данных"

  @moduledoc """
  A test task.
  """
  def run([ver]) do
    filename = File.ls!("./#{ExSouth.dir}/") 
      |> Enum.find &(String.starts_with?(&1, "#{ver}_"))

    case File.exists?("./#{ExSouth.dir}/#{filename}") do
      true when filename != nil -> 
        ExSouth.init_pool()

        cver = ExSouth.get_current_south_db()

        cond do
            cver == nil -> 
                IO.puts "DB doesn't installed..."
            cver >= ver -> 
                IO.puts "Version allready installed..."
            true -> 
                IO.puts "Updating DB up to v.#{ver}..." 

                is_failed = File.ls!("./#{ExSouth.dir}/") 
                    |> Enum.sort
                    |> Enum.any? fn(name)->
                        [iver, uname] = String.split(name, "_", parts: 2)
                        uname = String.split(uname, ".", parts: 2) |> List.first
                        if iver > cver and iver <= ver and iver != "9999" do 
                            is_ok = "./#{ExSouth.dir}/#{name}" |> File.read! |> SQL.execute 
                                |> ExSouth.get_execute_result

                            if is_ok do
                                ExSouth.bump_version_south_db(iver, uname)
                                false
                            else true end
                        else false end
                    end

                if is_failed do 
                    IO.puts "Errors at updating DB..." 
                else 
                    IO.puts "DB is now v.#{ver}" 
                end
        end

      _ -> 
        IO.puts "Version is not found..."

    end
  end

  def run(_) do
    IO.puts "You must provide version number."
  end
end


defmodule Mix.Tasks.Db.Ver do
  use Mix.Task

  @shortdoc "Обновляет базу данных"

  @moduledoc """
  A test task.
  """
  def run(_) do
    ExSouth.init_pool()

    result = ExSouth.get_versions_south_db()

    case result do
        nil -> 
            File.ls!("./#{ExSouth.dir}/") 
                |> Enum.each fn(name)->
                    ver = String.split(name, "_") |> List.first
                    if ver != "9999", do: IO.puts "( ) #{String.split(name, ".") |> List.first}"
                end

        vers -> 
            cver = vers |> 
                Enum.map(fn([{:id, ver}, {:name, name}])-> IO.puts "(*) #{ver}_#{name}"; ver end)
                    |> Enum.reverse |> List.first

            File.ls!("./#{ExSouth.dir}/") 
                |> Enum.each(fn(name)->
                    ver = String.split(name, "_") |> List.first
                    if ver > cver and ver != "9999", do: IO.puts "( ) #{String.split(name, ".") |> List.first}"
                end)
    end
  end
end

defmodule Mix.Tasks.Db.Drop do
  use Mix.Task

  @shortdoc "Удаляет базу данных"

  @moduledoc """
  A test task.
  """
  def run(_) do
    IO.puts "Dropping DB..."
    ExSouth.init_pool()

    "./#{ExSouth.dir}/9999_remove.sql" |> File.read! |> SQL.execute 
        |> ExSouth.get_execute_result

    ExSouth.drop_south_db()
    IO.puts "DB dropped."
  end

end