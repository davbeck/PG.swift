FROM swift:3

RUN mkdir /app
WORKDIR /app

ADD Package.swift /app/Package.swift
RUN swift package fetch
ADD . /app
