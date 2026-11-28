package android.os

import java.util.PriorityQueue

class Bundle {
    fun putFloat(key: String, value: Float) {}
}

class Looper private constructor() {
    private data class Task(val at: Long, val order: Long, val action: () -> Unit)
    private val tasks = PriorityQueue(compareBy<Task>({ it.at }, { it.order }))
    private var scheduled = 0L
    private var time = 0L

    fun post(delay: Long, action: () -> Unit) {
        tasks.add(Task(time + delay, scheduled++, action))
    }

    fun advanceBy(elapsed: Long) {
        val until = time + elapsed
        while (tasks.peek()?.let { it.at <= until } == true) {
            val task = tasks.remove()
            time = task.at
            task.action()
        }
        time = until
    }

    fun clear() = tasks.clear()

    companion object {
        private val main = Looper()
        fun getMainLooper(): Looper = main
    }
}

class Handler(private val looper: Looper) {
    fun post(action: () -> Unit) = looper.post(0, action)
    fun postDelayed(action: () -> Unit, delay: Long) = looper.post(delay, action)
    fun removeCallbacksAndMessages(token: Any?) = looper.clear()
}
