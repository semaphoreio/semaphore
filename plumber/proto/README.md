# Proto

This application serves as a container for all elixir modules generated from protobuf
message definitions which are used in other apps of plumber family.
All other apps in this repository should have this one as dependency.

## How to generate new proto modules?

1. Install protoc.

```
wget -O /tmp/protoc https://github.com/google/protobuf/releases/download/v3.3.0/protoc-3.3.0-linux-x86_64.zip
cd /tmp
unzip protoc
sudo mv bin/protoc /usr/local/bin/protoc
```

2. Install elixir protobuf.

```
mix escript.install hex protobuf 0.5.4
```

3. Switch to the `proto` directory in this repository.
4. Execute `make pb`. This will generate the latest proto files listed in the Makefile.
