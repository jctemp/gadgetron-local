FROM alpine:latest
RUN apk add --no-cache sqlite

RUN echo -e '#!/bin/sh\n\
  mkdir -p /data\n\
  mkdir -p /data/blobs\n\
  sqlite3 /data/metadata.db "PRAGMA user_version = 0;"\n\
  chmod -R 777 /data\n\
  echo "Initialization complete!"' > /init.sh && chmod +x /init.sh

ENTRYPOINT ["/init.sh"]

