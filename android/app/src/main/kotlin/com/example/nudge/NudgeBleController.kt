package com.example.nudge

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothDevice
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.StandardCharsets
import java.util.UUID
import org.json.JSONObject

class NudgeBleController(
    private val activity: FlutterFragmentActivity,
    private val demoMode: Boolean = false
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        private const val METHOD_CHANNEL = "nudge/device_ble"
        private const val EVENT_CHANNEL = "nudge/device_ble_events"
        private const val SCAN_TIMEOUT_MS = 12_000L
        private const val TARGET_MTU = 517
        private const val ATT_HEADER_BYTES = 3
        private const val MAX_COMMAND_BYTES = 512
        private val SERVICE_UUID = UUID.fromString("7df10000-4e55-4447-4500-4e5544474531")
        private val COMMAND_UUID = UUID.fromString("7df10001-4e55-4447-4500-4e5544474531")
        private val STATE_UUID = UUID.fromString("7df10002-4e55-4447-4500-4e5544474531")
        private val EVENT_UUID = UUID.fromString("7df10003-4e55-4447-4500-4e5544474531")
        private val CLIENT_CONFIGURATION_UUID =
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        private val DEVICE_ID_PATTERN = Regex("^nudge-[A-Za-z0-9._-]{2,90}$")
    }

    private val serviceUuid = if (demoMode) UUID.fromString(DemoBleSpec.serviceUuid) else SERVICE_UUID
    private val commandUuid = if (demoMode) UUID.fromString(DemoBleSpec.commandUuid) else COMMAND_UUID
    private val stateUuid = if (demoMode) UUID.fromString(DemoBleSpec.stateUuid) else STATE_UUID
    private var demoTarget: String? = null
    private var demoEpoch = 0
    private var demoTimeout: Runnable? = null
    private var demoWriteTimeout: Runnable? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private val bluetoothManager =
        activity.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val permissionLauncher: ActivityResultLauncher<Array<String>> =
        activity.registerForActivityResult(
            ActivityResultContracts.RequestMultiplePermissions()
        ) { results ->
            val pending = pendingScanResult
            pendingScanResult = null
            if (pending == null) return@registerForActivityResult
            if (requiredPermissions().all { results[it] == true || hasPermission(it) }) {
                beginScan(pending)
            } else {
                pending.error(
                    "ble-permission-denied",
                    "Bluetooth permission is required to connect the Nudge device.",
                    null
                )
            }
        }

    private var eventSink: EventChannel.EventSink? = null
    private var bluetoothGatt: BluetoothGatt? = null
    private var commandCharacteristic: BluetoothGattCharacteristic? = null
    private var stateCharacteristic: BluetoothGattCharacteristic? = null
    private var eventCharacteristic: BluetoothGattCharacteristic? = null
    private var connectedDeviceId: String? = null
    private var pendingScanResult: MethodChannel.Result? = null
    private var pendingReadResult: MethodChannel.Result? = null
    private var pendingWriteResult: MethodChannel.Result? = null
    private var scanCallback: ScanCallback? = null
    private var activeScanResult: MethodChannel.Result? = null
    private var scanTimeout: Runnable? = null
    private var negotiatedMtu = 23

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, if (demoMode) "nudge/demo_ble" else METHOD_CHANNEL).setMethodCallHandler(this)
        EventChannel(messenger, if (demoMode) "nudge/demo_ble_events" else EVENT_CHANNEL).setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scanAndConnect" -> {
                if (demoMode) {
                    val target = call.argument<String>("device")
                    if (!DemoBleSpec.names.containsKey(target)) {
                        result.error("ble-demo-target", "Choose Orbit or Station Demo.", null)
                        return
                    }
                    if (scanCallback != null || bluetoothGatt != null || pendingScanResult != null) {
                        result.error("ble-busy", "Only one Demo connection is allowed.", null)
                        return
                    }
                    demoEpoch++
                    demoTarget = target
                }
                requestScan(result)
            }
            "readPendingEvent" -> if (demoMode) result.error("ble-demo-only", "Demo has no activity events.", null) else readPendingEvent(result)
            "writeCommand" -> writeCommand(call, result)
            "disconnect" -> {
                if (demoMode) demoEpoch++
                disconnectGatt()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun requiredPermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    private fun hasPermission(permission: String): Boolean =
        ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED

    private fun requestScan(result: MethodChannel.Result) {
        if (!activity.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)) {
            result.error("ble-unavailable", "This Android device does not support BLE.", null)
            return
        }
        val missing = requiredPermissions().filterNot(::hasPermission)
        if (missing.isNotEmpty()) {
            if (pendingScanResult != null) {
                result.error("ble-busy", "A Bluetooth permission request is already active.", null)
                return
            }
            pendingScanResult = result
            permissionLauncher.launch(missing.toTypedArray())
            return
        }
        beginScan(result)
    }

    @SuppressLint("MissingPermission")
    private fun beginScan(result: MethodChannel.Result) {
        // Android 12+ requires CONNECT even to read adapter state. This runs
        // only after requestScan/the permission callback granted permissions.
        val adapter = bluetoothManager.adapter
        if (adapter == null || !adapter.isEnabled) {
            result.error("ble-disabled", "Bluetooth is turned off or unavailable.", null)
            return
        }
        if (scanCallback != null || bluetoothGatt != null) {
            result.error("ble-busy", "A Nudge BLE connection is already active.", null)
            return
        }
        val scanner = adapter.bluetoothLeScanner
        if (scanner == null) {
            result.error("ble-unavailable", "Android BLE scanner is unavailable.", null)
            return
        }
        activeScanResult = result
        emit(mapOf("type" to "scanning"))
        var completed = false
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, scanResult: ScanResult) {
                if (completed) return
                val advertisedName = scanResult.scanRecord?.deviceName ?: scanResult.device.name
                val candidateId = advertisedName
                    ?.removePrefix("Nudge ")
                    ?.trim()
                if (demoMode) {
                    if (advertisedName != DemoBleSpec.names[demoTarget]) return
                } else if (candidateId == null || !DEVICE_ID_PATTERN.matches(candidateId)) return
                completed = true
                activeScanResult = null
                stopScan()
                connectedDeviceId = if (demoMode) demoTarget else candidateId
                bluetoothGatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    scanResult.device.connectGatt(
                        activity,
                        false,
                        gattCallback,
                        BluetoothDevice.TRANSPORT_LE
                    )
                } else {
                    scanResult.device.connectGatt(activity, false, gattCallback)
                }
                if (demoMode) {
                    val timeout = Runnable { emitError("改用裝置自動展示：Demo 連線逾時"); disconnectGatt() }
                    demoTimeout = timeout
                    mainHandler.postDelayed(timeout, 15_000L)
                }
                result.success(true)
            }

            override fun onScanFailed(errorCode: Int) {
                if (completed) return
                completed = true
                activeScanResult = null
                stopScan()
                result.error("ble-scan-failed", "BLE scan failed ($errorCode).", null)
                emitError("BLE scan failed ($errorCode).")
            }
        }
        scanCallback = callback
        val timeout = Runnable {
            if (completed) return@Runnable
            completed = true
            activeScanResult = null
            stopScan()
            result.error("ble-not-found", "No nearby Nudge device was found.", null)
            emitError("找不到附近的 Nudge 裝置。")
        }
        scanTimeout = timeout
        mainHandler.postDelayed(timeout, SCAN_TIMEOUT_MS)
        scanner.startScan(
            listOf(ScanFilter.Builder().setServiceUuid(ParcelUuid(serviceUuid)).build()),
            ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build(),
            callback
        )
    }

    @SuppressLint("MissingPermission")
    private fun stopScan() {
        val callback = scanCallback
        scanCallback = null
        if (callback != null) runCatching { bluetoothManager.adapter?.bluetoothLeScanner?.stopScan(callback) }
        scanTimeout?.let(mainHandler::removeCallbacks)
        scanTimeout = null
        activeScanResult?.error("ble-cancelled", "BLE scan cancelled.", null)
        activeScanResult = null
    }

    private val gattCallback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (bluetoothGatt !== gatt) return
            if (status == BluetoothGatt.GATT_SUCCESS && newState == BluetoothProfile.STATE_CONNECTED) {
                if (!gatt.requestMtu(TARGET_MTU)) {
                    if (demoMode) { emitError("Demo requires a larger BLE MTU; 改用裝置自動展示"); disconnectGatt() }
                    else discoverServices(gatt)
                }
                return
            }
            if (newState == BluetoothProfile.STATE_DISCONNECTED || status != BluetoothGatt.GATT_SUCCESS) {
                emit(mapOf("type" to "disconnected", "deviceId" to connectedDeviceId))
                clearGatt(gatt)
            }
        }

        @SuppressLint("MissingPermission")
        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            if (bluetoothGatt !== gatt) return
            if (demoMode && (status != BluetoothGatt.GATT_SUCCESS || mtu < 99)) {
                emitError("Demo MTU unavailable; 改用裝置自動展示"); disconnectGatt(); return
            }
            if (status == BluetoothGatt.GATT_SUCCESS) negotiatedMtu = mtu
            discoverServices(gatt)
        }

        @SuppressLint("MissingPermission")
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (bluetoothGatt !== gatt) return
            if (status != BluetoothGatt.GATT_SUCCESS) {
                emitError("Nudge BLE service discovery failed ($status).")
                disconnectGatt()
                return
            }
            val service: BluetoothGattService? = gatt.getService(serviceUuid)
            commandCharacteristic = service?.getCharacteristic(commandUuid)
            stateCharacteristic = service?.getCharacteristic(stateUuid)
            eventCharacteristic = service?.getCharacteristic(EVENT_UUID)
            val state = stateCharacteristic
            if (commandCharacteristic == null || state == null || (!demoMode && eventCharacteristic == null)) {
                emitError("Connected device does not expose the Nudge BLE contract.")
                disconnectGatt()
                return
            }
            if (!gatt.setCharacteristicNotification(state, true)) {
                emitError("Unable to subscribe to Nudge device state.")
                disconnectGatt()
                return
            }
            val descriptor = state.getDescriptor(CLIENT_CONFIGURATION_UUID)
            if (descriptor == null || !writeDescriptor(gatt, descriptor)) {
                emitError("Nudge state notification descriptor is unavailable.")
                disconnectGatt()
            }
        }

        override fun onDescriptorWrite(
            gatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            status: Int
        ) {
            if (bluetoothGatt !== gatt) return
            if (descriptor.uuid != CLIENT_CONFIGURATION_UUID || status != BluetoothGatt.GATT_SUCCESS) {
                emitError("Nudge state subscription failed ($status).")
                disconnectGatt()
                return
            }
            demoTimeout?.let(mainHandler::removeCallbacks)
            demoTimeout = null
            emit(mapOf("type" to "connected", "deviceId" to connectedDeviceId))
            readState(gatt)
        }

        @Deprecated("Android 13 compatibility callback")
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            if (bluetoothGatt !== gatt) return
            handleCharacteristicChanged(characteristic, characteristic.value ?: byteArrayOf())
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray
        ) {
            if (bluetoothGatt !== gatt) return
            handleCharacteristicChanged(characteristic, value)
        }

        @Deprecated("Android 13 compatibility callback")
        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            if (bluetoothGatt !== gatt) return
            handleCharacteristicRead(characteristic, characteristic.value ?: byteArrayOf(), status)
        }

        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
            status: Int
        ) {
            if (bluetoothGatt !== gatt) return
            handleCharacteristicRead(characteristic, value, status)
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            if (bluetoothGatt !== gatt || characteristic.uuid != commandUuid) return
            demoWriteTimeout?.let(mainHandler::removeCallbacks)
            demoWriteTimeout = null
            val result = pendingWriteResult ?: return
            pendingWriteResult = null
            post {
                if (status == BluetoothGatt.GATT_SUCCESS) result.success(true)
                else result.error("ble-write-failed", "BLE command write failed ($status).", null)
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun discoverServices(gatt: BluetoothGatt) {
        if (!gatt.discoverServices()) {
            emitError("Android rejected Nudge BLE service discovery.")
            disconnectGatt()
        }
    }

    private fun handleCharacteristicChanged(
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray
    ) {
        if (characteristic.uuid != stateUuid) return
        emit(
            mapOf(
                "type" to "state",
                "deviceId" to connectedDeviceId,
                "payload" to value.toString(StandardCharsets.UTF_8)
            )
        )
    }

    private fun handleCharacteristicRead(
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray,
        status: Int
    ) {
        if (characteristic.uuid == stateUuid) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                handleCharacteristicChanged(characteristic, value)
            }
            return
        }
        if (characteristic.uuid != EVENT_UUID) return
        val result = pendingReadResult ?: return
        pendingReadResult = null
        post {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                result.success(value.toString(StandardCharsets.UTF_8))
            } else {
                result.error("ble-read-failed", "BLE event read failed ($status).", null)
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun readState(gatt: BluetoothGatt) {
        stateCharacteristic?.let(gatt::readCharacteristic)
    }

    @SuppressLint("MissingPermission")
    private fun readPendingEvent(result: MethodChannel.Result) {
        val gatt = bluetoothGatt
        val characteristic = eventCharacteristic
        if (gatt == null || characteristic == null) {
            result.error("ble-not-connected", "No Nudge device is connected.", null)
            return
        }
        if (pendingReadResult != null) {
            result.error("ble-busy", "A BLE event read is already active.", null)
            return
        }
        pendingReadResult = result
        if (!gatt.readCharacteristic(characteristic)) {
            pendingReadResult = null
            result.error("ble-read-failed", "Android rejected the BLE event read.", null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun writeCommand(call: MethodCall, result: MethodChannel.Result) {
        val commandJson = call.argument<String>("commandJson")
        val bytes = commandJson?.toByteArray(StandardCharsets.UTF_8)
        val gatt = bluetoothGatt
        val characteristic = commandCharacteristic
        val maxPayloadBytes = minOf(if (demoMode) 96 else MAX_COMMAND_BYTES, negotiatedMtu - ATT_HEADER_BYTES)
        if (bytes == null || bytes.isEmpty() || bytes.size > maxPayloadBytes) {
            result.error(
                "ble-command-invalid",
                "BLE command is empty or exceeds the negotiated $maxPayloadBytes-byte payload.",
                null
            )
            return
        }
        if (demoMode && !validDemoCommand(commandJson)) {
            result.error("ble-demo-command", "Only v1 Demo actions are accepted.", null)
            return
        }
        if (gatt == null || characteristic == null) {
            result.error("ble-not-connected", "No Nudge device is connected.", null)
            return
        }
        if (pendingWriteResult != null) {
            result.error("ble-busy", "A BLE command write is already active.", null)
            return
        }
        pendingWriteResult = result
        if (demoMode) {
            val timeout = Runnable {
                val pending = pendingWriteResult
                pendingWriteResult = null
                pending?.error("ble-write-timeout", "改用裝置自動展示", null)
                disconnectGatt()
            }
            demoWriteTimeout = timeout
            mainHandler.postDelayed(timeout, 8_000L)
        }
        val accepted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            gatt.writeCharacteristic(
                characteristic,
                bytes,
                BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            ) == BluetoothGatt.GATT_SUCCESS
        } else {
            characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            characteristic.value = bytes
            gatt.writeCharacteristic(characteristic)
        }
        if (!accepted) {
            demoWriteTimeout?.let(mainHandler::removeCallbacks)
            demoWriteTimeout = null
            pendingWriteResult = null
            result.error("ble-write-failed", "Android rejected the BLE command write.", null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun writeDescriptor(
        gatt: BluetoothGatt,
        descriptor: BluetoothGattDescriptor
    ): Boolean = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        gatt.writeDescriptor(
            descriptor,
            BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        ) == BluetoothGatt.GATT_SUCCESS
    } else {
        descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        gatt.writeDescriptor(descriptor)
    }

    @SuppressLint("MissingPermission")
    private fun disconnectGatt() {
        pendingScanResult?.error("ble-cancelled", "BLE permission request cancelled.", null)
        pendingScanResult = null
        stopScan()
        bluetoothGatt?.disconnect()
        clearGatt(bluetoothGatt)
    }

    private fun clearGatt(gatt: BluetoothGatt?) {
        if (gatt != null && bluetoothGatt !== gatt) return
        demoTimeout?.let(mainHandler::removeCallbacks); demoTimeout = null
        demoWriteTimeout?.let(mainHandler::removeCallbacks); demoWriteTimeout = null
        bluetoothGatt = null
        commandCharacteristic = null
        stateCharacteristic = null
        eventCharacteristic = null
        connectedDeviceId = null
        negotiatedMtu = 23
        pendingReadResult?.error("ble-disconnected", "Nudge device disconnected.", null)
        pendingWriteResult?.error("ble-disconnected", "Nudge device disconnected.", null)
        pendingReadResult = null
        pendingWriteResult = null
        gatt?.close()
    }

    private fun validDemoCommand(raw: String?): Boolean = try {
        val json = JSONObject(raw ?: "")
        val keys = json.keys().asSequence().toSet()
        keys == setOf("v", "type", "action") && json.opt("v") is Int &&
            json.getInt("v") == 1 && json.opt("type") == "demo" &&
            DemoBleSpec.actions.any { it == json.opt("action") }
    } catch (_: Exception) { false }

    private fun emit(event: Map<String, Any?>) {
        val epoch = demoEpoch
        post { if (!demoMode || epoch == demoEpoch) eventSink?.success(event) }
    }

    private fun emitError(message: String) = emit(mapOf("type" to "error", "message" to message))

    private fun post(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block() else mainHandler.post(block)
    }

    fun close() {
        disconnectGatt()
        pendingScanResult?.error("ble-closed", "BLE controller closed.", null)
        pendingScanResult = null
        eventSink = null
    }
}
