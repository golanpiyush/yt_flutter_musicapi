package com.golanpiyush.yt_flutter_musicapi

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import com.chaquo.python.PyObject
import android.content.Context
import android.util.Log
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.ThreadPoolExecutor

// Data Classes
data class SearchResult(
    val title: String,
    val artists: String,
    val videoId: String,
    val duration: String?,
    val year: String?,
    val albumArt: String?,
    val audioUrl: String?
)

data class RelatedSong(
    val title: String,
    val artists: String,
    val videoId: String,
    val duration: String?,
    val albumArt: String?,
    val audioUrl: String?,
    val isOriginal: Boolean
)

enum class AudioQuality {
    LOW, MED, HIGH, VERY_HIGH
}

enum class ThumbnailQuality {
    LOW, MED, HIGH, VERY_HIGH
}

/** YtFlutterMusicapiPlugin */
class YtFlutterMusicapiPlugin: FlutterPlugin, MethodCallHandler {
    
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var python: Python? = null
    private var pythonModule: PyObject? = null
    private var musicSearcher: PyObject? = null
    private var relatedFetcher: PyObject? = null
    
    // Performance optimizations
    private val coroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val threadPoolExecutor = Executors.newFixedThreadPool(4) as ThreadPoolExecutor
    private val instanceCache = ConcurrentHashMap<String, PyObject>()
    
    companion object {
        private const val TAG = "YTMusicAPI"
        private const val CHANNEL_NAME = "yt_flutter_musicapi"
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        
        // Initialize Python in background
        coroutineScope.launch {
            initializePython()
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            
            "initialize" -> {
                handleInitialize(call, result)
            }
            
            "searchMusic" -> {
                handleSearchMusic(call, result)
            }
            
            "getRelatedSongs" -> {
                handleGetRelatedSongs(call, result)
            }
            
            "dispose" -> {
                handleDispose(result)
            }
            
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun initializePython() {
        try {
            if (!Python.isStarted()) {
                Python.start(AndroidPlatform(context))
            }
            python = Python.getInstance()
            
            // Import the Python module
            pythonModule = python?.getModule("ytmusic_api")
            
            Log.d(TAG, "Python initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Python", e)
        }
    }

    private fun handleInitialize(call: MethodCall, result: Result) {
        coroutineScope.launch {
            try {
                val proxy = call.argument<String>("proxy")
                val country = call.argument<String>("country") ?: "US"
                
                if (pythonModule == null) {
                    initializePython()
                }
                
                // Initialize searcher and related fetcher with caching
                val searcherKey = "searcher_${proxy}_${country}"
                val relatedKey = "related_${proxy}_${country}"
                
                musicSearcher = instanceCache.getOrPut(searcherKey) {
                    if (proxy != null) {
                        pythonModule!!.callAttr("YTMusicSearcher", proxy, country)
                    } else {
                        pythonModule!!.callAttr("YTMusicSearcher", null, country)
                    }
                }
                
                relatedFetcher = instanceCache.getOrPut(relatedKey) {
                    if (proxy != null) {
                        pythonModule!!.callAttr("YTMusicRelatedFetcher", proxy, country)
                    } else {
                        pythonModule!!.callAttr("YTMusicRelatedFetcher", null, country)
                    }
                }
                
                withContext(Dispatchers.Main) {
                    result.success(mapOf(
                        "success" to true,
                        "message" to "YTMusic API initialized successfully"
                    ))
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize YTMusic API", e)
                withContext(Dispatchers.Main) {
                    result.error("INIT_ERROR", "Failed to initialize: ${e.message}", null)
                }
            }
        }
    }

    private fun handleSearchMusic(call: MethodCall, result: Result) {
        coroutineScope.launch {
            try {
                val query = call.argument<String>("query")
                    ?: throw IllegalArgumentException("Query is required")
                
                val limit = call.argument<Int>("limit") ?: 10
                val thumbQuality = call.argument<String>("thumbQuality") ?: "VERY_HIGH"
                val audioQuality = call.argument<String>("audioQuality") ?: "VERY_HIGH"
                val includeAudioUrl = call.argument<Boolean>("includeAudioUrl") ?: true
                val includeAlbumArt = call.argument<Boolean>("includeAlbumArt") ?: true
                
                if (musicSearcher == null) {
                    throw IllegalStateException("YTMusic API not initialized. Call initialize() first.")
                }
                
                // Convert enum strings to Python enum values
                val pythonThumbQuality = getPythonThumbnailQuality(thumbQuality)
                val pythonAudioQuality = getPythonAudioQuality(audioQuality)
                
                // Call Python method
                val searchResults = musicSearcher!!.callAttr(
                    "get_music_details",
                    query,
                    limit,
                    pythonThumbQuality,
                    pythonAudioQuality,
                    includeAudioUrl,
                    includeAlbumArt
                )
                
                val resultList = mutableListOf<Map<String, Any?>>()
                
                // Process generator results
                try {
                    val iterator = searchResults.asIterable()
                    for (item in iterator) {
                        val songData = convertPythonDictToMap(item as PyObject)
                        resultList.add(songData)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error processing search results", e)
                    // Try alternative approach for generator
                    val pyList = python!!.getBuiltins().callAttr("list", searchResults)
                    val size = pyList.callAttr("__len__").toInt()
                    for (i in 0 until size) {
                        val item = pyList.callAttr("__getitem__", i)
                        val songData = convertPythonDictToMap(item)
                        resultList.add(songData)
                    }
                }
                
                withContext(Dispatchers.Main) {
                    result.success(mapOf(
                        "success" to true,
                        "results" to resultList,
                        "count" to resultList.size
                    ))
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Search failed", e)
                withContext(Dispatchers.Main) {
                    result.error("SEARCH_ERROR", "Search failed: ${e.message}", null)
                }
            }
        }
    }

    private fun handleGetRelatedSongs(call: MethodCall, result: Result) {
        coroutineScope.launch {
            try {
                val songName = call.argument<String>("songName")
                    ?: throw IllegalArgumentException("Song name is required")
                
                val artistName = call.argument<String>("artistName")
                    ?: throw IllegalArgumentException("Artist name is required")
                
                val limit = call.argument<Int>("limit") ?: 10
                val thumbQuality = call.argument<String>("thumbQuality") ?: "VERY_HIGH"
                val audioQuality = call.argument<String>("audioQuality") ?: "VERY_HIGH"
                val includeAudioUrl = call.argument<Boolean>("includeAudioUrl") ?: true
                val includeAlbumArt = call.argument<Boolean>("includeAlbumArt") ?: true
                
                if (relatedFetcher == null) {
                    throw IllegalStateException("YTMusic API not initialized. Call initialize() first.")
                }
                
                // Convert enum strings to Python enum values
                val pythonThumbQuality = getPythonThumbnailQuality(thumbQuality)
                val pythonAudioQuality = getPythonAudioQuality(audioQuality)
                
                // Call Python method
                val relatedResults = relatedFetcher!!.callAttr(
                    "getRelated",
                    songName,
                    artistName,
                    limit,
                    pythonThumbQuality,
                    pythonAudioQuality,
                    includeAudioUrl,
                    includeAlbumArt
                )
                
                val resultList = mutableListOf<Map<String, Any?>>()
                
                // Process generator results
                try {
                    val iterator = relatedResults.asIterable()
                    for (item in iterator) {
                        val songData = convertPythonDictToMap(item as PyObject)
                        resultList.add(songData)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error processing related results", e)
                    // Try alternative approach for generator
                    val pyList = python!!.getBuiltins().callAttr("list", relatedResults)
                    val size = pyList.callAttr("__len__").toInt()
                    for (i in 0 until size) {
                        val item = pyList.callAttr("__getitem__", i)
                        val songData = convertPythonDictToMap(item)
                        resultList.add(songData)
                    }
                }
                
                withContext(Dispatchers.Main) {
                    result.success(mapOf(
                        "success" to true,
                        "results" to resultList,
                        "count" to resultList.size
                    ))
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Get related songs failed", e)
                withContext(Dispatchers.Main) {
                    result.error("RELATED_ERROR", "Get related songs failed: ${e.message}", null)
                }
            }
        }
    }

    private fun handleDispose(result: Result) {
        try {
            // Clean up resources
            coroutineScope.cancel()
            instanceCache.clear()
            threadPoolExecutor.shutdown()
            
            musicSearcher = null
            relatedFetcher = null
            pythonModule = null
            
            result.success(mapOf(
                "success" to true,
                "message" to "Resources disposed successfully"
            ))
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to dispose resources", e)
            result.error("DISPOSE_ERROR", "Failed to dispose: ${e.message}", null)
        }
    }

    private fun getPythonThumbnailQuality(quality: String): PyObject {
        val thumbnailQualityEnum = pythonModule!!.callAttr("__getattribute__", "ThumbnailQuality")
        return when (quality.uppercase()) {
            "LOW" -> thumbnailQualityEnum.callAttr("__getattribute__", "LOW")
            "MED" -> thumbnailQualityEnum.callAttr("__getattribute__", "MED")
            "HIGH" -> thumbnailQualityEnum.callAttr("__getattribute__", "HIGH")
            "VERY_HIGH" -> thumbnailQualityEnum.callAttr("__getattribute__", "VERY_HIGH")
            else -> thumbnailQualityEnum.callAttr("__getattribute__", "VERY_HIGH")
        }
    }

    private fun getPythonAudioQuality(quality: String): PyObject {
        val audioQualityEnum = pythonModule!!.callAttr("__getattribute__", "AudioQuality")
        return when (quality.uppercase()) {
            "LOW" -> audioQualityEnum.callAttr("__getattribute__", "LOW")
            "MED" -> audioQualityEnum.callAttr("__getattribute__", "MED")
            "HIGH" -> audioQualityEnum.callAttr("__getattribute__", "HIGH")
            "VERY_HIGH" -> audioQualityEnum.callAttr("__getattribute__", "VERY_HIGH")
            else -> audioQualityEnum.callAttr("__getattribute__", "VERY_HIGH")
        }
    }

    private fun convertPythonDictToMap(pythonDict: PyObject): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        
        try {
            // Convert Python dict to Kotlin map - use items() method for proper iteration
            val items = pythonDict.callAttr("items")
            val itemsList = python!!.getBuiltins().callAttr("list", items)
            val size = itemsList.callAttr("__len__").toInt()
            
            for (i in 0 until size) {
                val pair = itemsList.callAttr("__getitem__", i)
                val key = pair.callAttr("__getitem__", 0).toString()
                val value = pair.callAttr("__getitem__", 1)
                
                map[key] = when {
                    value == null -> null
                    value.toString() == "None" -> null
                    else -> value.toString()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to convert Python dict to map", e)
            // Fallback method - try direct key access
            try {
                val keys = listOf("title", "artists", "videoId", "duration", "year", "albumArt", "audioUrl", "isOriginal")
                for (key in keys) {
                    try {
                        val value = pythonDict.callAttr("__getitem__", key)
                        map[key] = when {
                            value == null -> null
                            value.toString() == "None" -> null
                            else -> value.toString()
                        }
                    } catch (keyError: Exception) {
                        // Key doesn't exist, skip
                    }
                }
            } catch (fallbackError: Exception) {
                Log.e(TAG, "Fallback conversion also failed", fallbackError)
            }
        }
        
        return map
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        
        // Clean up resources
        try {
            coroutineScope.cancel()
            instanceCache.clear()
            threadPoolExecutor.shutdown()
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup", e)
        }
    }
}

/*
// Test Usage Examples (commented out for production)

// Initialize
val initParams = mapOf(
    "proxy" to null, // or "http://proxy:port"
    "country" to "US"
)

// Search Music
val searchParams = mapOf(
    "query" to "Gale Lag Ja",
    "limit" to 10,
    "thumbQuality" to "VERY_HIGH",
    "audioQuality" to "VERY_HIGH",
    "includeAudioUrl" to true,
    "includeAlbumArt" to true
)

// Get Related Songs
val relatedParams = mapOf(
    "songName" to "Viva La Vida",
    "artistName" to "Coldplay",
    "limit" to 10,
    "thumbQuality" to "VERY_HIGH",
    "audioQuality" to "VERY_HIGH",
    "includeAudioUrl" to true,
    "includeAlbumArt" to true
)

// Example Flutter Integration:
/*
class _MyAppState extends State<MyApp> {
  static const platform = MethodChannel('yt_flutter_musicapi');

  Future<void> initializeYTMusic() async {
    try {
      final result = await platform.invokeMethod('initialize', {
        'proxy': null,
        'country': 'US',
      });
      print('Initialization: $result');
    } catch (e) {
      print('Failed to initialize: $e');
    }
  }

  Future<void> searchMusic() async {
    try {
      final result = await platform.invokeMethod('searchMusic', {
        'query': 'Gale Lag Ja',
        'limit': 10,
        'thumbQuality': 'VERY_HIGH',
        'audioQuality': 'VERY_HIGH',
        'includeAudioUrl': true,
        'includeAlbumArt': true,
      });
      print('Search results: $result');
    } catch (e) {
      print('Search failed: $e');
    }
  }

  Future<void> getRelatedSongs() async {
    try {
      final result = await platform.invokeMethod('getRelatedSongs', {
        'songName': 'Viva La Vida',
        'artistName': 'Coldplay',
        'limit': 10,
        'thumbQuality': 'VERY_HIGH',
        'audioQuality': 'VERY_HIGH',
        'includeAudioUrl': true,
        'includeAlbumArt': true,
      });
      print('Related songs: $result');
    } catch (e) {
      print('Get related songs failed: $e');
    }
  }
}
*/
