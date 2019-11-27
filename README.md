
run from assets
```bash
chokidar "./src/**/*.elm" -c "clear && printf '\e[3J' && elm make src/Main.elm --output=/dev/null" --initial
```
