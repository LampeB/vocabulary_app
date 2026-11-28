package io.flutter.plugin.common

class BinaryMessenger {
    lateinit var channel: MethodChannel
}

class MethodCall(val method: String, val arguments: Any?) {
    @Suppress("UNCHECKED_CAST")
    fun <T> argument(key: String): T? = (arguments as? Map<*, *>)?.get(key) as T?
}

class MethodChannel(messenger: BinaryMessenger, val name: String) {
    interface Result {
        fun success(result: Any?)
        fun notImplemented()
    }

    private var handler: ((MethodCall, Result) -> Unit)? = null

    init { messenger.channel = this }

    fun setMethodCallHandler(handler: ((MethodCall, Result) -> Unit)?) {
        this.handler = handler
    }

    fun invoke(method: String, arguments: Any?, result: Result) {
        checkNotNull(handler)(MethodCall(method, arguments), result)
    }
}
