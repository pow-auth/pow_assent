Logger.configure(level: :warning)

ExUnit.start()

# Ensure that symlink to custom ecto priv directory exists
source = PowAssent.Test.Ecto.Repo.config()[:priv]
target = Application.app_dir(:pow, source)
File.rm_rf(target)
File.mkdir_p(target)
File.rmdir(target)
:ok = :file.make_symlink(Path.expand(source), target)

Mix.Task.run("ecto.drop", ~w(--quiet -r PowAssent.Test.Ecto.Repo))
Mix.Task.run("ecto.create", ~w(--quiet -r PowAssent.Test.Ecto.Repo))
Mix.Task.run("ecto.migrate", ~w(--quiet -r PowAssent.Test.Ecto.Repo))

{:ok, _pid} = PowAssent.Test.Ecto.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(PowAssent.Test.Ecto.Repo, :manual)

{:ok, _pid} = PowAssent.Test.Phoenix.Endpoint.start_link()
{:ok, _pid} = PowAssent.Test.EmailConfirmation.Phoenix.Endpoint.start_link()
{:ok, _pid} = PowAssent.Test.Invitation.Phoenix.Endpoint.start_link()
{:ok, _pid} = PowAssent.Test.NoRegistration.Phoenix.Endpoint.start_link()
{:ok, _pid} = PowAssent.Test.Reauthorization.Phoenix.Endpoint.start_link()
{:ok, _pid} = PowAssent.Test.WithCustomChangeset.Phoenix.Endpoint.start_link()
