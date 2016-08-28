Arc Manta
===

Arc Manta Provides an [`Arc`](https://github.com/stavro/arc) storage back-end for [`Joyent Manta`](https://www.joyent.com/manta).

## Installation

Add the latest stable release to your `mix.exs` file:

```elixir
defp deps do
  [
    arc_manta: "~> 0.0.1"
  ]
end
```

Then run `mix deps.get` in your shell to fetch the dependencies.

### Configuration

Manta uses SSH-signed timestamps to authenticate requests. You'll have to add some configuration to your application:

```elixir
config :arc,
  manta_user: "my_joyent_user",
  manta_ssh_fingerprint: "aa:bb:cc:dd:ee:ff:11:22:33:44:55:66:77:88:99:00",
  manta_ssh_private_key: "...an ASCII ssh private key added to your Joyent user's account..."
```

You probably want to load the private key from an ENV variable rather than hard-code it in your config.

## License

Copyright 2016 Dan Connor

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
