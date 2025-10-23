FROM quay.io/openshift/mdns-publisher:latest

RUN microdnf install -y inotify-tools && microdnf clean all

COPY mdns-entrypoint.sh /usr/local/bin/mdns-entrypoint.sh
RUN chmod +x /usr/local/bin/mdns-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/mdns-entrypoint.sh"]
