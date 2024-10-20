import ballerina/io;

ShoppingServiceClient ep = check new ("http://localhost:9090");

public function main() returns error? {
    while true {
        io:println("\nOnline Shopping System");
        io:println("1. Add Product");
        io:println("2. Update Product");
        io:println("3. Remove Product");
        io:println("4. List Available Products");
        io:println("5. Search Product");
        io:println("6. Add to Cart");
        io:println("7. Place Order");
        io:println("8. Create Users");
        io:println("9. Run All Operations");
        io:println("10. Exit");
        
        string choice = io:readln("Enter your choice: ");
        
        match choice {
            "1" => {
                check addProduct();
            }
            "2" => {
                check updateProduct();
            }
            "3" => {
                check removeProduct();
            }
            "4" => {
                check listAvailableProducts();
            }
            "5" => {
                check searchProduct();
            }
            "6" => {
                check addToCart();
            }
            "7" => {
                check placeOrder();
            }
            "8" => {
                check createUsers();
            }
            "9" => {
                check runAllOperations();
            }
            "10" => {
                break;
            }
            _ => {
                io:println("Invalid choice. Please try again.");
            }
        }
    }
}

function addProduct() returns error? {
    string name = io:readln("Enter product name: ");
    string description = io:readln("Enter product description: ");
    float price = check float:fromString(io:readln("Enter product price: "));
    int stock_quantity = check int:fromString(io:readln("Enter stock quantity: "));
    string sku = io:readln("Enter SKU: ");
    
    Product product = {name, description, price, stock_quantity, sku, status: AVAILABLE};
    ProductResponse|error response = ep->AddProduct(product);
    if response is error {
        io:println("Error adding product: ", response.message());
    } else {
        io:println("Product added successfully: ", response);
    }
}

function updateProduct() returns error? {
    string sku = io:readln("Enter SKU of product to update: ");
    string name = io:readln("Enter new product name: ");
    string description = io:readln("Enter new product description: ");
    float price = check float:fromString(io:readln("Enter new product price: "));
    int stock_quantity = check int:fromString(io:readln("Enter new stock quantity: "));
    
    UpdateProductRequest request = {
        sku: sku,
        product: {name, description, price, stock_quantity, sku, status: AVAILABLE}
    };
    ProductResponse|error response = ep->UpdateProduct(request);
    if response is error {
        io:println("Error updating product: ", response.message());
    } else {
        io:println("Product updated successfully: ", response);
    }
}

function removeProduct() returns error? {
    string sku = io:readln("Enter SKU of product to remove: ");
    
    RemoveProductRequest request = {sku: sku};
    ProductListResponse|error response = ep->RemoveProduct(request);
    if response is error {
        io:println("Error removing product: ", response.message());
    } else {
        io:println("Product removed successfully. Updated product list: ", response);
    }
}

function listAvailableProducts() returns error? {
    Empty request = {};
    ProductListResponse|error response = ep->ListAvailableProducts(request);
    if response is error {
        io:println("Error listing products: ", response.message());
    } else {
        io:println("Available products: ", response);
    }
}

function searchProduct() returns error? {
    string sku = io:readln("Enter SKU of product to search: ");
    
    SearchProductRequest request = {sku: sku};
    ProductResponse|error response = ep->SearchProduct(request);
    if response is error {
        io:println("Error searching product: ", response.message());
    } else {
        io:println("Product found: ", response);
    }
}

function addToCart() returns error? {
    string user_id = io:readln("Enter user ID: ");
    string sku = io:readln("Enter SKU of product to add to cart: ");
    int quantity = check int:fromString(io:readln("Enter quantity: "));
    
    AddToCartRequest request = {user_id: user_id, sku: sku, quantity: quantity};
    CartResponse|error response = ep->AddToCart(request);
    if response is error {
        io:println("Error adding to cart: ", response.message());
    } else {
        io:println("Product added to cart successfully. Updated cart: ", response);
    }
}

function placeOrder() returns error? {
    string user_id = io:readln("Enter user ID: ");
    
    PlaceOrderRequest request = {user_id: user_id};
    OrderResponse|error response = ep->PlaceOrder(request);
    if response is error {
        io:println("Error placing order: ", response.message());
    } else {
        io:println("Order placed successfully: ", response);
    }
}

function createUsers() returns error? {
    string user_id = io:readln("Enter user ID: ");
    string name = io:readln("Enter user name: ");
    string type_str = io:readln("Enter user type (CUSTOMER or ADMIN): ");
    UserType user_type = (type_str == "ADMIN") ? ADMIN : CUSTOMER;

    User user = {user_id: user_id, name: name, 'type: user_type};
    CreateUsersStreamingClient streamingClient = check ep->CreateUsers();
    check streamingClient->sendUser(user);
    check streamingClient->complete();
    UsersResponse? response = check streamingClient->receiveUsersResponse();
    if response is () {
        io:println("No response received from server");
    } else {
        io:println("Users created successfully: ", response);
    }
}

function runAllOperations() returns error? {
    io:println("\nRunning all operations...");

    // Add Product
    Product addProductRequest = {name: "ballerina", description: "ballerina", price: 1, stock_quantity: 1, sku: "ballerina", status: AVAILABLE};
    ProductResponse|error addProductResponse = ep->AddProduct(addProductRequest);
    if addProductResponse is error {
        io:println("Error adding product: ", addProductResponse.message());
    } else {
        io:println("Product added successfully: ", addProductResponse);
    }

    // Update Product
    UpdateProductRequest updateProductRequest = {sku: "ballerina", product: {name: "updated_ballerina", description: "updated_ballerina", price: 2, stock_quantity: 2, sku: "ballerina", status: AVAILABLE}};
    ProductResponse updateProductResponse = check ep->UpdateProduct(updateProductRequest);
    io:println("Product updated: ", updateProductResponse);

    // Remove Product
    RemoveProductRequest removeProductRequest = {sku: "ballerina"};
    ProductListResponse removeProductResponse = check ep->RemoveProduct(removeProductRequest);
    io:println("Product removed. Updated list: ", removeProductResponse);

    // List Available Products
    Empty listAvailableProductsRequest = {};
    ProductListResponse listAvailableProductsResponse = check ep->ListAvailableProducts(listAvailableProductsRequest);
    io:println("Available products: ", listAvailableProductsResponse);

    // Search Product
    SearchProductRequest searchProductRequest = {sku: "ballerina"};
    ProductResponse searchProductResponse = check ep->SearchProduct(searchProductRequest);
    io:println("Search result: ", searchProductResponse);

    // Add to Cart
    AddToCartRequest addToCartRequest = {user_id: "user1", sku: "ballerina", quantity: 1};
    CartResponse addToCartResponse = check ep->AddToCart(addToCartRequest);
    io:println("Added to cart: ", addToCartResponse);

    // Place Order
    PlaceOrderRequest placeOrderRequest = {user_id: "user1"};
    OrderResponse placeOrderResponse = check ep->PlaceOrder(placeOrderRequest);
    io:println("Order placed: ", placeOrderResponse);

    // Create Users
    User createUsersRequest = {user_id: "user2", name: "John Doe", 'type: CUSTOMER};
    CreateUsersStreamingClient createUsersStreamingClient = check ep->CreateUsers();
    check createUsersStreamingClient->sendUser(createUsersRequest);
    check createUsersStreamingClient->complete();
    UsersResponse? createUsersResponse = check createUsersStreamingClient->receiveUsersResponse();
    io:println("Users created: ", createUsersResponse);

    io:println("\nAll operations completed successfully!");
}