# Code security

Run the security scan with:

```
./code --language go|js|elixir
```

The tool used depends on the language:
- Golang: [gosec](https://github.com/securego/gosec)
- Javascript: [njsscan](https://github.com/ajinabraham/njsscan)
- Elixir: [sobelow](https://github.com/nccgroup/sobelow)

By default, if the tool required isn't installed, the scan will fail. If you want to automatically install it, use the `-d` flag.

## Options

- `-l, --language LANGUAGE`: required; language of the dependencies to scan.
- `-i, --ignores IGNORES`: Rules to ignore. Default is none.
- `-d, --dependencies`: install missing dependencies
