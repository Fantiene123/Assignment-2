import ballerina/io;
import ballerinax/kafka;
import ballerina/lang.value;
import ballerinax/mysql.driver as _;
import ballerinax/mysql;
import ballerina/sql;
import ballerina/random;

final mysql:Client dbClient = check new(
    host="172.25.0.4", user="root", password="root", port=3306, database="package_delivery_system"
);

type Package readonly & record {
    string customer_name;
    string contact_number;
    string pickup_location;
    string delivery_location;
    string delivery_type;
    string preferred_times;
};

type Delivery record {
    string delivery_type;
    string delivery_time;
    string delivery_day;
};


configurable string groupId = "express";
configurable string express_delivery_requests = "express-delivery-requests";
configurable string delivery_schedule_response = "delivery-schedule-response";
configurable decimal pollingInterval = 1;
configurable string kafkaEndpoint = "172.25.0.11:9092";

final kafka:ConsumerConfiguration consumerConfigs = {
    groupId: groupId,
    topics: [express_delivery_requests],
    offsetReset: kafka:OFFSET_RESET_EARLIEST,
    pollingInterval
};

service on new kafka:Listener(kafkaEndpoint, consumerConfigs) {
    private final kafka:Producer packageProducer;
    private final string[] morning_times =  ["9h00", "10h00", "11h00"];
    private final string[] afternoon_times =  ["13h00", "14h00", "15h00"];
    private final string[] evening_times =  ["18h00", "19h00", "20h00"];
    private final string[] days_of_the_week =  ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
    private final string[] locations =  ["Windhoek", "Rehoboth", "Walvis Bay"];
    private Package package;
    public function init() returns error? {
        self.packageProducer = check new (kafkaEndpoint);
    }
     remote function onConsumerRecord(kafka:AnydataConsumerRecord[] records) returns error? {
         foreach var item in records {
            byte[] byteArray = <byte[]> item.value;
            string jsonString = check string:fromBytes(byteArray);
            json Json = check value:fromJsonString(jsonString);
            self.package = check Json.cloneWithType(Package);

            boolean validation = false;
            self.locations.forEach(function (string location){
                if (location == self.package.delivery_location){
                    validation = true;
                }
            });
            if (validation){
                //Process delivery package
                Delivery delivery = {delivery_day: "", delivery_time: "", delivery_type: self.package.delivery_type};
                io:println("Processing 'express' package delivery request...");
                //Calculate delivery time
                int random;
                match self.package.preferred_times{
                    "Morning" => {
                        random = check random:createIntInRange(0, 3);
                        delivery.delivery_time = self.morning_times[random];
                    }
                    "Afternoon" => {
                        random = check random:createIntInRange(0, 3);
                        delivery.delivery_time = self.afternoon_times[random];
                    }
                    "Evening" => {
                        random = check random:createIntInRange(0, 3);
                        delivery.delivery_time = self.evening_times[random];
                    }
                }
                //Calculate delivery day
                random = check random:createIntInRange(0, 3);
                delivery.delivery_day = self.days_of_the_week[random];
                _ = check addDelivery(delivery, self.package);
                 //Delivering response to user
                check self.packageProducer->send({
                    topic: delivery_schedule_response,
                    value: delivery.toJsonString() 
                });
            }
            else{
                return error("Delivery location: " + self.package.delivery_location + " not available!");
            }
         }
     }
}

isolated function addDelivery(Delivery del, Package pkg) returns error?{
    sql:ExecutionResult result = check dbClient->execute(`
            INSERT INTO delivery_schedules (delivery_type, delivery_time, delivery_day) 
                VALUES (${del.delivery_type}, ${del.delivery_time}, ${del.delivery_day}); 
            `);
        int|error schedule_id = <int>check result.lastInsertId;
        string contact_number = pkg.contact_number;
        //Update'tracking_id' and 'status' in deliveries table after order has been fulfilled
        sql:ExecutionResult exec = check dbClient->execute(`
            UPDATE deliveries SET status = 'COMPLETED', tracking_id = ${check schedule_id} WHERE contact_number = ${contact_number};
        `);
}