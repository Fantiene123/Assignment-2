import ballerina/http;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;
import ballerinax/kafka;
import ballerina/uuid;
import ballerina/log;

configurable string dbHost = ?;
configurable string dbUser = ?;
configurable string dbPassword = ?;
configurable string dbName = ?;
configurable int dbPort = ?;
configurable string kafkaBootstrapServers = ?;

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

type DeliveryResponse record {|
    string trackingId;
    string status;
    string estimatedDeliveryTime;
    DeliveryRequest originalRequest;
|};

service / on new http:Listener(8080) {
    private final mysql:Client dbClient;
    private final kafka:Producer kafkaProducer;

    function init() returns error? {
        self.dbClient = check new(host=dbHost, user=dbUser, password=dbPassword, database=dbName, port=dbPort);

        kafka:ProducerConfiguration producerConfig = {
            clientId: "logistics-producer",
            acks: "all",
            retryCount: 3
        };
        self.kafkaProducer = check new (kafkaBootstrapServers, producerConfig);

        log:printInfo("Central Logistics Service initialized");
    }

    resource function post request(@http:Payload DeliveryRequest payload) returns DeliveryResponse|error {
        string trackingId = uuid:createType1AsString();
        string deliveryId = uuid:createType1AsString();
        
        // Insert customer if not exists
        string customerId = check self.insertCustomer(payload.customerInfo);
        
        // Insert delivery
        sql:ParameterizedQuery query = `INSERT INTO deliveries 
            (deliveryId, origin, destination, packageType, deliveryType, customerId, status) 
            VALUES (${deliveryId}, ${payload.pickupLocation}, ${payload.deliveryLocation}, 
                    ${payload.packageType}, ${payload.deliveryType}, ${customerId}, 'Processing')`;
        _ = check self.dbClient->execute(query);

        DeliveryResponse response = {
            trackingId: trackingId,
            status: "Processing",
            estimatedDeliveryTime: "TBD",
            originalRequest: payload
        };

        check self.insertDeliveryResponse(response, deliveryId);
        check self.sendToDeliveryService(payload.deliveryType, response);

        log:printInfo(string `Processed delivery request: ${trackingId}`);
        return response;
    }

    resource function get status/[string trackingId]() returns DeliveryResponse|error {
        sql:ParameterizedQuery query = `SELECT * FROM delivery_responses WHERE trackingId = ${trackingId}`;
        stream<record {}, error?> resultStream = self.dbClient->query(query);
        record {}? result = check resultStream.next();
        check resultStream.close();

        if result is () {
            return error("Tracking ID not found");
        }

        DeliveryResponse response = {
            trackingId: result["trackingId"].toString(),
            status: result["status"].toString(),
            estimatedDeliveryTime: result["estimatedDeliveryTime"].toString(),
            originalRequest: {} // We would need to fetch this from the deliveries table
        };

        log:printInfo(string `Retrieved status for tracking ID: ${trackingId}`);
        return response;
    }

    function insertCustomer(CustomerInfo customerInfo) returns string|error {
        string customerId = uuid:createType1AsString();
        sql:ParameterizedQuery query = `INSERT INTO customers 
            (customerId, firstName, lastName, contactNumber) 
            VALUES (${customerId}, ${customerInfo.firstName}, ${customerInfo.lastName}, ${customerInfo.contactNumber})
            ON DUPLICATE KEY UPDATE 
            firstName = ${customerInfo.firstName}, 
            lastName = ${customerInfo.lastName}, 
            contactNumber = ${customerInfo.contactNumber}`;
        _ = check self.dbClient->execute(query);
        return customerId;
    }

    function insertDeliveryResponse(DeliveryResponse response, string deliveryId) returns error? {
        sql:ParameterizedQuery query = `INSERT INTO delivery_responses 
            (trackingId, status, estimatedDeliveryTime, deliveryId) 
            VALUES (${response.trackingId}, ${response.status}, ${response.estimatedDeliveryTime}, ${deliveryId})`;
        _ = check self.dbClient->execute(query);
    }

    function sendToDeliveryService(string deliveryType, DeliveryResponse response) returns error? {
        string topic = deliveryType + "DeliveryTopic";
        byte[] serializedMsg = response.toJsonString().toBytes();
        _ = check self.kafkaProducer->send({topic, value: serializedMsg});
    }
}