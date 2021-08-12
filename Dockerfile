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

#
# This one is for doing the actual build
#
FROM base as build

#
# Copy the sources
#
COPY --from=src /src ./

#
# Run the actual build
#
RUN yarn install --pure-lockfile
RUN yarn run build

#
# Final parameters
#
EXPOSE  8081
CMD [ "yarn", "run", "dev" ]

#
# The actual running container
#
FROM base

#
# Basic Parameters
#
ARG ARCH="amd64"
ARG OS="linux"
ARG VER="3.0.1"
ARG PKG="grafana-image-renderer"

#
# Some important labels
#
LABEL ORG="Armedia LLC"
LABEL MAINTAINER="Armedia Devops Team <devops@armedia.com>"
LABEL APP="Grafana Image Renderer"
LABEL VERSION="${VER}"

#
# Create the required user
#
RUN useradd --system --user-group "${UID}"

#
# Some important environment variables
#
ENV GF_PATHS_HOME="/usr/share/grafana"
ENV NODE_ENV="production"

WORKDIR "${GF_PATHS_HOME}"

#
# Copy over the built artifacts
#
COPY --from=build /usr/src/app/node_modules node_modules
COPY --from=build /usr/src/app/build build
COPY --from=build /usr/src/app/proto proto
COPY --from=build /usr/src/app/default.json config.json
COPY --from=build /usr/src/app/plugin.json plugin.json

#
# Set directory ownership
#
RUN chown -R "${UID}:" "${GF_PATHS_HOME}"

#
# Final parameters
#
USER        ${UID}
EXPOSE      8081
ENTRYPOINT  [ "/usr/local/bin/node", ]
CMD         [ "build/app.js", "server", "--config=config.json" ]
