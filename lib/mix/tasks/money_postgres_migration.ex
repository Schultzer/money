if Code.ensure_loaded?(Ecto) do
  defmodule Mix.Tasks.Money.Gen.Postgres.Migration do
    use Mix.Task

    import Macro, only: [camelize: 1, underscore: 1]
    import Mix.Generator
    import Mix.Ecto

    @shortdoc "Generates a migration to create the :money_with_currency composite " <>
                "database type for Postgres"

    @moduledoc """
    Generates a migration to add a composite type called `:money_with_currency`
    to a Postgres database.

    The `:money_with_currency` type created is a composite type and
    therefore may not be supported in other databases.
    """

    @doc false
    def run(args) do
      no_umbrella!("money.gen.migration")
      repos = parse_repo(args)
      name = "add_money_with_currency_type_to_postgres"

      Enum.each(repos, fn repo ->
        ensure_repo(repo, args)
        path = Path.relative_to(migration_path(repo), Mix.Project.app_path())
        file = Path.join(path, "#{timestamp()}_#{underscore(name)}.exs")
        create_directory(path)

        assigns = [mod: Module.concat([repo, Migrations, camelize(name)])]

        content =
          assigns
          |> migration_template
          |> Code.format_string!()

        create_file(file, content)

        if open?(file) and Mix.shell().yes?("Do you want to run this migration?") do
          Mix.Task.run("ecto.migrate", [repo])
        end
      end)
    end

    defp migration_path(repo) do
      Path.join(repo_priv(repo), "migrations")
    end

    defp repo_priv(repo) do
      config = repo.config()
      priv = config[:priv] || "priv/#{repo |> Module.split() |> List.last() |> Macro.underscore()}"
      app = Keyword.fetch!(config, :otp_app)
      Path.join(Mix.Project.deps_paths[app] || File.cwd!, priv)
    end

    defp timestamp do
      {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
      "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
    end

    defp pad(i) when i < 10, do: <<?0, ?0 + i>>
    defp pad(i), do: to_string(i)

    embed_template(:migration, """
    defmodule <%= inspect @mod %> do
      use Ecto.Migration

      def up do
        <%= Money.DDL.execute(Money.DDL.create_money_with_currency) %>
      end

      def down do
        <%= Money.DDL.execute(Money.DDL.drop_money_with_currency) %>
      end
    end
    """)
  end
end
