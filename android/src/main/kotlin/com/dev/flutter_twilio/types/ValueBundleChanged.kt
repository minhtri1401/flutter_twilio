package com.dev.flutter_twilio.types

import android.os.Bundle

@FunctionalInterface
fun interface ValueBundleChanged<T> {
    fun onChange(t: T?, extra: Bundle?)
}