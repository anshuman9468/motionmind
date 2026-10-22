package com.skillverse.skillverse_ai

import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.SystemClock
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL_NAME = "com.skillverse.ai/vision_tracking"
        private const val POSE_MODEL_ASSET = "pose_landmarker_lite.task"
        private const val QUALITY_MODEL_ASSET = "motionmind_quality.tflite"

        private val jointIndexes = mapOf(
            "head" to 0,
            "leftShoulder" to 11,
            "rightShoulder" to 12,
            "leftElbow" to 13,
            "rightElbow" to 14,
            "leftWrist" to 15,
            "rightWrist" to 16,
            "leftHip" to 23,
            "rightHip" to 24,
            "leftKnee" to 25,
            "rightKnee" to 26,
            "leftAnkle" to 27,
            "rightAnkle" to 28,
        )
    }

    private data class CameraPlane(
        val bytes: ByteArray,
        val bytesPerRow: Int,
        val bytesPerPixel: Int,
    )

    private lateinit var channel: MethodChannel
    private val inferenceExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var poseLandmarker: PoseLandmarker? = null
    private var qualityInterpreter: Interpreter? = null
    private var previousHipCenter: Pair<Float, Float>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initializePoseLandmarker" -> initializeModels(result)
                "processCameraFrame" -> processCameraFrame(call, result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        channel.setMethodCallHandler(null)
        inferenceExecutor.shutdown()
        poseLandmarker?.close()
        qualityInterpreter?.close()
        super.onDestroy()
    }

    private fun initializeModels(result: MethodChannel.Result) {
        inferenceExecutor.execute {
            try {
                poseLandmarker?.close()
                qualityInterpreter?.close()

                val poseOptions = PoseLandmarker.PoseLandmarkerOptions.builder()
                    .setBaseOptions(
                        BaseOptions.builder()
                            .setModelAssetPath(POSE_MODEL_ASSET)
                            .build(),
                    )
                    .setRunningMode(RunningMode.IMAGE)
                    .setNumPoses(1)
                    .setMinPoseDetectionConfidence(0.55f)
                    .setMinPosePresenceConfidence(0.55f)
                    .setMinTrackingConfidence(0.55f)
                    .build()

                poseLandmarker = PoseLandmarker.createFromOptions(applicationContext, poseOptions)
                qualityInterpreter = try {
                    Interpreter(loadAssetBuffer(QUALITY_MODEL_ASSET))
                } catch (qualityError: Exception) {
                    // Pose tracking remains useful when the optional quality model
                    // is unavailable or contains an unsupported operator.
                    Log.w("SkillVerseAI", "Optional quality model unavailable", qualityError)
                    null
                }
                previousHipCenter = null
                runOnUiThread { result.success(mapOf("ready" to true)) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("MODEL_INITIALIZATION_FAILED", error.message, null)
                }
            }
        }
    }

    private fun processCameraFrame(call: MethodCall, result: MethodChannel.Result) {
        val width = call.argument<Int>("width")
        val height = call.argument<Int>("height")
        val rotationDegrees = call.argument<Int>("rotationDegrees") ?: 0
        val cameraFacing = call.argument<String>("cameraFacing") ?: "unknown"
        val qualitySkillId = call.argument<Int>("qualitySkillId") ?: 0
        val rawPlanes = call.argument<List<*>>("planes")

        if (width == null || height == null || rawPlanes == null) {
            result.error("INVALID_FRAME", "A YUV camera frame is required.", null)
            return
        }
        if (width <= 0 || height <= 0 || width > 4096 || height > 4096) {
            result.error("INVALID_FRAME", "Camera frame dimensions are invalid.", null)
            return
        }
        if (poseLandmarker == null) {
            result.error("MODELS_NOT_READY", "Pose model is not initialized.", null)
            return
        }

        inferenceExecutor.execute {
            try {
                val planes = readPlanes(rawPlanes)
                val bitmap = rotateBitmap(yuv420ToBitmap(width, height, planes), rotationDegrees)
                val poseResult = poseLandmarker!!.detect(BitmapImageBuilder(bitmap).build())
                val payload = posePayload(
                    poseResult.landmarks(),
                    bitmap.width,
                    bitmap.height,
                    cameraFacing,
                    qualitySkillId,
                )
                runOnUiThread { result.success(payload) }
            } catch (error: Exception) {
                Log.e("SkillVerseAI", "Pose frame inference failed", error)
                runOnUiThread { result.error("POSE_INFERENCE_FAILED", error.message, null) }
            }
        }
    }

    private fun posePayload(
        poses: List<List<NormalizedLandmark>>,
        frameWidth: Int,
        frameHeight: Int,
        cameraFacing: String,
        qualitySkillId: Int,
    ): Map<String, Any> {
        if (poses.isEmpty() || poses.first().size != 33) {
            return mapOf(
                "humanDetected" to false,
                "trackingState" to "SEARCHING_FOR_HUMAN",
                "trackingConfidence" to 0.0,
                "multiplePeopleCount" to poses.size,
                "selectedPersonId" to "primary_user_1",
                "joints" to emptyMap<String, Any>(),
                "landmarks" to emptyList<Map<String, Any>>(),
                "frameWidth" to frameWidth,
                "frameHeight" to frameHeight,
                "timestampUs" to (SystemClock.elapsedRealtimeNanos() / 1_000L),
            )
        }

        val points = poses.first()
        val averageVisibility = points.map { it.visibility().orElse(0f) }.average().toFloat()
        val landmarks = points.map { point ->
            mapOf(
                "x" to point.x().toDouble(),
                "y" to point.y().toDouble(),
                "z" to point.z().toDouble(),
                "visibility" to point.visibility().orElse(0f).toDouble(),
                "presence" to point.presence().orElse(0f).toDouble(),
            )
        }
        val joints = jointIndexes.mapValues { (_, index) -> pointToJoint(points[index]) }.toMutableMap()
        joints["neck"] = midpoint(points[11], points[12])
        joints["spine"] = midpoint(points[11], points[12], points[23], points[24])

        val qualityScore = qualityInterpreter?.let {
            try {
                runQualityModel(points, qualitySkillId)
            } catch (qualityError: Exception) {
                Log.w("SkillVerseAI", "Optional quality inference failed", qualityError)
                null
            }
        }
        val payload = mutableMapOf<String, Any>(
            "humanDetected" to true,
            "trackingState" to if (averageVisibility >= 0.55f) "HUMAN_LOCKED" else "BODY_NOT_CLEAR",
            "trackingConfidence" to averageVisibility.toDouble(),
            "multiplePeopleCount" to poses.size,
            "selectedPersonId" to "primary_user_1",
            "joints" to joints,
            "landmarks" to landmarks,
            "frameWidth" to frameWidth,
            "frameHeight" to frameHeight,
            "timestampUs" to (SystemClock.elapsedRealtimeNanos() / 1_000L),
        )
        if (qualityScore != null) {
            payload["onDeviceQualityScore"] = qualityScore.toDouble()
        }
        return payload
    }

    private fun pointToJoint(point: NormalizedLandmark): Map<String, Double> = mapOf(
        "x" to point.x().toDouble(),
        "y" to point.y().toDouble(),
        "z" to point.z().toDouble(),
        "confidence" to point.visibility().orElse(0f).toDouble(),
    )

    private fun midpoint(vararg points: NormalizedLandmark): Map<String, Double> {
        val size = points.size.toDouble()
        return mapOf(
            "x" to points.sumOf { it.x().toDouble() } / size,
            "y" to points.sumOf { it.y().toDouble() } / size,
            "z" to points.sumOf { it.z().toDouble() } / size,
            "confidence" to points.sumOf { it.visibility().orElse(0f).toDouble() } / size,
        )
    }

    private fun runQualityModel(points: List<NormalizedLandmark>, skillId: Int): Float {
        val features = qualityFeatures(points)
        // motionmind_quality.tflite exposes quality_score with shape [1].
        val output = FloatArray(1)
        qualityInterpreter!!.runForMultipleInputsOutputs(
            arrayOf<Any>(arrayOf(features), intArrayOf(skillId.coerceIn(0, 4))),
            mutableMapOf<Int, Any>(0 to output),
        )
        val rawScore = output[0]
        val normalizedScore = if (rawScore in 0f..1f) rawScore * 100f else rawScore
        return normalizedScore.coerceIn(0f, 100f)
    }

    /**
     * The quality model accepts the eight portable MotionMind dimensions in
     * 0..100 order. These are derived only from landmarks, never camera pixels.
     */
    private fun qualityFeatures(points: List<NormalizedLandmark>): FloatArray {
        val leftShoulder = points[11]
        val rightShoulder = points[12]
        val leftElbow = points[13]
        val rightElbow = points[14]
        val leftWrist = points[15]
        val rightWrist = points[16]
        val leftHip = points[23]
        val rightHip = points[24]
        val leftKnee = points[25]
        val rightKnee = points[26]
        val leftAnkle = points[27]
        val rightAnkle = points[28]

        val shoulderTilt = abs(leftShoulder.y() - rightShoulder.y())
        val hipTilt = abs(leftHip.y() - rightHip.y())
        val alignment = (100f - (shoulderTilt + hipTilt) * 220f).coerceIn(0f, 100f)
        val leftKneeAngle = angle(leftHip, leftKnee, leftAnkle)
        val rightKneeAngle = angle(rightHip, rightKnee, rightAnkle)
        val leftElbowAngle = angle(leftShoulder, leftElbow, leftWrist)
        val rightElbowAngle = angle(rightShoulder, rightElbow, rightWrist)
        val rangeOfMotion = ((leftKneeAngle + rightKneeAngle) / 3.6f).coerceIn(0f, 100f)
        val shoulderMid = midpointOf(leftShoulder, rightShoulder)
        val hipMid = midpointOf(leftHip, rightHip)
        val posture = (100f - abs(shoulderMid.first - hipMid.first) * 260f).coerceIn(0f, 100f)
        val symmetry = (100f - abs(leftKneeAngle - rightKneeAngle) * 1.2f).coerceIn(0f, 100f)
        val drift = previousHipCenter?.let {
            sqrt((it.first - hipMid.first) * (it.first - hipMid.first) + (it.second - hipMid.second) * (it.second - hipMid.second))
        } ?: 0f
        previousHipCenter = hipMid
        val stability = (100f - drift * 900f).coerceIn(0f, 100f)
        val control = (points.map { it.visibility().orElse(0f) }.average() * 100.0).toFloat().coerceIn(0f, 100f)
        val extension = ((leftElbowAngle + rightElbowAngle) / 3.6f).coerceIn(0f, 100f)
        val timing = ((stability + control) / 2f).coerceIn(0f, 100f)
        return floatArrayOf(alignment, rangeOfMotion, posture, symmetry, stability, control, extension, timing)
    }

    private fun angle(a: NormalizedLandmark, b: NormalizedLandmark, c: NormalizedLandmark): Float {
        val abX = a.x() - b.x()
        val abY = a.y() - b.y()
        val bcX = c.x() - b.x()
        val bcY = c.y() - b.y()
        val denominator = sqrt(abX * abX + abY * abY) * sqrt(bcX * bcX + bcY * bcY)
        if (denominator <= 0.00001f) return 180f
        val cosine = ((abX * bcX + abY * bcY) / denominator).coerceIn(-1f, 1f)
        return Math.toDegrees(kotlin.math.acos(cosine.toDouble())).toFloat()
    }

    private fun midpointOf(a: NormalizedLandmark, b: NormalizedLandmark): Pair<Float, Float> =
        Pair((a.x() + b.x()) / 2f, (a.y() + b.y()) / 2f)

    private fun readPlanes(rawPlanes: List<*>): List<CameraPlane> {
        require(rawPlanes.size >= 3) { "YUV_420_888 needs three image planes." }
        return rawPlanes.take(3).map { rawPlane ->
            val plane = rawPlane as? Map<*, *> ?: error("Invalid image plane.")
            val bytes = when (val encoded = plane["bytes"]) {
                is ByteArray -> encoded
                // StandardMessageCodec normally returns ByteArray for Uint8List,
                // but accepting a numeric list keeps this bridge compatible with
                // CameraX implementations that serialize planes differently.
                is List<*> -> ByteArray(encoded.size) { index ->
                    (encoded[index] as? Number)?.toInt()?.and(0xff)
                        ?.toByte() ?: 0
                }
                else -> error("Image plane bytes are missing.")
            }
            CameraPlane(
                bytes = bytes,
                bytesPerRow = (plane["bytesPerRow"] as? Number)?.toInt() ?: 0,
                bytesPerPixel = (plane["bytesPerPixel"] as? Number)?.toInt() ?: 1,
            )
        }
    }

    private fun yuv420ToBitmap(width: Int, height: Int, planes: List<CameraPlane>): Bitmap {
        val yPlane = planes[0]
        val uPlane = planes[1]
        val vPlane = planes[2]
        val pixels = IntArray(width * height)
        for (y in 0 until height) {
            val uvRow = y shr 1
            for (x in 0 until width) {
                val yIndex = y * yPlane.bytesPerRow + x * yPlane.bytesPerPixel
                val uvColumn = x shr 1
                val uIndex = uvRow * uPlane.bytesPerRow + uvColumn * uPlane.bytesPerPixel
                val vIndex = uvRow * vPlane.bytesPerRow + uvColumn * vPlane.bytesPerPixel
                val yValue = samplePlane(yPlane.bytes, yIndex, 16)
                val uValue = samplePlane(uPlane.bytes, uIndex, 128)
                val vValue = samplePlane(vPlane.bytes, vIndex, 128)
                pixels[y * width + x] = yuvToArgb(yValue, uValue, vValue)
            }
        }
        return Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888)
    }

    private fun samplePlane(bytes: ByteArray, index: Int, fallback: Int): Int {
        return if (index in bytes.indices) bytes[index].toInt() and 0xff else fallback
    }

    private fun yuvToArgb(y: Int, u: Int, v: Int): Int {
        val c = max(0, y - 16)
        val d = u - 128
        val e = v - 128
        val red = min(255, max(0, (298 * c + 409 * e + 128) shr 8))
        val green = min(255, max(0, (298 * c - 100 * d - 208 * e + 128) shr 8))
        val blue = min(255, max(0, (298 * c + 516 * d + 128) shr 8))
        return (0xff shl 24) or (red shl 16) or (green shl 8) or blue
    }

    private fun rotateBitmap(bitmap: Bitmap, rotationDegrees: Int): Bitmap {
        val normalizedRotation = ((rotationDegrees % 360) + 360) % 360
        if (normalizedRotation == 0) return bitmap
        val matrix = Matrix().apply { postRotate(normalizedRotation.toFloat()) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    private fun loadAssetBuffer(name: String): ByteBuffer {
        assets.open(name).use { stream ->
            val bytes = stream.readBytes()
            return ByteBuffer.allocateDirect(bytes.size)
                .order(ByteOrder.nativeOrder())
                .apply {
                    put(bytes)
                    rewind()
                }
        }
    }
}
