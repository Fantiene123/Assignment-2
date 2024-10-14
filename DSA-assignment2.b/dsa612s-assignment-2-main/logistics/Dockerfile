FROM ballerina/ballerina

USER root

WORKDIR /app/
COPY . ./logistics/
RUN bal build logistics
CMD ["bal", "run", "./logistics/target/bin/logistics.jar"]

