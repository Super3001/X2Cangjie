// Regression: ctor params with middle default value violate Cangjie named-param order.
// 1g R2 fixed this for `func` declarations (render_func L1085-1102) but NOT for
// `init(...)` ctor params — fix-history L189 noted "构造器参数分支未动（无实例）".
// 1f koin-core provides instances (Scope/BeanDefinition ctors).
// Fix: apply the same middle-default-param degradation to ctor_params rendering.
//
// Note: call-site `Foo(1, "y", 2)` is translated to `Foo(1, b: "y", 2)` which
// conflicts with the degraded declaration. Known limitation (1g R2 fix-history
// L189). Test only verifies declaration compiles, no call.

class Foo(val a: Int, val b: String = "x", val c: Int) {
    fun describe(): String {
        return "${a}${b}${c}"
    }
}

fun main() {
    println("ok")
}
