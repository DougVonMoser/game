
run from assets
```bash
cd assets
chokidar "./src/**/*.elm" -c "clear && printf '\e[3J' && elm make src/Main.elm --output=/dev/null" --initial
```

deployment considerations

i dont care about 
- constant uptime. its okay to have downtime during deployments to save on cost
- testing. atm, no tests are in place and any sense of CI is undesirable

i care about/goals
- cost. aws aint free. instance limits/billing limits
- completely automated after push to source 
    + dns resolution/load balancer
    + old runtime teardown
- secure secret management


TODOS: 
resolve a dns at a load balancer

what if docker built it the release locally, pushed it up to s3. 
kill old
ec2 instance grabs that release and starts it
point load balancer at new 


commands to build self contained release in docker
```bash
mix deps.get --only prod
npm run prod --prefix ./assets
mix phx.digest
SECRET_KEY_BASE=superdupersecret MIX_ENV=prod mix release --overwrite
# _build/prod/rel/code_names/bin/code_names start
# _build/prod/rel/code_names/bin/code_names stop
```
