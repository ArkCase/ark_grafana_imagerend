#
# This one houses the main git clone
#
FROM 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_base:latest AS src

#
# Basic Parameters
#
ARG ARCH="amd64"
ARG OS="linux"
ARG VER="3.0.1"
ARG PKG="grafana-image-renderer"
ARG SRC="https://github.com/grafana/grafana-image-renderer.git"

#
# Some important labels
#
LABEL ORG="Armedia LLC"
LABEL MAINTAINER="Armedia Devops Team <devops@armedia.com>"
LABEL APP="Grafana Image Renderer"
LABEL VERSION="${VER}"

WORKDIR /src

#
# Download the primary artifact
#
RUN yum -y update && yum -y install git && git clone -b "v${VER}" --single-branch "${SRC}" "/src"

#
# This one is for the base build
#
FROM 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_base:latest AS base

#
# Basic Parameters
#
ARG ARCH="amd64"
ARG OS="linux"
ARG VER="3.0.1"
ARG PKG="grafana-image-renderer"
ARG NODE_SRC="https://rpm.nodesource.com/setup_14.x"

#
# Some important labels
#
LABEL ORG="Armedia LLC"
LABEL MAINTAINER="Armedia Devops Team <devops@armedia.com>"
LABEL APP="Grafana Image Renderer"
LABEL VERSION="${VER}"

ENV CHROME_BIN="/usr/bin/chromium-browser"
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD="true"

WORKDIR /usr/src/app

#
# Install NodeJS and Yarn
#
RUN curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo
RUN rpm --import https://dl.yarnpkg.com/rpm/pubkey.gpg
RUN curl --silent --location "${NODE_SRC}" | bash -
RUN yum -y update && yum -y install nodejs yarn epel-release open-sans-fonts udev
RUN yum -y install chromium unifont unifont-fonts
RUN rm -rf /tmp/*

FROM base as build

COPY --from=src /src ./

RUN yarn install --pure-lockfile
RUN yarn run build

EXPOSE 8081

CMD [ "yarn", "run", "dev" ]

FROM base

LABEL maintainer="Grafana team <hello@grafana.com>"

ARG GF_UID="472"
ARG GF_GID="472"
ENV GF_PATHS_HOME="/usr/share/grafana"

WORKDIR $GF_PATHS_HOME

RUN addgroup -S -g $GF_GID grafana && \
    adduser -S -u $GF_UID -G grafana grafana && \
    mkdir -p "$GF_PATHS_HOME" && \
    chown -R grafana:grafana "$GF_PATHS_HOME"

ENV NODE_ENV=production

COPY --from=build /usr/src/app/node_modules node_modules
COPY --from=build /usr/src/app/build build
COPY --from=build /usr/src/app/proto proto
COPY --from=build /usr/src/app/default.json config.json
COPY --from=build /usr/src/app/plugin.json plugin.json

EXPOSE 8081

USER grafana

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "build/app.js", "server", "--config=config.json"]
