# PG.swift

A [PostgreSQL](https://www.postgresql.org) client library written in pure Swift (without any dependency the C [libpq](https://www.postgresql.org/docs/9.5/static/libpq.html)).

## Motivation

[While](https://github.com/ZewoGraveyard/PostgreSQL) [everyone](https://github.com/vapor-community/postgresql) [seems](https://github.com/stepanhruda/PostgreSQL-Swift) [to](https://github.com/PerfectlySoft/Perfect-PostgreSQL) [agree](https://github.com/IBM-Swift/Swift-Kuery-PostgreSQL) that there needs to be a Swift native interface to Postgres, they all use the C library, [libpq](https://www.postgresql.org/docs/9.5/static/libpq.html). This is a reasonable approach but has a few drawbacks. For one, C lacks a universal event driven, non-blocking socket interface, so you are forced to block a thread while you wait for query responses. Swift has both [DispatchSource](https://developer.apple.com/reference/dispatch/dispatchsource)s and [RunLoops](https://developer.apple.com/reference/foundation/runloop) (this project currently uses the latter). This avoids creating extra threads, which incure performance and memory overhead. Additionally, the client has to do extra work to convert the data from the conneciton into C structures, then again into Swift types.

## Status

This project is in it's very earliest stage. You can create a client that connects to a server, but not much else. Here are some of the bigger features that need to be implemented before the framework is usable:

- [X] Connect client to server.
- [ ] Handle authentication other than passwordless.
- [ ] Execute queries.
- [ ] Return query results.
- [ ] Support for SSL.
- [ ] Support for Linux (much of NSStream is still unimplemented there, so this may be a big deal).

