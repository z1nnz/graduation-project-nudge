package com.example.nudge

import android.os.Bundle
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.Instant
import java.time.ZonedDateTime

class MainActivity : FlutterActivity() {
    private val channelName = "nudge/healthkit"
    private val healthPermissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(SleepSessionRecord::class),
        HealthPermission.getReadPermission(ExerciseSessionRecord::class)
    )

    private lateinit var permissionLauncher: ActivityResultLauncher<Set<String>>
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        permissionLauncher = registerForActivityResult(
            PermissionController.createRequestPermissionResultContract()
        ) { granted ->
            val result = pendingPermissionResult ?: return@registerForActivityResult
            pendingPermissionResult = null
            result.success(granted.containsAll(healthPermissions))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestHealthAuthorization" -> requestHealthAuthorization(result)
                "getHealthData" -> getHealthData(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun requestHealthAuthorization(result: MethodChannel.Result) {
        val availability = HealthConnectClient.getSdkStatus(this)
        if (availability != HealthConnectClient.SDK_AVAILABLE) {
            result.success(false)
            return
        }

        CoroutineScope(Dispatchers.Main).launch {
            try {
                val client = HealthConnectClient.getOrCreate(this@MainActivity)
                val granted = client.permissionController.getGrantedPermissions()
                if (granted.containsAll(healthPermissions)) {
                    result.success(true)
                    return@launch
                }

                pendingPermissionResult = result
                permissionLauncher.launch(healthPermissions)
            } catch (error: Exception) {
                pendingPermissionResult = null
                result.success(false)
            }
        }
    }

    private fun getHealthData(result: MethodChannel.Result) {
        val availability = HealthConnectClient.getSdkStatus(this)
        if (availability != HealthConnectClient.SDK_AVAILABLE) {
            result.success(
                mapOf(
                    "success" to false,
                    "message" to "Health Connect unavailable",
                    "sleepHours" to 0.0,
                    "steps" to 0,
                    "exerciseMinutes" to 0
                )
            )
            return
        }

        CoroutineScope(Dispatchers.Main).launch {
            try {
                val client = HealthConnectClient.getOrCreate(this@MainActivity)
                val granted = client.permissionController.getGrantedPermissions()
                if (!granted.containsAll(healthPermissions)) {
                    result.success(
                        mapOf(
                            "success" to false,
                            "message" to "Health Connect permission not granted",
                            "sleepHours" to 0.0,
                            "steps" to 0,
                            "exerciseMinutes" to 0
                        )
                    )
                    return@launch
                }

                val end = ZonedDateTime.now()
                val start = end.toLocalDate().atStartOfDay(end.zone)
                val range = TimeRangeFilter.between(start.toInstant(), end.toInstant())
                val sleepRange = TimeRangeFilter.between(
                    start.minusHours(12).toInstant(),
                    end.toInstant()
                )

                val steps = readSteps(client, range)
                val sleepHours = readSleepHours(
                    client = client,
                    range = sleepRange,
                    dayStart = start.toInstant(),
                    end = end.toInstant()
                )
                val exerciseMinutes = readExerciseMinutes(client, range)

                result.success(
                    mapOf(
                        "success" to true,
                        "message" to "已同步 Health Connect 資料",
                        "sleepHours" to sleepHours,
                        "steps" to steps,
                        "exerciseMinutes" to exerciseMinutes
                    )
                )
            } catch (error: Exception) {
                result.success(
                    mapOf(
                        "success" to false,
                        "message" to "同步失敗：${error.message ?: error.javaClass.simpleName}",
                        "sleepHours" to 0.0,
                        "steps" to 0,
                        "exerciseMinutes" to 0
                    )
                )
            }
        }
    }

    private suspend fun readSteps(
        client: HealthConnectClient,
        range: TimeRangeFilter
    ): Int {
        val response = client.aggregate(
            AggregateRequest(
                metrics = setOf(StepsRecord.COUNT_TOTAL),
                timeRangeFilter = range
            )
        )
        return (response[StepsRecord.COUNT_TOTAL] ?: 0L).toInt()
    }

    private suspend fun readSleepHours(
        client: HealthConnectClient,
        range: TimeRangeFilter,
        dayStart: Instant,
        end: Instant
    ): Double {
        val response = client.readRecords(
            ReadRecordsRequest(
                SleepSessionRecord::class,
                timeRangeFilter = range
            )
        )
        val totalMinutes = response.records.sumOf { session ->
            val clippedStart = maxOf(session.startTime, dayStart)
            val clippedEnd = minOf(session.endTime, end)
            if (clippedEnd.isAfter(clippedStart)) {
                Duration.between(clippedStart, clippedEnd).toMinutes()
            } else {
                0L
            }
        }
        return totalMinutes / 60.0
    }

    private suspend fun readExerciseMinutes(
        client: HealthConnectClient,
        range: TimeRangeFilter
    ): Int {
        val response = client.readRecords(
            ReadRecordsRequest(
                ExerciseSessionRecord::class,
                timeRangeFilter = range
            )
        )
        val totalMinutes = response.records.sumOf { session ->
            Duration.between(session.startTime, session.endTime).toMinutes()
        }
        return totalMinutes.toInt()
    }
}
