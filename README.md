# nuntiux [![Elixir CI][ci-img]][ci]

[ci]: https://github.com/2Latinos/nuntiux
[ci-img]: https://github.com/2Latinos/nuntiux/actions/workflows/elixir.yml/badge.svg

`nuntiux` is an Elixir library to mock registered processes. Its main use case is to intercept
messages sent to specific processes and to allow the consumer to act upon them.

It is a sister application to [nuntius](https://github.com/2Latinos/nuntius) initially developed
by Brujo Benavides and Paulo Ferraz de Oliveira, now replicated as a learning
exercise, though our goal is to have the same (equivalent) interface and target the same use cases
in an initial release.

## Usage

`nuntiux` is best used via [mix](https://hexdocs.pm/mix/main/Mix.html)'s `test` environment and
using the [`mix test`](https://hexdocs.pm/mix/Mix.Tasks.Test.html) task:


1\. change your `mix.exs`' `deps` to include:

```elixir
{:nuntiux, "1.0.0", only: :test, runtime: false}
```

2\. run your `nuntiux`-enabled tests with:

```shell
mix test
```

## Features

* places mock processes in front of previously registered processes; these mock processes will
intercept (and optionally handle) every message that was supposed to go to the latter ones, then
  * allows mock processes to decide on letting the messages pass through, or not,
  * allows mock processes to run one or many pre-processing functions on each received message,
  * allows mock processes to discard intercepted messages entirely,
  * allows history collection of messages received by the mock processes for further analysis.

## Options for the mock process

The following parameters allow you to configure the interaction between the mock and mocked
processes, as well as other elements for debugging:

* `:passthrough`: when `true` (default: `true`) all messages received by the mock process are
passed through to the mocked process,
* `:history`: when `true` (default: `true`) all messages received by the mock process are
classified as per [Understanding the message history](#understanding-the-message-history).

## Understanding the message history

History elements are classified with 4 keys:

* `:timestamp`: an integer representing Erlang system time in native time unit,
* `:message`: the message that was received and/or potentially handled by expectations
(or passed through),
* `:mocked`: an indication of whether or not any of the expecations you declared handled
the message,
* `:passed_through`: an indication of whether or not the received message was passed through to
the mocked process.

## Documentation

Documentation is generated with:

```shell
mix docs
```

after which you can use your favorite Web browser to open `doc/index.html`.

It is also available, online, at [hexdocs.pm/nuntiux](https://hexdocs.pm/nuntiux/).

## Examples

Examples are found inside folder [examples](examples).

## Versioning

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Readme

We get inspiration for our README's format/content from
[Make a README](https://www.makeareadme.com/).

## Changelog

All notable changes to this project will be referenced from the [CHANGELOG](CHANGELOG.md).

## Contributing

Though this project is maintained by [2Latinos](https://github.com/2Latinos) contributions are
accepted and welcome. Check [CONTRIBUTING.md](CONTRIBUTING.md) for more.

## License

Check [LICENSE](LICENSE).
