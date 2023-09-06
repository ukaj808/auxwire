FROM haskell:9.2.7
ENV NODE_MAJOR=20

RUN mkdir -p /opt/augslink
RUN mkdir -p /opt/augslink/tls

WORKDIR /opt/augslink

## Install pip to install yt-dlp
RUN apt-get update
RUN apt-get install -y python3
RUN curl -o get-pip.py https://bootstrap.pypa.io/get-pip.py 
RUN python3 get-pip.py
RUN python3 -m pip install -U yt-dlp

## Install node 18
RUN apt-get update
RUN apt-get install -y ca-certificates curl gnupg
RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
RUN apt-get update
RUN apt-get install -y nodejs

## Install ffmpeg
RUN apt-get install -y ffmpeg 

## Haskell Build
RUN cabal update

# Docker will cache this command as a layer, freeing us up to
# modify source code without re-installing dependencies
# (unless the .cabal file changes!)
COPY ./augslink.cabal .
RUN cabal build --only-dependencies -j4

## Now copy the rest of the source code (build)
COPY . .
RUN cabal install

RUN npm install
RUN npm run build

# todo
CMD ["augslink", "-p", "dist-static"]
