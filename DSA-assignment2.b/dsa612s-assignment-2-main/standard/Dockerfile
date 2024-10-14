FROM ballerina/ballerina

USER root

WORKDIR /app/
COPY . ./standard/
RUN bal build standard
CMD ["bal", "run", "./standard/target/bin/standard.jar"]