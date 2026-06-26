package proj_ecommerce

main() {
    let catalog = ProductCatalog()
    catalog.addProduct(Product("Laptop", 999, 10))
    catalog.addProduct(Product("Mouse", 25, 100))
    catalog.addProduct(Product("Keyboard", 75, 50))
    catalog.addProduct(Product("Monitor", 450, 20))
    catalog.addProduct(Product("Headset", 60, 80))
    println("Product Catalog:")
    catalog.listProducts()
    println("Total products: ${catalog.totalProducts()}")
    let alice = Customer("Alice", 1)
    let bob = Customer("Bob", 2)
    let cart1 = ShoppingCart(alice)
    let laptop = catalog.findByName("Laptop")
    if (let Some(laptopValue) <- laptop) {
        let laptop = laptopValue
        cart1.addItem(laptop, 1)
    }
    let mouse = catalog.findByName("Mouse")
    if (let Some(mouseValue) <- mouse) {
        let mouse = mouseValue
        cart1.addItem(mouse, 2)
    }
    let cart2 = ShoppingCart(bob)
    let kb = catalog.findByName("Keyboard")
    if (let Some(kbValue) <- kb) {
        let kb = kbValue
        cart2.addItem(kb, 1)
    }
    let headset = catalog.findByName("Headset")
    if (let Some(headsetValue) <- headset) {
        let headset = headsetValue
        cart2.addItem(headset, 1)
    }
    println()
    cart1.printCart()
    println()
    cart2.printCart()
    println()
    let processor = OrderProcessor()
    let o1 = processor.checkout(cart1)
    let o2 = processor.checkout(cart2)
    processor.processAll()
    println()
    processor.printSummary()
    println()
    println(alice.info())
    println(bob.info())
}
