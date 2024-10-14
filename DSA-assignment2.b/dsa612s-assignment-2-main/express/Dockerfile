FROM ballerina/ballerina
USER root

WORKDIR /app/
COPY . ./express/
RUN bal build express
CMD ["bal", "run", "./express/target/bin/express.jar"]