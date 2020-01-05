FROM code_names_build_env

ENV MIX_ENV=prod 
ENV SECRET_KEY_BASE=superdupersecret 

ADD mix.exs mix.lock ./
RUN mix do deps.get --only prod 

ADD assets/package.json assets/package-lock.json assets/
RUN cd assets && \
    npm install

ADD . .

RUN cd assets && \
    npm run prod && \
    cd .. && \
    mix phx.digest

RUN mix release first_deploy --overwrite
