FROM butts

ENV MIX_ENV=prod \
    SECRET_KEY_BASE=superdupersecret \
    LANG=C.UTF-8

WORKDIR /workdir/yay/

COPY mix.exs mix.lock ./
RUN mix do deps.get --only prod 

COPY assets/package.json assets/package-lock.json assets/
RUN cd assets && \
    npm install

#clean this up
COPY . .

RUN cd assets && \
    npm run prod && \
    cd .. && \
    mix phx.digest

RUN mix release first_deploy --overwrite

RUN cp _build/prod/first_deploy-0.1.0.tar.gz first_deploy-0.1.0.tar.gz

