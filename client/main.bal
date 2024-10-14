import ballerina/http;
import ballerina/io;

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

configurable string centralLogisticsUrl = ?;

public function main() returns error? {
    http:Client centralLogisticsClient = check new (centralLogisticsUrl);

    while true {
        io:println("\nLogistics System Client");
        io:println("1. Submit a delivery request");
        io:println("2. Check delivery status");
        io:println("3. Exit");
        string choice = io:readln("Enter your choice (1-3): ");

        match choice {
            "1" => {
                check submitDeliveryRequest(centralLogisticsClient);
            }
            "2" => {
                check checkDeliveryStatus(centralLogisticsClient);
            }
            "3" => {
                io:println("Exiting...");
                return;
            }
            _ => {
                io:println("Invalid choice. Please try again.");
            }
        }
    }
}

function submitDeliveryRequest(http:Client client) returns error? {
    DeliveryRequest request = {
        deliveryType: io:readln("Enter delivery type (Standard/Express/International): "),
        pickupLocation: io:readln("Enter pickup location: "),
        deliveryLocation: io:readln("Enter delivery location: "),
        packageType: io:readln("Enter package type: "),
        customerInfo: {
            firstName: io:readln("Enter first name: "),
            lastName: io:readln("Enter last name: "),
            contactNumber: io:readln("Enter contact number: ")
        }
    };

    DeliveryResponse response = check client->/request.post(request);
    io:println("\nDelivery request submitted successfully!");
    io:println("Tracking ID: ", response.trackingId);
    io:println("Status: ", response.status);
    io:println("Estimated Delivery Time: ", response.estimatedDeliveryTime);
}

function checkDeliveryStatus(http:Client client) returns error? {
    string trackingId = io:readln("Enter tracking ID: ");
    DeliveryResponse response = check client->/status/[trackingId].get();
    io:println("\nDelivery Status:");
    io:println("Tracking ID: ", response.trackingId);
    io:println("Status: ", response.status);
    io:println("Estimated Delivery Time: ", response.estimatedDeliveryTime);
}