import ballerinax/kafka;
import ballerina/io;

type Package readonly & record {
    string customer_name;
    string contact_number;
    string pickup_location;
    string delivery_location;
    string delivery_type;
    string preferred_times;
};

type Delivery readonly & record {
    string delivery_type;
    string delivery_time;
    string delivery_day;
};

configurable string groupId = "customers";
configurable string new_delivery_request = "new-delivery-requests";
configurable string delivery_schedule_response = "delivery-schedule-response";
configurable decimal pollingInterval = 2;
configurable string kafkaEndpoint = "172.25.0.11:9092";

final kafka:ConsumerConfiguration consumerConfigs = {
    groupId: groupId,
    topics: [delivery_schedule_response],
    offsetReset: kafka:OFFSET_RESET_EARLIEST,
    pollingInterval
};

service on new kafka:Listener(kafkaEndpoint, consumerConfigs) {
    private final kafka:Producer packageProducer;

    function init() returns error? {
        self.packageProducer = check new (kafkaEndpoint);
        Package new_package = {customer_name: "Denzel Metukoma", contact_number: "0819503163", pickup_location: "Windhoek", delivery_location: "Angola", delivery_type: "international", preferred_times: "Evening"};
        check self.packageProducer->send({
            topic: new_delivery_request,
            value: new_package.toJsonString()
        });
        io:println("Submitted package delivery request!");
    }

    remote function onConsumerRecord(Delivery[] deliveries) returns error? {
        io:println("Delivery Schedule:");
        from Delivery delivery in deliveries
        do {
            io:println(delivery);
        };
    }
} 
