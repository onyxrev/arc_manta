defmodule Arc.Storage.Manta do
  @signature_algorithm "rsa-sha256"
  @authorization_header_strftime_format "%a, %d %b %Y %H:%M:%S GMT"
  @directory_content_type_header "application/json; type=directory"

  @default_expiry_time 60*5
  @default_mimetype "application/octet-stream"
  @default_host "us-east.manta.joyent.com"

  # wait up to 30 seconds, which is pretty arbitrary
  @httpoison_options [recv_timeout: 30000]

  def put(definition, version, {file, scope}) do
    path = definition_to_path(definition, version, {file, scope})
    mkdir_p(path)

    :ok = store_file(
      fully_qualified_url(path),
      extract_binary(file),
      [{"Content-Type", "#{get_mimetype(file)}; type=file"} | base_headers]
    )

    {:ok, file.file_name}
  end

  def delete(definition, version, {file, scope}) do
    path = definition_to_url(definition, version, {file, scope})

    case delete_file(path) do
      :ok -> :ok
      {:error, "{\"code\":\"ResourceNotFound\"" <> _} -> :ok
    end
  end

  def url(definition, version, file_and_scope, options \\ []) do
    case Keyword.get(options, :signed, false) do
      false -> build_url(definition, version, file_and_scope, options)
      true  -> build_signed_url(definition, version, file_and_scope, options)
    end
  end

  #
  # Private
  #

  defp store_file(fully_qualified_url, data, headers) do
    HTTPoison.start

    HTTPoison.put!(fully_qualified_url, data, headers, @httpoison_options)
    |> httpoison_response_to_status
  end

  defp delete_file(fully_qualified_url) do
    HTTPoison.start

    HTTPoison.delete!(fully_qualified_url, base_headers)
    |> httpoison_response_to_status
  end

  defp mkdir_p(path) do
    path
    |> Path.split
    |> Enum.reduce(fn(segment, partial_path) ->
      :ok = partial_path
      |> List.wrap
      |> mkdir

      List.wrap(partial_path) ++ List.wrap(segment)
    end)
  end

  defp mkdir(path) do
    fully_qualified_url(path)
    |> HTTPoison.put!("", [{"Content-Type", @directory_content_type_header} | base_headers])
    |> httpoison_response_to_status
  end

  defp httpoison_response_to_status(%HTTPoison.Response{status_code: 204}), do: :ok
  defp httpoison_response_to_status(%HTTPoison.Response{body: body}), do: {:error, body}

  defp definition_to_path(definition, version, {file, scope}) do
    destination_dir = definition.storage_dir(version, {file, scope})
    Path.join(destination_dir, file.file_name)
  end

  defp definition_to_url(definition, version, {file, scope}) do
    definition_to_path(definition, version, {file, scope})
    |> fully_qualified_url
  end

  defp fully_qualified_url(path) when is_list(path) do
    fully_qualified_url(Path.join(path))
  end

  defp fully_qualified_url(path) when is_binary(path) do
    "https://#{manta_host}/#{manta_user}/public/#{path}"
  end

  def base_headers do
    now = :calendar.universal_time()
    |> Calendar.Strftime.strftime!(@authorization_header_strftime_format)

    [{"Authorization", authorization_header(now)}, {"date", now}]
  end

  defp authorization_header(now) do
    'Signature keyId="#{manta_key_id}",algorithm="#{@signature_algorithm}",signature="#{sign_date("date: #{now}")}"'
  end

  defp sign_date(now) do
    key = manta_ssh_private_key
    |> :public_key.pem_decode
    |> List.first
    |> :public_key.pem_entry_decode

    now
    |> :public_key.sign(:sha256, key)
    |> Base.encode64
  end

  defp get_file_extension(file) do
    file.file_name
    |> String.split(".")
    |> List.last
  end

  defp get_mimetype(file) do
    :mimerl.extension(get_file_extension(file)) || @default_mimetype
  end

  defp build_url(definition, version, file_and_scope, _options) do
    manta_key(definition, version, file_and_scope)
    |> fully_qualified_url
  end

  # TODO
  defp build_signed_url(_definition, _version, _file_and_scope, _options) do
  end

  defp manta_key(definition, version, file_and_scope) do
    Path.join([
      definition.storage_dir(version, file_and_scope),
      Arc.Definition.Versioning.resolve_file_name(definition, version, file_and_scope)
    ])
  end

  defp extract_binary(file) do
    Map.get(file, :binary) || File.read!(file.path)
  end

  defp manta_ssh_fingerprint do
    Application.get_env :arc, :manta_ssh_fingerprint
  end

  defp manta_host do
    Application.get_env(:arc, :manta_host) || @default_host
  end

  defp manta_user do
    Application.get_env :arc, :manta_user
  end

  defp manta_ssh_private_key do
    Application.get_env :arc, :manta_ssh_private_key
  end

  defp manta_key_id do
    "/#{manta_user}/keys/#{manta_ssh_fingerprint}"
  end
end
