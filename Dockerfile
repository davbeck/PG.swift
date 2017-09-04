FROM swift:3.1

RUN mkdir /app
WORKDIR /app

ADD Package.swift /app/Package.swift
ADD Package.pins /app/Package.pins
RUN swift package fetch
ADD . /app
