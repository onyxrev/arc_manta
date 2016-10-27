defmodule ArcTest.Storage.Manta do
  use ExUnit.Case, async: false
  @img "test/support/image.png"

  defmodule DummyDefinition do
    use Arc.Definition

    def __storage, do: Arc.Storage.Manta

    def storage_dir(_, _), do: "arctest/uploads"
  end

  defmodule DefinitionWithThumbnail do
    use Arc.Definition
    @versions [:thumb]

    def __storage, do: Arc.Storage.Manta

    def transform(:thumb, _) do
      {"convert", "-strip -thumbnail 100x100^ -gravity center -extent 100x100 -format jpg", :jpg}
    end
  end

  defmodule DefinitionWithScope do
    use Arc.Definition

    def __storage, do: Arc.Storage.Manta

    def storage_dir(_, {_, scope}), do: "uploads/with_scopes/#{scope.id}"
  end

  def manta_user do
    System.get_env("ARC_TEST_MANTA_USER")
  end

  defmacro delete_and_assert_not_found(definition, args) do
    quote bind_quoted: [definition: definition, args: args] do
      :ok = definition.delete(args)
      url = DummyDefinition.url(args)
      {:ok, {{_, code, msg}, _, _}} = :httpc.request(to_char_list(url))
      assert 404 == code
      assert 'Not Found' == msg
    end
  end

  defmacro assert_header(definition, args, header, value) do
    quote bind_quoted: [definition: definition, args: args, header: header, value: value] do
      url = definition.url(args)
      {:ok, {{_, 200, 'OK'}, headers, _}} = :httpc.request(to_char_list(url))

      char_header = to_char_list(header)

      assert to_char_list(value) == Enum.find_value(headers, fn(
        {^char_header, value}) -> value
        _ -> nil
      end)
    end
  end

  defmacro assert_public(definition, args) do
    quote bind_quoted: [definition: definition, args: args] do
      url = definition.url(args)
      {:ok, {{_, code, msg}, headers, _}} = :httpc.request(to_char_list(url))
      assert code == 200
      assert msg == 'OK'
    end
  end

  defmacro assert_public_with_extension(definition, args, version, extension) do
    quote bind_quoted: [definition: definition, version: version, args: args, extension: extension] do
      url = definition.url(args, version)
      {:ok, {{_, code, msg}, headers, _}} = :httpc.request(to_char_list(url))
      assert code == 200
      assert msg == 'OK'
      assert Path.extname(url) == extension
    end
  end

  setup_all do
    Application.ensure_all_started(:httpoison)
    Application.ensure_all_started(:ex_aws)
    Application.put_env :arc, :manta_ssh_private_key, System.get_env("ARC_TEST_SSH_PRIVATE_KEY")
    Application.put_env :arc, :manta_ssh_fingerprint, System.get_env("ARC_TEST_SSH_FINGERPRINT")
    Application.put_env :arc, :manta_user, System.get_env("ARC_TEST_MANTA_USER")
  end

  @tag :manta
  @tag timeout: 15000
  test "public full qualified url" do
    assert "https://us-east.manta.joyent.com/#{manta_user}/public/arctest/uploads/image.png" == DummyDefinition.url(@img)
  end

  @tag :manta
  @tag timeout: 15000
  test "public put and get" do
    assert {:ok, "image.png"} == DummyDefinition.store(@img)
    assert_public(DummyDefinition, "image.png")
    delete_and_assert_not_found(DummyDefinition, "image.png")
  end

  @tag :manta
  @tag timeout: 15000
  test "content_type" do
    {:ok, "image.png"} = DummyDefinition.store({@img, :with_content_type})
    assert_header(DummyDefinition, "image.png", "content-type", "image/png; type=file")
    delete_and_assert_not_found(DummyDefinition, "image.png")
  end

  @tag :manta
  @tag timeout: 150000
  test "delete with scope" do
    scope = %{id: 1}
    {:ok, path} = DefinitionWithScope.store({"test/support/image.png", scope})
    assert "https://us-east.manta.joyent.com/#{manta_user}/public/uploads/with_scopes/1/image.png" == DefinitionWithScope.url({path, scope})
    assert_public(DefinitionWithScope, {path, scope})
    delete_and_assert_not_found(DefinitionWithScope, {path, scope})
  end

  @tag :manta
  @tag timeout: 150000
  test "put with converted version" do
    assert {:ok, "image.png"} == DefinitionWithThumbnail.store(@img)
    assert_public_with_extension(DefinitionWithThumbnail, "image.png", :thumb, ".jpg")
    delete_and_assert_not_found(DefinitionWithThumbnail, "image.png")
  end
end
