FROM internetsystemsconsortium/bind9:9.20@sha256:66092edb53c081fa11b1fa8219e99065b0f497cb38f568ba789702a4c10e2590
USER root
RUN apk add --no-cache python3
COPY named.conf /etc/bind/named.conf
COPY db.cloud.local db.myminicloud.local /opt/zones/
COPY generate-zones.py /usr/local/bin/generate-zones.py
ENTRYPOINT ["python3", "/usr/local/bin/generate-zones.py"]
