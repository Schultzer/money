if Code.ensure_loaded?(Ecto) do
  defmodule Mix.Tasks.Money.Gen.Postgres.AggregateFunctions do
    use Mix.Task

    import Mix.Generator
    import Mix.Ecto
    import Macro, only: [camelize: 1, underscore: 1]

    @shortdoc "Generates a migration to create aggregate types for money_with_currency"

    @moduledoc """
    Generates a migration to add a aggregation functions
    to Postgres for the `money_with_currency` type

    This release includes only the `sum` aggregattion
    function.
    """

    @doc false
    def run(args) do
      no_umbrella!("money.gen.postgres.aggregate_functions")
      repos = parse_repo(args)
      name = "add_postgres_money_aggregate_functions"

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
        <%= Money.DDL.execute_each(Money.DDL.define_aggregate_functions) %>
      end

      def down do
        <%= Money.DDL.execute_each(Money.DDL.drop_aggregate_functions) %>
      end
    end
    """)
  end
end
