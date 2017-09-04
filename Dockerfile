FROM kylef/swiftenv
RUN swiftenv install 3.1

RUN apt-get -qq update
RUN apt-get install -y openssl libssl-dev

RUN mkdir /app
WORKDIR /app

ADD Package.swift /app/Package.swift
ADD Package.pins /app/Package.pins
ADD Package.resolved /app/Package.resolved
RUN swift package fetch
ADD . /app
