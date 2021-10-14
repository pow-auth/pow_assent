# Dynamic Strategy Configuration

In most cases, having a single set of configuration options defined per provider strategy is sufficient.
For more advanced authorization flows, however, you may find the need to customize strategy configuration dynamically on a per-request basis.

Pow Assent includes a built-in Plug helper function specifically for these more advanced configuration scenarios: [`PowAssent.Plug.merge_provider_config`](https://hexdocs.pm/pow_assent/PowAssent.Plug.html#merge_provider_config/3).