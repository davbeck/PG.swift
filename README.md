# PG.swift

![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)
![MIT](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)

A [PostgreSQL](https://www.postgresql.org) client library written in pure Swift (without any dependency the C [libpq](https://www.postgresql.org/docs/9.5/static/libpq.html)).

## Usage

See [Swift Package Manager](https://swift.org/package-manager/#example-usage).

```swift
import PG

let config = Client.Config(user: "postgres", database: "pg_swift_tests")
let client = Client(config)

client.connect() { error in
	guard error == nil else { return }

	let id = UUID(uuidString: "A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11")
	let query = Query("SELECT * FROM example WHERE id = $1;", id)
	client.exec(query) { result in
		switch result {
		case .success(let result):
			print("name: \(result.rows.first?["name"])")
		case .failure(let error):
			print("failed to excecute query: \(error)")
		}
	}
}
```

## Motivation

[While](https://github.com/ZewoGraveyard/PostgreSQL) [everyone](https://github.com/vapor-community/postgresql) [seems](https://github.com/stepanhruda/PostgreSQL-Swift) [to](https://github.com/PerfectlySoft/Perfect-PostgreSQL) [agree](https://github.com/IBM-Swift/Swift-Kuery-PostgreSQL) that there needs to be a Swift native interface to Postgres, they all use the C library, [libpq](https://www.postgresql.org/docs/9.5/static/libpq.html). This is a reasonable approach but has a few drawbacks. For one, C lacks a universal event driven, non-blocking socket interface, so you are forced to block a thread while you wait for query responses. Swift has both [DispatchSource](https://developer.apple.com/reference/dispatch/dispatchsource)s and [RunLoops](https://developer.apple.com/reference/foundation/runloop) (this project currently uses the former). This avoids creating extra threads, which incure performance and memory overhead. Additionally, the client has to do extra work to convert the data from the conneciton into C structures, then again into Swift types.

The goal of this project is to be usable as is to connect to a PostgreSQL database, but low level enough that it won't get in the way (both in terms of performance and unused code) of higher levels of abstraction.

## Status

This project is in it's very earliest stage. You can create a client that connects to a server and excecute queries. Here are some of the bigger features that need to be implemented before the framework is usable:

- [X] Connect client to server.
- [X] Handle authentication other than passwordless.
- [X] Execute queries.
- [X] Return query results and convert them to usable types.
- [ ] Support for SSL.
- [X] Support for Linux (using [BlueSocket](https://github.com/IBM-Swift/BlueSocket) and [`DispatchSources`](https://developer.apple.com/reference/dispatch/dispatchsource)).
- [ ] Handle connection errors, disconnects and reconnects.
- [ ] Support for `LISTEN` and `NOTIFY`.
- [ ] Database pool for concurrent queries to the same server.

## Related projects

It's my intention to add other projects that expand upon this projects capabilities but can be ommited if the user doesn't need them.

- [ ] Integration with [PromiseKit](http://promisekit.org).
- [ ] String interpolation for queries that expand into query bindings.
- [ ] Swift 4 Encodable support on QueryResult.
