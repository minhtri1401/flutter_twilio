package com.dev.flutter_twilio.types

@FunctionalInterface
fun interface CompletionHandler<T> {
    fun withValue(t: T?)
}