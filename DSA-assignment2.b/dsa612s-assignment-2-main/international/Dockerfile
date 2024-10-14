FROM ballerina/ballerina

USER root

WORKDIR /app/
COPY . ./international/
RUN bal build international
CMD ["bal", "run", "./international/target/bin/international.jar"]