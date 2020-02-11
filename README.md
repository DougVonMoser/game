
run from assets
```bash
cd assets
chokidar "./src/**/*.elm" -c "clear && printf '\e[3J' && elm make src/Main.elm --output=/dev/null" --initial
```

https://www.design-seeds.com/in-nature/creatures/flamingo-hues-2/
