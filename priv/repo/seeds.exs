# Script for populating the database.
#
# Run with:
#   mix run priv/repo/seeds.exs

alias AgentJido.Accounts
alias AgentJido.Accounts.User
alias AgentJido.Analytics.Ingestion
alias AgentJido.Repo

normalize_env = fn
  value when is_binary(value) ->
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end

  _other ->
    nil
end

%{inserted_or_updated: repository_count, errors: repository_errors} = Ingestion.sync_repositories_from_ecosystem()
%{inserted_or_updated: hex_package_count, errors: hex_package_errors} = Ingestion.sync_hex_packages_from_ecosystem()

if repository_errors == [] do
  IO.puts("Seeded #{repository_count} analytics tracked repositories.")
else
  raise """
  Failed to seed #{length(repository_errors)} analytics tracked repositories.
  #{inspect(repository_errors)}
  """
end

if hex_package_errors == [] do
  IO.puts("Seeded #{hex_package_count} analytics tracked Hex packages.")
else
  raise """
  Failed to seed #{length(hex_package_errors)} analytics tracked Hex packages.
  #{inspect(hex_package_errors)}
  """
end

maybe_confirm_user = fn user ->
  if user.confirmed_at do
    {:ok, user}
  else
    user
    |> User.confirm_changeset()
    |> Repo.update()
  end
end

ensure_admin = fn user ->
  if Accounts.admin?(user), do: {:ok, user}, else: Accounts.promote_user_to_admin(user)
end

admin_email = normalize_env.(System.get_env("ADMIN_EMAIL"))
admin_password = normalize_env.(System.get_env("ADMIN_PASSWORD"))

case admin_email do
  nil ->
    IO.puts("""
    Skipping admin account seed because ADMIN_EMAIL is not set.

    Bootstrap an admin account locally:
      ADMIN_EMAIL=you@example.com ADMIN_PASSWORD='at-least-12-chars' mix run priv/repo/seeds.exs

    ADMIN_PASSWORD is optional. Without it, request a magic link at /users/log-in and open /dev/mailbox.
    """)

  email ->
    user =
      case Accounts.get_user_by_email(email) do
        nil ->
          {:ok, created_user} = Accounts.register_user(%{email: email})
          IO.puts("Created user: #{email}")
          created_user

        existing_user ->
          IO.puts("Using existing user: #{email}")
          existing_user
      end

    {:ok, user} = ensure_admin.(user)
    {:ok, user} = maybe_confirm_user.(user)

    case admin_password do
      nil ->
        IO.puts("Seeded admin user: #{email} (magic-link login enabled; no password set).")

      password ->
        case Accounts.update_user_password(user, %{password: password}) do
          {:ok, {_updated_user, _expired_tokens}} ->
            IO.puts("Seeded admin user: #{email} (password login enabled).")

          {:error, changeset} ->
            raise """
            Failed to set ADMIN_PASSWORD for #{email}.
            #{inspect(changeset.errors)}
            """
        end
    end
end
