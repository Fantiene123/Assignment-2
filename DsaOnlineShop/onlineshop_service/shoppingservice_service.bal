import ballerina/grpc;
import ballerina/uuid;


// In-memory storage
map<Product> productInventory = {};
map<User> users = {};
map<CartItem[]> userCarts = {};


listener grpc:Listener ep = new (9090);

@grpc:Descriptor {value: PROTOBUFF_DESC}
service "ShoppingService" on ep {
    remote function AddProduct(Product value) returns ProductResponse|error {
        string sku = uuid:createType1AsString();
        value.sku = sku;
        lock {
            productInventory[sku] = value.clone();
        }
        return {sku, product: value};
    }

     remote function CreateUsers(stream<User, grpc:Error?> clientStream) returns UsersResponse|error {
        int createdCount = 0;
        check clientStream.forEach(function(User user) {
            lock {
                users[user.user_id] = user.clone();
            }
            createdCount += 1;
        });
        return {created_count: createdCount};
    }

     remote function UpdateProduct(UpdateProductRequest value) returns ProductResponse|error {
        lock {
            if (!productInventory.hasKey(value.sku)) {
                return error("Product not found");
            }
            productInventory[value.sku] = value.product.clone();
        }
        return {sku: value.sku, product: value.product};
    }

     remote function RemoveProduct(RemoveProductRequest value) returns ProductListResponse|error {
        lock {
            if (!productInventory.hasKey(value.sku)) {
                return error("Product not found");
            }
            _ = productInventory.remove(value.sku);
            return {products: productInventory.toArray()};
        }
    }

     remote function ListAvailableProducts(Empty value) returns ProductListResponse|error {
        lock {
            Product[] availableProducts = from var product in productInventory
                                          where product.status == AVAILABLE
                                          select product;
            return {products: availableProducts};
        }
    }

     remote function SearchProduct(SearchProductRequest value) returns ProductResponse|error {
        lock {
            if (!productInventory.hasKey(value.sku)) {
                return error("Product not found");
            }
            return {sku: value.sku, product: productInventory.get(value.sku)};
        }
    }
     remote function AddToCart(AddToCartRequest value) returns CartResponse|error {
        lock {
            if (!users.hasKey(value.user_id)) {
                return error("User not found");
            }
            if (!productInventory.hasKey(value.sku)) {
                return error("Product not found");
            }
            if (productInventory.get(value.sku).stock_quantity < value.quantity) {
                return error("Insufficient stock");
            }

            CartItem[] userCart = userCarts[value.user_id] ?: [];
            CartItem[] updatedCart = userCart.clone();
            int? existingItemIndex = ();
            foreach int i in 0 ..< updatedCart.length() {
                if (updatedCart[i].sku == value.sku) {
                    existingItemIndex = i;
                    break;
                }
            }

            if (existingItemIndex is int) {
                updatedCart[existingItemIndex].quantity += value.quantity;
            } else {
                updatedCart.push({sku: value.sku, quantity: value.quantity});
            }

            userCarts[value.user_id] = updatedCart;
            return {items: updatedCart};
        }
    }

     remote function PlaceOrder(PlaceOrderRequest value) returns OrderResponse|error {
        lock {
            if (!users.hasKey(value.user_id)) {
                return error("User not found");
            }

            CartItem[] userCart = userCarts[value.user_id] ?: [];
            if (userCart.length() == 0) {
                return error("Cart is empty");
            }

            float totalPrice = 0;
            foreach var item in userCart {
                if (!productInventory.hasKey(item.sku)) {
                    return error(string `Product with SKU ${item.sku} not found`);
                }
                var product = productInventory.get(item.sku);
                if (product.stock_quantity < item.quantity) {
                    return error(string `Insufficient stock for product ${product.name}`);
                }
                totalPrice += product.price * item.quantity;
                product.stock_quantity -= item.quantity;
            }

            string orderId = uuid:createType1AsString();
            // Here you would typically save the order to a database
            // For this example, we'll just clear the user's cart
            _ = userCarts.remove(value.user_id);

            return {
                order_id: orderId,
                items: userCart,
                total_price: totalPrice
            };
        }
    }
}

// This function should be generated by the Ballerina compiler
function getDescriptorMap() returns map<string> {
    map<string> descriptorMap = {};
    return descriptorMap;
}