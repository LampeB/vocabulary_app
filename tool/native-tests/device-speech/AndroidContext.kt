package android.content

class Context {
    val applicationContext: Context get() = this
    val packageManager = PackageManager()
}

class Intent(val action: String)

class PackageManager {
    fun queryIntentServices(intent: Intent, flags: Int): List<ResolveInfo> =
        listOf("ko-engine", "en-engine").map { ResolveInfo(ServiceInfo(it)) }
}

class ResolveInfo(val serviceInfo: ServiceInfo)

class ServiceInfo(val packageName: String)
