### multi stage builds

# Build image - action code
FROM alpine:3.13 as action

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

# Final image
FROM alpine:3.13

COPY --from=action /entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
