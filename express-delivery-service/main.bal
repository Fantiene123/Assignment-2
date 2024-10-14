import ballerina/http;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;
import ballerinax/kafka;
import ballerina/time;
import ballerina/log;
import ballerina/task;

configurable string dbHost = ?;
configurable string dbUser = ?;
configurable string dbPassword = ?;
configurable string dbName = ?;
configurable int dbPort = ?;
configurable string kafkaBootstrapServers = ?;

type DeliveryResponse record {|
    string trackingId;
    string status;
    string estimatedDeliveryTime;
    DeliveryRequest originalRequest;
|};

type DeliveryRequest record {|
    string deliveryType;
    string pickupLocation;
    string deliveryLocation;
    string packageType;
    CustomerInfo customerInfo;
|};

type CustomerInfo record {|
    string firstName;
    string lastName;
    string contactNumber;
|};

service /express on new http:Listener(8082) {
    private final mysql:Client dbClient;
    private final kafka:Producer kafkaProducer;
    private final kafka:Consumer kafkaConsumer;

    function init() returns error? {
        self.dbClient = check new(host=dbHost, user=dbUser, password=dbPassword, database=dbName, port=dbPort);

        kafka:ProducerConfiguration producerConfig = {
            clientId: "express-delivery-producer",
            acks: "all",
            retryCount: 3
        };
        self.kafkaProducer = check new (kafkaBootstrapServers, producerConfig);

        kafka:ConsumerConfiguration consumerConfig = {
            groupId: "express-delivery-group",
            topics: ["expressDeliveryTopic"]
        };
        self.kafkaConsumer = check new (kafkaBootstrapServers, consumerConfig);

        task:Schedule job = {
            intervalInMillis: 5000,
            initialDelayInMillis: 1000
        };
        _ = check task:scheduleJobRecurByFrequency(job, self.processDeliveries);

        log:printInfo("Express Delivery Service initialized");
    }

    resource function get deliveries() returns DeliveryResponse[]|error {
        sql:ParameterizedQuery query = `SELECT dr.* FROM delivery_responses dr
            JOIN deliveries d ON dr.deliveryId = d.deliveryId
            WHERE d.deliveryType = 'Express'`;
        stream<record {}, error?> resultStream = self.dbClient->query(query);

        DeliveryResponse[] responses = [];
        check from record {} result in resultStream
            do {
                DeliveryResponse response = {
                    trackingId: result["trackingId"].toString(),
                    status: result["status"].toString(),
                    estimatedDeliveryTime: result["estimatedDeliveryTime"].toString(),
                    originalRequest: {} // We would need to fetch this from the deliveries table
                };
                responses.push(response);
            };
        check resultStream.close();

        return responses;
    }

    function processDeliveries() returns error? {
        kafka:ConsumerRecord[] records = check self.kafkaConsumer->poll(1);
        foreach kafka:ConsumerRecord record in records {
            DeliveryResponse response = check record.value.fromBytes().fromJsonString().cloneWithType();
            DeliveryResponse updatedResponse = check self.processExpressDelivery(response);

            sql:ParameterizedQuery query = `UPDATE delivery_responses 
                SET status = ${updatedResponse.status}, estimatedDeliveryTime = ${updatedResponse.estimatedDeliveryTime} 
                WHERE trackingId = ${updatedResponse.trackingId}`;
            _ = check self.dbClient->execute(query);

            byte[] serializedMsg = updatedResponse.toJsonString().toBytes();
            _ = check self.kafkaProducer->send({topic: "expressDeliveryResponseTopic", value: serializedMsg});

            log:printInfo(string `Processed express delivery for tracking ID: ${updatedResponse.trackingId}`);
        }
    }

    function processExpressDelivery(DeliveryResponse response) returns DeliveryResponse|error {
        time:Utc currentTime = time:utcNow();
        time:Utc estimatedDeliveryTime = time:utcAddDays(currentTime, 1);

        response.status = "Processing Express Delivery";
        response.estimatedDeliveryTime = time:utcToString(estimatedDeliveryTime);
        return response;
    }
}