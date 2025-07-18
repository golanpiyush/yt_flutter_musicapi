package com.golanpiyush.yt_flutter_musicapi

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.*
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import com.chaquo.python.PyObject
import android.content.Context
import android.util.Log
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.ThreadPoolExecutor
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken



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

// Data class for lyrics line
data class LyricsLine(
    val timestamp: Long,  // in milliseconds
    val text: String,
    val timeFormatted: String
)

// Data class for lyrics response
data class LyricsResponse(
    val success: Boolean,
    val lyrics: List<LyricsLine>?,
    val source: String?,
    val totalLines: Int?,
    val error: String?
)

/** YtFlutterMusicapiPlugin */
class YtFlutterMusicapiPlugin: FlutterPlugin, MethodCallHandler {
    
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var python: Python? = null
    private var pythonModule: PyObject? = null
    private var musicSearcher: PyObject? = null
    private var relatedFetcher: PyObject? = null
    
    // Event Channels
    private lateinit var searchStreamChannel: EventChannel
    private lateinit var relatedSongsStreamChannel: EventChannel
    private lateinit var artistSongsStreamChannel: EventChannel
    
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

        // Initialize all event channels
        searchStreamChannel = EventChannel(flutterPluginBinding.binaryMessenger, "yt_flutter_musicapi/searchStream")
        relatedSongsStreamChannel = EventChannel(flutterPluginBinding.binaryMessenger, "yt_flutter_musicapi/relatedSongsStream")
        artistSongsStreamChannel = EventChannel(flutterPluginBinding.binaryMessenger, "yt_flutter_musicapi/artistSongsStream")

        // Set up stream handlers
        searchStreamChannel.setStreamHandler(SearchStreamHandler())
        relatedSongsStreamChannel.setStreamHandler(RelatedSongsStreamHandler())
        artistSongsStreamChannel.setStreamHandler(ArtistSongsStreamHandler())
    }

    inner class SearchStreamHandler : EventChannel.StreamHandler {
        private var eventSink: EventChannel.EventSink? = null
        private var job: Job? = null

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
            job = coroutineScope.launch {
                try {
                    val args = arguments as? Map<*, *> ?: throw IllegalArgumentException("Invalid arguments format")
                    val query = args["query"] as? String ?: throw IllegalArgumentException("Query is required")
                    val limit = args["limit"] as? Int ?: 10
                    val thumbQuality = args["thumbQuality"] as? String ?: "HIGH"
                    val audioQuality = args["audioQuality"] as? String ?: "HIGH"
                    val includeAudioUrl = args["includeAudioUrl"] as? Boolean ?: true
                    val includeAlbumArt = args["includeAlbumArt"] as? Boolean ?: true

                    if (musicSearcher == null) {
                        throw IllegalStateException("Music searcher not initialized")
                    }

                    val generator = musicSearcher!!.callAttr(
                        "get_music_details",
                        query,
                        limit,
                        getPythonThumbnailQuality(thumbQuality),
                        getPythonAudioQuality(audioQuality),
                        includeAudioUrl,
                        includeAlbumArt
                    )

                    var itemCount = 0
                    val iterator = generator.callAttr("__iter__")

                    while (isActive && itemCount < limit) {
                        try {
                            val item = iterator.callAttr("__next__")
                            val songData = convertPythonDictToMap(item)
                            
                            val result = mapOf(
                                "title" to (songData["title"]?.toString() ?: "Unknown"),
                                "artists" to (songData["artists"]?.toString() ?: "Unknown"),
                                "videoId" to (songData["videoId"]?.toString() ?: ""),
                                "duration" to songData["duration"]?.toString(),
                                "year" to songData["year"]?.toString(),
                                "albumArt" to songData["albumArt"]?.toString(),
                                "audioUrl" to songData["audioUrl"]?.toString()
                            )
                            
                            withContext(Dispatchers.Main) {
                                events?.success(result)
                            }
                            
                            itemCount++
                            delay(50)
                            
                        } catch (e: Exception) {
                            if (e.message?.contains("StopIteration") == true) break
                            Log.e(TAG, "Error processing search result", e)
                        }
                    }

                    withContext(Dispatchers.Main) {
                        events?.endOfStream()
                    }
                    
                } catch (e: Exception) {
                    Log.e(TAG, "Search stream error", e)
                    withContext(Dispatchers.Main) {
                        events?.error("STREAM_ERROR", e.message, null)
                    }
                }
            }
        }

        override fun onCancel(arguments: Any?) {
            job?.cancel()
            eventSink = null
        }
    }

    inner class RelatedSongsStreamHandler : EventChannel.StreamHandler {
        private var eventSink: EventChannel.EventSink? = null
        private var job: Job? = null

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
            job = coroutineScope.launch {
                try {
                    val args = arguments as? Map<*, *> ?: throw IllegalArgumentException("Invalid arguments format")
                    val songName = args["songName"] as? String ?: throw IllegalArgumentException("Song name is required")
                    val artistName = args["artistName"] as? String ?: throw IllegalArgumentException("Artist name is required")
                    val limit = args["limit"] as? Int ?: 10
                    val thumbQuality = args["thumbQuality"] as? String ?: "HIGH"
                    val audioQuality = args["audioQuality"] as? String ?: "HIGH"
                    val includeAudioUrl = args["includeAudioUrl"] as? Boolean ?: true
                    val includeAlbumArt = args["includeAlbumArt"] as? Boolean ?: true

                    if (relatedFetcher == null) {
                        throw IllegalStateException("Related fetcher not initialized")
                    }

                    val generator = relatedFetcher!!.callAttr(
                        "getRelated",
                        songName,
                        artistName,
                        limit,
                        getPythonThumbnailQuality(thumbQuality),
                        getPythonAudioQuality(audioQuality),
                        includeAudioUrl,
                        includeAlbumArt
                    )

                    var itemCount = 0
                    val iterator = generator.callAttr("__iter__")

                    while (isActive && itemCount < limit) {
                        try {
                            val item = iterator.callAttr("__next__")
                            val songData = convertPythonDictToMap(item)
                            
                            val result = mapOf(
                                "title" to (songData["title"]?.toString() ?: "Unknown"),
                                "artists" to (songData["artists"]?.toString() ?: "Unknown"),
                                "videoId" to (songData["videoId"]?.toString() ?: ""),
                                "duration" to songData["duration"]?.toString(),
                                "albumArt" to songData["albumArt"]?.toString(),
                                "audioUrl" to songData["audioUrl"]?.toString(),
                                "isOriginal" to songData["isOriginal"]?.toString().toBoolean()
                            )
                            
                            withContext(Dispatchers.Main) {
                                events?.success(result)
                            }
                            
                            itemCount++
                            delay(50)
                            
                        } catch (e: Exception) {
                            if (e.message?.contains("StopIteration") == true) break
                            Log.e(TAG, "Error processing related song", e)
                        }
                    }

                    withContext(Dispatchers.Main) {
                        events?.endOfStream()
                    }
                    
                } catch (e: Exception) {
                    Log.e(TAG, "Related songs stream error", e)
                    withContext(Dispatchers.Main) {
                        events?.error("STREAM_ERROR", e.message, null)
                    }
                }
            }
        }

        override fun onCancel(arguments: Any?) {
            job?.cancel()
            eventSink = null
        }
    }

    inner class ArtistSongsStreamHandler : EventChannel.StreamHandler {
        private var eventSink: EventChannel.EventSink? = null
        private var job: Job? = null

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
            job = coroutineScope.launch {
                try {
                    val args = arguments as? Map<*, *> ?: throw IllegalArgumentException("Invalid arguments format")
                    val artistName = args["artistName"] as? String ?: throw IllegalArgumentException("Artist name is required")
                    val limit = args["limit"] as? Int ?: 25
                    val thumbQuality = args["thumbQuality"] as? String ?: "VERY_HIGH"
                    val audioQuality = args["audioQuality"] as? String ?: "HIGH"
                    val includeAudioUrl = args["includeAudioUrl"] as? Boolean ?: true
                    val includeAlbumArt = args["includeAlbumArt"] as? Boolean ?: true

                    if (musicSearcher == null) {
                        throw IllegalStateException("Music searcher not initialized")
                    }

                    val generator = musicSearcher!!.callAttr(
                        "get_artist_songs",
                        artistName,
                        limit,
                        thumbQuality,
                        audioQuality,
                        includeAudioUrl,
                        includeAlbumArt
                    )

                    var itemCount = 0
                    val iterator = generator.callAttr("__iter__")

                    while (isActive && itemCount < limit) {
                        try {
                            val item = iterator.callAttr("__next__")
                            val songData = convertPythonDictToMap(item)
                            
                            val result = mapOf(
                                "title" to (songData["title"]?.toString() ?: "Unknown"),
                                "artists" to (songData["artists"]?.toString() ?: "Unknown"),
                                "videoId" to (songData["videoId"]?.toString() ?: ""),
                                "duration" to songData["duration"]?.toString(),
                                "albumArt" to songData["albumArt"]?.toString(),
                                "audioUrl" to songData["audioUrl"]?.toString(),
                                "artistName" to artistName
                            )
                            
                            withContext(Dispatchers.Main) {
                                events?.success(result)
                            }
                            
                            itemCount++
                            delay(50)
                            
                        } catch (e: Exception) {
                            if (e.message?.contains("StopIteration") == true) break
                            Log.e(TAG, "Error processing artist song", e)
                        }
                    }

                    withContext(Dispatchers.Main) {
                        events?.endOfStream()
                    }
                    
                } catch (e: Exception) {
                    Log.e(TAG, "Artist songs stream error", e)
                    withContext(Dispatchers.Main) {
                        events?.error("STREAM_ERROR", e.message, null)
                    }
                }
            }
        }

        override fun onCancel(arguments: Any?) {
            job?.cancel()
            eventSink = null
        }
    }




    fun debugPythonInitialization(): Map<String, Any?> {
        return try {
            val pythonStatus = Python.isStarted()
            val sysModule = python?.getModule("sys")
            
            // Safe conversion of Python list to Kotlin list
            val moduleNames = sysModule?.callAttr("modules")?.asMap()?.keys?.toList() ?: emptyList<String>()
            
            // Explicit type conversion for boolean check
            val globalsearcherExists = python?.getModule("globalsearcher") != null

            mapOf(
                "pythonStarted" to pythonStatus,
                "pythonModuleNames" to moduleNames,  // Now properly typed as List<String>
                "globalsearcherExists" to globalsearcherExists
            )
        } catch (e: Exception) {
            mapOf("error" to e.message)
        }
    }

    fun inspectEnvironment(): Map<String, Any?> {
        return try {
            val sys = python?.getModule("sys")
            val platform = python?.getModule("platform")
            
            // Explicit type conversions
            val pythonPath: List<String> = sys?.callAttr("path")?.asList()?.map { it.toString() } ?: emptyList()
            val chaquopyVersion = python?.getModule("chaquopy")?.callAttr("__version__")?.toString()
            val platformInfo = platform?.callAttr("platform")?.toString()

            mapOf(
                "pythonPath" to pythonPath,  // Now properly typed as List<String>
                "chaquopyVersion" to chaquopyVersion,
                "platform" to platformInfo
            )
        } catch (e: Exception) {
            mapOf("error" to e.message)
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        logMethodCall(call)
        when (call.method) {
            "checkStatus" -> handleCheckStatus(result)
            "initialize" -> handleInitialize(call, result)
            "searchMusic" -> handleSearchMusic(call, result)
            "startStreamingSearch" -> handleStartStreamingSearch(call, result)
            "getSongDetails" -> handleGetSongDetails(call, result)
            "getArtistSongs" -> handleGetArtistSongs(call, result)
            "getRelatedSongs" -> handleGetRelatedSongs(call, result)
            "dispose" -> handleDispose(result)
            else -> result.notImplemented()
        }
    }

    private fun logMethodCall(call: MethodCall) {
        Log.d(TAG, """
            Method: ${call.method}
            Args: ${call.arguments}
            Python: ${python != null}
            Module: ${pythonModule != null}
            Searcher: ${musicSearcher != null}
            """.trimIndent())
    }

    private fun handleCheckStatus(result: Result) {
        coroutineScope.launch {
            try {
                if (pythonModule == null) {
                    initializePython()
                }
            
                val statusResult = pythonModule!!.callAttr("check_ytmusic_and_ytdlp_ready")
                val statusMap = convertPythonDictToMap(statusResult)
            
                withContext(Dispatchers.Main) {
                    result.success(statusMap)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Status check failed", e)
                withContext(Dispatchers.Main) {
                    result.error("STATUS_ERROR", "Failed to check status: ${e.message}", null)
                }
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
            pythonModule = python?.getModule("globalsearcher")
            
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

    



    // DONE + WORKING AS INTENDED
    private fun handleSearchMusic(call: MethodCall, result: Result) {
    coroutineScope.launch {
        try {
            val query = call.argument<String>("query") 
                ?: throw IllegalArgumentException("Query is required")
            
            val limit = call.argument<Int>("limit") ?: 10
            val thumbQuality = call.argument<String>("thumbQuality") ?: "HIGH"
            val audioQuality = call.argument<String>("audioQuality") ?: "HIGH"
            val includeAudioUrl = call.argument<Boolean>("includeAudioUrl") ?: true
            val includeAlbumArt = call.argument<Boolean>("includeAlbumArt") ?: true
            
            if (musicSearcher == null) {
                throw IllegalStateException("YTMusic API not initialized. Call initialize() first.")
            }
            
            val pythonThumbQuality = getPythonThumbnailQuality(thumbQuality)
            val pythonAudioQuality = getPythonAudioQuality(audioQuality)
            
            Log.d(TAG, "Starting search with query: $query")
            
            val searchResults = musicSearcher!!.callAttr(
                "get_music_details",
                query,
                limit,
                pythonThumbQuality,
                pythonAudioQuality,
                includeAudioUrl,
                includeAlbumArt
            )
            
            Log.d(TAG, "Raw search results type: ${searchResults?.javaClass?.simpleName}")
            
            val resultList = mutableListOf<Map<String, Any?>>()
            
            try {
                // Convert generator to list first
                val pythonList = python?.getBuiltins()?.callAttr("list", searchResults)
                
                if (pythonList != null) {
                    val size = pythonList.callAttr("__len__").toInt()
                    Log.d(TAG, "Processing $size search results")
                    
                    for (i in 0 until size) {
                        try {
                            val item = pythonList.callAttr("__getitem__", i)
                            Log.d(TAG, "Processing search result $i: ${item.toString()}")
                            
                            val songData = convertPythonDictToMap(item)
                            
                            // Create standardized result
                            val processedResult = mapOf(
                                "title" to (songData["title"]?.toString() ?: "Unknown Title"),
                                "artists" to (songData["artists"]?.toString() ?: "Unknown Artist"),
                                "videoId" to (songData["videoId"]?.toString() ?: ""),
                                "duration" to songData["duration"]?.toString(),
                                "year" to songData["year"]?.toString(),
                                "albumArt" to songData["albumArt"]?.toString(),
                                "audioUrl" to songData["audioUrl"]?.toString()
                            )
                            
                            resultList.add(processedResult)
                            Log.d(TAG, "Added search result: ${processedResult["title"]} by ${processedResult["artists"]}")
                            
                        } catch (e: Exception) {
                            Log.e(TAG, "Error processing search result $i", e)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error processing search results list", e)
            }
            
            Log.d(TAG, "Returning ${resultList.size} search results")
            
            withContext(Dispatchers.Main) {
                result.success(mapOf(
                    "success" to true,
                    "data" to resultList,
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



// Update the handleStartStreamingSearch method:
private fun handleStartStreamingSearch(call: MethodCall, result: Result) {
    Log.d(TAG, "handleStartStreamingSearch called")
    
    // Extract arguments and validate
    val query = call.argument<String>("query")
    if (query.isNullOrEmpty()) {
        result.error("INVALID_QUERY", "Query is required", null)
        return
    }
    
    // This method just confirms the call was received
    // The actual streaming happens in the EventChannel.StreamHandler
    result.success(mapOf(
        "started" to true,
        "message" to "Streaming search will start when EventChannel is listened to",
        "query" to query
    ))
}


    // DONE + WORKING AS INTENDED
    private fun handleGetRelatedSongs(call: MethodCall, result: Result) {
    try {
        val songName = call.argument<String>("songName")
            ?: throw IllegalArgumentException("Song name is required")
        val artistName = call.argument<String>("artistName")
            ?: throw IllegalArgumentException("Artist name is required")

        result.success(mapOf(
            "success" to true,
            "message" to "Streaming started for related songs of '$songName' by '$artistName'",
            "songName" to songName,
            "artistName" to artistName
        ))
    } catch (e: Exception) {
        Log.e(TAG, "Get related songs failed", e)
        result.error("RELATED_ERROR", "Get related songs failed: ${e.message}", null)
    }
}

private fun handleGetSongDetails(call: MethodCall, result: Result) {
    coroutineScope.launch {
        try {
            // Parse arguments
            val songs = call.argument<List<Map<String, String>>>("songs")
                ?: throw IllegalArgumentException("Songs list is required")
            
            val mode = call.argument<String>("mode") ?: "batch"
            val thumbQuality = call.argument<String>("thumbQuality") ?: "VERY_HIGH"
            val audioQuality = call.argument<String>("audioQuality") ?: "VERY_HIGH"
            val includeAudioUrl = call.argument<Boolean>("includeAudioUrl") ?: true
            val includeAlbumArt = call.argument<Boolean>("includeAlbumArt") ?: true
            
            if (musicSearcher == null) {
                throw IllegalStateException("YTMusic API not initialized. Call initialize() first.")
            }
            
            val pythonThumbQuality = getPythonThumbnailQuality(thumbQuality)
            val pythonAudioQuality = getPythonAudioQuality(audioQuality)
            
            Log.d(TAG, "Getting song details in $mode mode for ${songs.size} songs")
            
            // Convert songs list to Python list
            val pySongs = python?.getBuiltins()?.callAttr("list") ?: 
                throw IllegalStateException("Python builtins not available")
            
            for (song in songs) {
                val pySong = python?.getBuiltins()?.callAttr("dict") ?: continue
                pySong.callAttr("__setitem__", "song_name", song["song_name"])
                pySong.callAttr("__setitem__", "artist_name", song["artist_name"])
                pySongs.callAttr("append", pySong)
            }
            
            // Call the Python method
            val pythonResult = musicSearcher!!.callAttr(
                "get_song_details",
                pySongs,
                pythonThumbQuality,
                pythonAudioQuality,
                includeAudioUrl,
                includeAlbumArt,
                mode.lowercase()
            )
            
            // Process results based on mode
            when (mode.lowercase()) {
                "single" -> {
                    // Single mode - returns a single dictionary
                    val songData = convertPythonDictToMap(pythonResult)
                    
                    withContext(Dispatchers.Main) {
                        result.success(mapOf(
                            "success" to true,
                            "data" to songData,
                            "mode" to "single"
                        ))
                    }
                }
                else -> {
                    // Batch mode - returns a generator, need to consume it
                    val resultList = mutableListOf<Map<String, Any?>>()
                    
                    try {
                        // Convert generator to list by consuming it
                        val pythonList = python?.getBuiltins()?.callAttr("list", pythonResult)
                        
                        if (pythonList != null) {
                            val size = pythonList.callAttr("__len__").toInt()
                            Log.d(TAG, "Generator produced $size results")
                            
                            for (i in 0 until size) {
                                try {
                                    val item = pythonList.callAttr("__getitem__", i)
                                    resultList.add(convertPythonDictToMap(item))
                                } catch (e: Exception) {
                                    Log.e(TAG, "Error processing item $i", e)
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error consuming generator", e)
                        // Fallback: try to iterate directly if it's iterable
                        try {
                            val iterator = pythonResult.callAttr("__iter__")
                            var index = 0
                            
                            while (true) {
                                try {
                                    val item = iterator.callAttr("__next__")
                                    resultList.add(convertPythonDictToMap(item))
                                    index++
                                    Log.d(TAG, "Processed item $index from generator")
                                } catch (stopIteration: Exception) {
                                    // StopIteration exception means we've reached the end
                                    if (stopIteration.message?.contains("StopIteration") == true) {
                                        Log.d(TAG, "Generator exhausted after $index items")
                                        break
                                    } else {
                                        Log.e(TAG, "Error iterating generator at item $index", stopIteration)
                                        break
                                    }
                                }
                            }
                        } catch (iterException: Exception) {
                            Log.e(TAG, "Failed to iterate generator directly", iterException)
                        }
                    }
                    
                    withContext(Dispatchers.Main) {
                        result.success(mapOf(
                            "success" to true,
                            "data" to resultList,
                            "mode" to "batch",
                            "count" to resultList.size
                        ))
                    }
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get song details", e)
            withContext(Dispatchers.Main) {
                result.error("SONG_DETAILS_ERROR", "Failed to get song details: ${e.message}", null)
            }
        }
    }
}

private fun handleGetArtistSongs(call: MethodCall, result: Result) {
    coroutineScope.launch {
        try {
            val artistName = call.argument<String>("artistName") 
                ?: throw IllegalArgumentException("Artist name is required")
            
            val limit = call.argument<Int>("limit") ?: 25
            val thumbQuality = call.argument<String>("thumbQuality") ?: "VERY_HIGH"
            val audioQuality = call.argument<String>("audioQuality") ?: "HIGH"
            val includeAudioUrl = call.argument<Boolean>("includeAudioUrl") ?: true
            val includeAlbumArt = call.argument<Boolean>("includeAlbumArt") ?: true
            
            if (musicSearcher == null) {
                throw IllegalStateException("YTMusic API not initialized")
            }

            Log.d(TAG, "Fetching songs for artist: $artistName (limit: $limit)")

            // Call Python and get the generator
            val generator = musicSearcher!!.callAttr(
                "get_artist_songs",
                artistName,
                limit,
                thumbQuality,
                audioQuality,
                includeAudioUrl,
                includeAlbumArt
            )

            // Convert generator to list
            val pythonList = python?.getBuiltins()?.callAttr("list", generator)
                ?: throw Exception("Failed to convert generator to list")

            val songs = mutableListOf<Map<String, Any?>>()
            val count = pythonList.callAttr("__len__").toInt()

            Log.d(TAG, "Processing $count songs...")

            for (i in 0 until count) {
                try {
                    val song = pythonList.callAttr("__getitem__", i)
                    val songMap = convertPythonDictToMap(song)
                    
                    // Ensure all required fields are present
                    // Ensure all required fields are present
                    songs.add(mapOf<String, Any?>(
                        "title" to (songMap["title"]?.toString() ?: "Unknown"),
                        "artists" to (songMap["artists"]?.toString() ?: "Unknown"),
                        "videoId" to (songMap["videoId"]?.toString() ?: ""),
                        "duration" to songMap["duration"]?.toString(),
                        "albumArt" to songMap["albumArt"]?.toString(),
                        "audioUrl" to songMap["audioUrl"]?.toString(),
                        "artistName" to artistName
                    ))
                } catch (e: Exception) {
                    Log.e(TAG, "Error processing song $i", e)
                }
            }

            withContext(Dispatchers.Main) {
                result.success(mapOf(
                    "success" to true,
                    "data" to songs,
                    "count" to songs.size,
                    "skipped" to (count - songs.size)
                ))
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error in handleGetArtistSongs", e)
            withContext(Dispatchers.Main) {
                result.error(
                    "ARTIST_SONGS_ERROR", 
                    "Failed to get artist songs: ${e.message}", 
                    null
                )
            }
        }
    }
}
// // Update the handleGetLyrics function to provide better error handling
// private fun handleGetLyrics(call: MethodCall, result: Result) {
//     coroutineScope.launch {
//         try {
//             val title = call.argument<String>("title") 
//                 ?: throw IllegalArgumentException("Title is required")
//             val artist = call.argument<String>("artist") 
//                 ?: throw IllegalArgumentException("Artist is required")
//             val duration = call.argument<Int>("duration") ?: -1

//             if (pythonModule == null) {
//                 initializePython()
//                 if (pythonModule == null) {
//                     throw IllegalStateException("Python environment not initialized")
//                 }
//             }

//             val lyricsProvider = instanceCache.getOrPut("lyrics_provider") {
//                 pythonModule!!.callAttr("DynamicLyricsProvider")
//             }

//             Log.d(TAG, "Fetching lyrics for: $title by $artist")

//             val lyricsResult = lyricsProvider.callAttr(
//                 "fetch_lyrics",
//                 title,
//                 artist,
//                 duration
//             )

//             Log.d(TAG, "Raw lyrics result: ${lyricsResult.toString()}")

//             val response = convertLyricsResponse(lyricsResult)
            
//             Log.d(TAG, "Converted lyrics response - Success: ${response.success}, Lines: ${response.lyrics?.size}")

//             withContext(Dispatchers.Main) {
//                 result.success(response.toMap())
//             }

//         } catch (e: Exception) {
//             Log.e(TAG, "Failed to get lyrics", e)
//             withContext(Dispatchers.Main) {
//                 result.error(
//                     "LYRICS_ERROR",
//                     "Failed to get lyrics: ${e.message}",
//                     mapOf(
//                         "success" to false,
//                         "error" to (e.message ?: "Unknown error")
//                     )
//                 )
//             }
//         }
//     }
// }

// // IMPROVED: convertLyricsResponse function
// private fun convertLyricsResponse(pyObject: PyObject?): LyricsResponse {
//     if (pyObject == null) {
//         return LyricsResponse(
//             success = false,
//             lyrics = null,
//             source = null,
//             totalLines = null,
//             error = "Null response from Python"
//         )
//     }

//     try {
//         Log.d(TAG, "Converting lyrics response")
//         val responseMap = convertPythonDictToMap(pyObject)
//         Log.d(TAG, "Response map: $responseMap")

//         // Handle success field - it could be Boolean or String
//         val success = when (val successVal = responseMap["success"]) {
//             is Boolean -> successVal
//             is String -> successVal.equals("true", ignoreCase = true)
//             else -> false
//         }

//         if (!success) {
//             return LyricsResponse(
//                 success = false,
//                 lyrics = null,
//                 source = responseMap["source"]?.toString(),
//                 totalLines = null,
//                 error = responseMap["error"]?.toString() ?: "Unknown error"
//             )
//         }

//         // Process lyrics lines - FIXED HANDLING
//         val lyricsList = mutableListOf<LyricsLine>()
//         val lyricsData = responseMap["lyrics"]
        
//         if (lyricsData is List<*>) {
//             Log.d(TAG, "Processing lyrics as Kotlin List with ${lyricsData.size} items")
            
//             for (item in lyricsData) {
//                 // Handle both map representations and string representations
//                 when {
//                     item is Map<*, *> -> {
//                         try {
//                             processMapItem(item as Map<String, Any?>, lyricsList)
//                         } catch (e: Exception) {
//                             Log.e(TAG, "Error processing map item", e)
//                         }
//                     }
//                     item is String -> {
//                         try {
//                             // Attempt to parse string representation as JSON
//                             val map = parseJsonString(item)
//                             map?.let { processMapItem(it, lyricsList) }
//                         } catch (e: Exception) {
//                             Log.e(TAG, "Error parsing string item", e)
//                         }
//                     }
//                     else -> {
//                         Log.w(TAG, "Unknown lyrics item type: ${item?.javaClass?.simpleName}")
//                     }
//                 }
//             }
//         } else if (lyricsData is PyObject) {
//             Log.d(TAG, "Processing lyrics as PyObject")
//             try {
//                 val pythonList = python?.getBuiltins()?.callAttr("list", lyricsData)
//                 if (pythonList != null) {
//                     val size = pythonList.callAttr("__len__").toInt()
//                     for (i in 0 until size) {
//                         try {
//                             val linePy = pythonList.callAttr("__getitem__", i)
//                             val lineMap = convertPythonDictToMap(linePy)
//                             processMapItem(lineMap, lyricsList)
//                         } catch (e: Exception) {
//                             Log.e(TAG, "Error processing lyrics line $i", e)
//                         }
//                     }
//                 }
//             } catch (e: Exception) {
//                 Log.e(TAG, "Error processing PyObject lyrics", e)
//             }
//         }

//         Log.d(TAG, "Processed ${lyricsList.size} lyrics lines")
        
//         return LyricsResponse(
//             success = true,
//             lyrics = lyricsList,
//             source = responseMap["source"]?.toString(),
//             totalLines = when (val total = responseMap["total_lines"]) {
//                 is Int -> total
//                 is Long -> total.toInt()
//                 is String -> total.toIntOrNull() ?: lyricsList.size
//                 else -> lyricsList.size
//             },
//             error = null
//         )
        
//     } catch (e: Exception) {
//         Log.e(TAG, "Error converting lyrics response", e)
//         return LyricsResponse(
//             success = false,
//             lyrics = null,
//             source = null,
//             totalLines = null,
//             error = "Error processing lyrics: ${e.message}"
//         )
//     }
// }

// private fun parseTimestamp(value: Any?): Long {
//     return when (value) {
//         is Long -> value
//         is Int -> value.toLong()
//         is Double -> value.toLong()
//         is Float -> value.toLong()
//         is String -> value.toLongOrNull() ?: 0L
//         else -> 0L
//     }
// }

// // NEW: Helper function to process lyrics from Kotlin List
// private fun processLyricsList(lyricsData: List<*>, lyricsList: MutableList<LyricsLine>) {
//     lyricsData.forEachIndexed { index, item ->
//         try {
//             when (item) {
//                 is Map<*, *> -> {
//                     val lineData = (item as? Map<*, *>)?.mapNotNull {
//                         val key = it.key as? String ?: return@mapNotNull null
//                         key to it.value
//                     }?.toMap()

//                     if (lineData != null) {
//                         addLyricsLine(lineData, lyricsList)
//                     } else {
//                         Log.w(TAG, "Invalid map at index $index")
//                     }
//                 }
//                 is PyObject -> {
//                     val lineData = convertPythonDictToMap(item)
//                     addLyricsLine(lineData, lyricsList)
//                 }
//                 else -> {
//                     Log.w(TAG, "Unexpected lyrics item type at index $index: ${item?.javaClass?.simpleName}")
//                 }
//             }
//         } catch (e: Exception) {
//             Log.e(TAG, "Error processing lyrics line $index", e)
//         }
//     }
// }


// // NEW: Helper function to process lyrics from PyObject
// private fun processLyricsPyObject(lyricsData: PyObject, lyricsList: MutableList<LyricsLine>) {
//     try {
//         val pythonList = python?.getBuiltins()?.callAttr("list", lyricsData)
//         if (pythonList != null) {
//             val size = pythonList.callAttr("__len__").toInt()
//             Log.d(TAG, "Processing $size lyrics lines from PyObject")
            
//             for (i in 0 until size) {
//                 try {
//                     val item = pythonList.callAttr("__getitem__", i)
//                     val lineData = convertPythonDictToMap(item)
//                     addLyricsLine(lineData, lyricsList)
//                 } catch (e: Exception) {
//                     Log.e(TAG, "Error processing lyrics line $i", e)
//                 }
//             }
//         }
//     } catch (e: Exception) {
//         Log.e(TAG, "Error processing PyObject lyrics", e)
//     }
// }

// // NEW: Helper function to add a lyrics line
// private fun addLyricsLine(lineData: Map<String, Any?>, lyricsList: MutableList<LyricsLine>) {
//     val timestamp = when (val ts = lineData["timestamp"]) {
//         is Long -> ts
//         is Int -> ts.toLong()
//         is String -> ts.toLongOrNull() ?: 0L
//         else -> 0L
//     }
    
//     val text = lineData["text"]?.toString() ?: ""
//     val timeFormatted = lineData["time_formatted"]?.toString() 
//         ?: formatTimestamp(timestamp)
    
//     if (text.isNotEmpty()) {
//         lyricsList.add(
//             LyricsLine(
//                 timestamp = timestamp,
//                 text = text,
//                 timeFormatted = timeFormatted
//             )
//         )
//         Log.d(TAG, "Added lyrics line: $text at $timeFormatted")
//     }
// }

// NEW: Helper function to convert Python lists to Kotlin lists
private fun convertPythonList(pyList: PyObject): List<Any?> {
    val resultList = mutableListOf<Any?>()
    
    try {
        // Convert to Python list if it's a generator or iterator
        val pythonList = python?.getBuiltins()?.callAttr("list", pyList) ?: pyList
        val size = pythonList.callAttr("__len__").toInt()
        
        Log.d(TAG, "Converting Python list with $size items")
        
        for (i in 0 until size) {
            try {
                val item = pythonList.callAttr("__getitem__", i)
                val convertedItem = when {
                    // If item is a dictionary, convert it recursively
                    isDictLike(item) -> convertPythonDictToMap(item)
                    // If item is a list, convert it recursively
                    isPythonList(item) -> convertPythonList(item)
                    // Otherwise, convert as regular value
                    else -> convertPythonValue(item)
                }
                resultList.add(convertedItem)
                Log.d(TAG, "Added list item $i: $convertedItem")
            } catch (e: Exception) {
                Log.e(TAG, "Error processing list item $i", e)
            }
        }
    } catch (e: Exception) {
        Log.e(TAG, "Error converting Python list", e)
    }
    
    return resultList
}

private fun isDictLike(pyObject: PyObject): Boolean {
    return try {
        // Check if it has keys() method (dict-like)
        pyObject.callAttr("keys")
        true
    } catch (e: Exception) {
        false
    }
}

// Helper function to check if a PyObject is a Python list - IMPROVED VERSION
private fun isPythonList(pyObject: PyObject): Boolean {
    return try {
        // First check if it has __len__ and __getitem__ methods (list-like)
        pyObject.callAttr("__len__")
        pyObject.callAttr("__getitem__", 0)
        true
    } catch (e: Exception) {
        try {
            // Alternative check: use isinstance with list type
            val pythonBuiltins = python?.getBuiltins()
            val listType = pythonBuiltins?.get("list")
            val tupleType = pythonBuiltins?.get("tuple")
            
            if (listType != null && tupleType != null) {
                val isList = pythonBuiltins.callAttr("isinstance", pyObject, listType).toBoolean()
                val isTuple = pythonBuiltins.callAttr("isinstance", pyObject, tupleType).toBoolean()
                isList || isTuple
            } else {
                false
            }
        } catch (e2: Exception) {
            // Final fallback: check string representation
            val str = pyObject.toString()
            (str.startsWith("[") && str.endsWith("]")) || 
            (str.startsWith("(") && str.endsWith(")"))
        }
    }
}


// private fun processMapItem(lineMap: Map<String, Any?>, lyricsList: MutableList<LyricsLine>) {
//     val timestamp = parseTimestamp(lineMap["timestamp"])
//     val text = lineMap["text"]?.toString() ?: ""
//     val timeFormatted = lineMap["time_formatted"]?.toString() 
//         ?: formatTimestamp(timestamp)
    
//     if (text.isNotEmpty()) {
//         lyricsList.add(
//             LyricsLine(
//                 timestamp = timestamp,
//                 text = text,
//                 timeFormatted = timeFormatted
//             )
//         )
//     }
// }

private fun parseJsonString(jsonString: String): Map<String, Any?>? {
    return try {
        // Remove single quotes to make valid JSON
        val cleanString = jsonString
            .replace("'", "\"")
            .replace("True", "true")
            .replace("False", "false")
        
        val type = object : TypeToken<Map<String, Any>>() {}.type
        Gson().fromJson(cleanString, type)
    } catch (e: Exception) {
        Log.e(TAG, "Error parsing JSON string", e)
        null
    }
}

private fun formatTimestamp(ms: Long): String {
    val seconds = ms / 1000
    val minutes = seconds / 60
    val remainingSeconds = seconds % 60
    val milliseconds = ms % 1000
    return String.format("%02d:%02d.%03d", minutes, remainingSeconds, milliseconds)
}

// Extension function to convert LyricsResponse to Map for Flutter
private fun LyricsResponse.toMap(): Map<String, Any?> {
    return mapOf(
        "success" to success,
        "lyrics" to lyrics?.map { 
            mapOf(
                "timestamp" to it.timestamp,
                "text" to it.text,
                "timeFormatted" to it.timeFormatted
            )
        },
        "source" to source,
        "totalLines" to totalLines,
        "error" to error
    )
}

// Extension function for safe boolean conversion
private fun String?.toBoolean(): Boolean {
    return when (this?.lowercase()) {
        "true" -> true
        "false" -> false
        else -> false
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
        return try {
            val thumbnailQualityEnum = pythonModule?.get("ThumbnailQuality")
                ?: throw IllegalStateException("ThumbnailQuality enum not found in Python module")

            when (quality.uppercase()) {
                "LOW" -> thumbnailQualityEnum["LOW"] ?: throw IllegalStateException("LOW quality not found")
                "MED" -> thumbnailQualityEnum["MED"] ?: throw IllegalStateException("MED quality not found")
                "HIGH" -> thumbnailQualityEnum["HIGH"] ?: throw IllegalStateException("HIGH quality not found")
                "VERY_HIGH" -> thumbnailQualityEnum["VERY_HIGH"] ?: throw IllegalStateException("VERY_HIGH quality not found")
                else -> {
                    Log.w(TAG, "Unknown thumbnail quality: $quality, using HIGH")
                    thumbnailQualityEnum["HIGH"] ?: throw IllegalStateException("Default quality not found")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting Python thumbnail quality for: $quality", e)
            throw e
        }
    }

    private fun getPythonAudioQuality(quality: String): PyObject {
        return try {
            val audioQualityEnum = pythonModule?.get("AudioQuality")
                ?: throw IllegalStateException("AudioQuality enum not found in Python module")

            when (quality.uppercase()) {
                "LOW" -> audioQualityEnum["LOW"] ?: throw IllegalStateException("LOW quality not found")
                "MED" -> audioQualityEnum["MED"] ?: throw IllegalStateException("MED quality not found")
                "HIGH" -> audioQualityEnum["HIGH"] ?: throw IllegalStateException("HIGH quality not found")
                "VERY_HIGH" -> audioQualityEnum["VERY_HIGH"] ?: throw IllegalStateException("VERY_HIGH quality not found")
                else -> {
                    Log.w(TAG, "Unknown audio quality: $quality, using HIGH")
                    audioQualityEnum["HIGH"] ?: throw IllegalStateException("Default quality not found")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting Python audio quality for: $quality", e)
            throw e
        }
    }

  // Update the convertPythonDictToMap function to handle lyrics responses better
 private fun convertPythonDictToMap(pyObject: PyObject?): Map<String, Any?> {
    if (pyObject == null) {
        return emptyMap()
    }

    val resultMap = mutableMapOf<String, Any?>()
    
    try {
        // Get keys as list
        val keysList = python?.getBuiltins()?.callAttr("list", pyObject.callAttr("keys"))
        
        if (keysList != null) {
            val size = keysList.callAttr("__len__").toInt()
            
            for (i in 0 until size) {
                try {
                    val key = keysList.callAttr("__getitem__", i).toString()
                    val value = pyObject.callAttr("__getitem__", key)
                    
                    resultMap[key] = when {
                        value == null -> null
                        value.isNone -> null
                        value.isTrue -> true
                        value.isFalse -> false
                        value.isString -> value.toString()
                        value.isNumber -> {
                            try {
                                value.toLong()
                            } catch (e: Exception) {
                                try {
                                    value.toDouble()
                                } catch (e: Exception) {
                                    value.toString()
                                }
                            }
                        }
                        else -> value.toString() // Fallback to string for complex objects
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Error processing key at index $i", e)
                }
            }
        }
    } catch (e: Exception) {
        Log.e(TAG, "Error converting Python dict to simple map", e)
    }
    
    return resultMap
}



// Add these extension properties to your code
private val PyObject.isNone: Boolean
    get() = this.toString() == "None"

private val PyObject.isTrue: Boolean
    get() = this.toString() == "True"

private val PyObject.isFalse: Boolean
    get() = this.toString() == "False"

private val PyObject.isString: Boolean
    get() = try {
        python?.getBuiltins()?.callAttr("isinstance", this, python?.getBuiltins()?.get("str"))?.toBoolean() ?: false
    } catch (e: Exception) {
        false
    }

private val PyObject.isNumber: Boolean
    get() = try {
        python?.getBuiltins()?.callAttr("isinstance", this, python?.getBuiltins()?.get("int"))?.toBoolean() ?: false ||
        python?.getBuiltins()?.callAttr("isinstance", this, python?.getBuiltins()?.get("float"))?.toBoolean() ?: false
    } catch (e: Exception) {
        false
    }

    // Helper function to convert individual Python values
private fun convertPythonValue(pyValue: PyObject): Any? {
    return try {
        val valueStr = pyValue.toString()
        Log.d(TAG, "Converting Python value: $valueStr")
        
        when {
            valueStr == "None" -> null
            valueStr == "True" -> true
            valueStr == "False" -> false
            valueStr.startsWith("'") && valueStr.endsWith("'") -> 
                valueStr.substring(1, valueStr.length - 1)
            valueStr.startsWith("\"") && valueStr.endsWith("\"") -> 
                valueStr.substring(1, valueStr.length - 1)
            valueStr.toLongOrNull() != null -> valueStr.toLong()
            valueStr.toDoubleOrNull() != null -> valueStr.toDouble()
            isPythonList(pyValue) -> {
                Log.d(TAG, "Converting Python list")
                convertPythonList(pyValue)
            }
            isDictLike(pyValue) -> {
                Log.d(TAG, "Converting nested Python dict")
                convertPythonDictToMap(pyValue)
            }
            else -> valueStr
        }
    } catch (e: Exception) {
        Log.w(TAG, "Error converting Python value: ${pyValue.toString()}", e)
        pyValue.toString()
    }
}


// Update the convertPythonDictFallback function to handle lyrics fields
private fun convertPythonDictFallback(pythonDict: PyObject): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>()
    
    try {
        // Check for lyrics response fields
        val lyricsResponseFields = listOf(
            "success", "lyrics", "source", "total_lines", "error"
        )
        
        // Check for standard search result fields
        val searchResultFields = listOf(
            "title", "artists", "videoId", "duration",
            "year", "albumArt", "audioUrl"
        )
        
        // Check for related song fields
        val relatedSongFields = listOf(
            "isOriginal"
        )
        
        // Check for status fields
        val statusFields = listOf(
            "ytmusic_ready", "ytmusic_version",
            "ytdlp_ready", "ytdlp_version", "message"
        )
        
        // Check for individual lyrics line fields
        val lyricsLineFields = listOf(
            "timestamp", "text", "time_formatted"
        )
        
        var foundAnyField = false
        
        // Handle all possible fields
        val allFields = lyricsResponseFields + searchResultFields + relatedSongFields + statusFields + lyricsLineFields
        
        for (field in allFields) {
            try {
                val value = pythonDict.get(field)
                if (value != null && value.toString() != "None") {
                    foundAnyField = true
                    map[field] = when {
                        value.toString() == "True" -> true
                        value.toString() == "False" -> false
                        isPythonList(value) -> value // Keep lists as PyObject
                        field == "timestamp" -> {
                            // Handle timestamp conversion
                            try {
                                value.toString().toLongOrNull() ?: 0L
                            } catch (e: Exception) {
                                0L
                            }
                        }
                        field == "total_lines" -> {
                            // Handle total_lines conversion
                            try {
                                value.toString().toIntOrNull() ?: 0
                            } catch (e: Exception) {
                                0
                            }
                        }
                        field == "isOriginal" -> {
                            // Handle boolean conversion for isOriginal
                            when (value.toString()) {
                                "True", "true", "1" -> true
                                "False", "false", "0" -> false
                                else -> value.toString().toBoolean()
                            }
                        }
                        else -> value.toString()
                    }
                }
            } catch (e: Exception) {
                Log.d(TAG, "Field $field not found in Python dict: ${e.message}")
            }
        }
        
        if (foundAnyField) {
            Log.d(TAG, "Converted using fallback method: $map")
            return map
        }
        
        // Final fallback: Try to string representation
        Log.d(TAG, "All fallbacks failed, returning string representation")
        return mapOf(
            "raw_data" to pythonDict.toString(),
            "error" to "Could not properly convert Python dict to map"
        )
    } catch (e: Exception) {
        Log.e(TAG, "All conversion fallbacks failed", e)
        return mapOf(
            "error" to "Conversion failed: ${e.message}",
            "raw_data" to pythonDict.toString()
        )
    }
}

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        try {
            coroutineScope.cancel()
            instanceCache.clear()
            threadPoolExecutor.shutdown()
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup", e)
        }
    }
}


// Test Usage Examples (commented out for production)

// Initialize
// val initParams = mapOf(
//     "proxy" to null, // or "http://proxy:port"
//     "country" to "US"
// )

// Search Music
// val searchParams = mapOf(
//     "query" to "Gale Lag Ja",
//     "limit" to 10,
//     "thumbQuality" to "VERY_HIGH",
//     "audioQuality" to "VERY_HIGH",
//     "includeAudioUrl" to true,
//     "includeAlbumArt" to true
// )

// Get Related Songs
// val relatedParams = mapOf(
//     "songName" to "Viva La Vida",
//     "artistName" to "Coldplay",
//     "limit" to 10,
//     "thumbQuality" to "VERY_HIGH",
//     "audioQuality" to "VERY_HIGH",
//     "includeAudioUrl" to true,
//     "includeAlbumArt" to true
// )