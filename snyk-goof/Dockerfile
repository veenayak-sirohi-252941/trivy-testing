FROM node:6-stretch

RUN mkdir /usr/src/goof
RUN mkdir /tmp/extracted_files
COPY . /usr/src/goof
WORKDIR /usr/src/goof

RUN mkdir -p /opt/npm \
    && curl -fsSL https://registry.npmjs.org/npm/-/npm-6.14.18.tgz \
      | tar -xz --strip-components=1 -C /opt/npm \
    && node /opt/npm/bin/npm-cli.js ci \
      --ignore-scripts \
      --no-audit \
      --no-fund \
      --fetch-retries=2 \
      --fetch-timeout=30000
EXPOSE 3001
EXPOSE 9229
ENTRYPOINT ["npm", "start"]