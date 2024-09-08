# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :logger, utc_log: true
config :tzdata, :autoupdate, :enabled

config :tzdata, download_url: "https://data.iana.org/time-zones/tzdata-latest.tar.gz"
# config :tzdata, :data_dir, "/etc/elixir_tzdata_storage"
