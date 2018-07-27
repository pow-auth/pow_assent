Mix.shell(Mix.Shell.Process)
Logger.configure(level: :warn)

ExUnit.start()

Mix.Task.run "ecto.drop", ~w(--quiet -r PowAssent.Test.Ecto.Repo)
Mix.Task.run "ecto.create", ~w(--quiet -r PowAssent.Test.Ecto.Repo)
Mix.Task.run "ecto.migrate", ~w(--quiet -r PowAssent.Test.Ecto.Repo)

{:ok, _pid} = PowAssent.Test.Ecto.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(PowAssent.Test.Ecto.Repo, :manual)

{:ok, _pid} = PowAssent.Test.Phoenix.Endpoint.start_link()
