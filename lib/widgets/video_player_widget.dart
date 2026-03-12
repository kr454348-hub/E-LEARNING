import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart' as yt_mobile;
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt_web;
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import '../services/database_service.dart';
import 'video_player_stub_config.dart'
    if (dart.library.html) 'video_player_web_config.dart'
    as web_config;

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool autoPlay;
  final bool looping;
  final String? courseId; // For view tracking

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.autoPlay = false,
    this.looping = false,
    this.courseId,
  });

  @override
  VideoPlayerWidgetState createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  // Common
  bool _isYouTube = false;

  // Direct Video
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  // YouTube Mobile
  yt_mobile.YoutubePlayerController? _ytMobileController;

  // YouTube Web
  yt_web.YoutubePlayerController? _ytWebController;

  String? _launchError;

  @override
  void initState() {
    super.initState();
    _isYouTube = _checkIfYouTube(widget.videoUrl);
    _initializePlayer();
    _incrementViewCount();
  }

  void _incrementViewCount() {
    if (widget.courseId != null) {
      DatabaseService()
          .update('courses', {
            'views': FieldValue.increment(1),
          }, docId: widget.courseId)
          .catchError((e) => debugPrint("Error incrementing views: $e"));
    }
  }

  bool _checkIfYouTube(String url) {
    return url.contains("youtube.com") || url.contains("youtu.be");
  }

  void _initializePlayer() {
    if (_isYouTube) {
      if (kIsWeb) {
        // Use youtube_player_iframe for Web
        final videoId = yt_mobile.YoutubePlayer.convertUrlToId(widget.videoUrl);
        if (videoId != null) {
          _ytWebController = yt_web.YoutubePlayerController(
            params: const yt_web.YoutubePlayerParams(
              showControls: true,
              showFullscreenButton: true,
              mute: false,
            ),
          )..loadVideoById(videoId: videoId);
        }
      } else if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        // Mobile YouTube only
        final videoId = yt_mobile.YoutubePlayer.convertUrlToId(widget.videoUrl);
        if (videoId != null) {
          _ytMobileController = yt_mobile.YoutubePlayerController(
            initialVideoId: videoId,
            flags: yt_mobile.YoutubePlayerFlags(
              autoPlay: widget.autoPlay,
              mute: false,
              forceHD: true,
            ),
          );
        }
      }
    } else {
      // Direct mp4/HLS
      if (kIsWeb) {
        final uniqueId = 'vid-direct-${widget.videoUrl.hashCode}';
        web_config.registerWebVideoPlayer(
          uniqueId,
          widget.videoUrl,
          widget.thumbnailUrl,
        );
      } else {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
        );
        _videoPlayerController!
            .initialize()
            .then((_) {
              if (mounted) {
                setState(() {
                  _chewieController = ChewieController(
                    videoPlayerController: _videoPlayerController!,
                    autoPlay: widget.autoPlay,
                    looping: widget.looping,
                    aspectRatio: _videoPlayerController!.value.aspectRatio,
                    materialProgressColors: ChewieProgressColors(
                      playedColor: Colors.deepPurple,
                      handleColor: Colors.deepPurpleAccent,
                      backgroundColor: Colors.grey,
                      bufferedColor: Colors.white24,
                    ),
                    placeholder: widget.thumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: widget.thumbnailUrl!,
                            fit: BoxFit.cover,
                          )
                        : null,
                    autoInitialize: true,
                  );
                });
              }
            })
            .catchError((e) {
              debugPrint("Error initializing direct video player: $e");
            });
      }
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.autoPlay != widget.autoPlay ||
        oldWidget.looping != widget.looping) {
      // Dispose old controllers
      _videoPlayerController?.dispose();
      _chewieController?.dispose();
      _ytMobileController?.dispose();
      
      _videoPlayerController = null;
      _chewieController = null;
      _ytMobileController = null;
      _ytWebController = null;

      _launchError = null; // Clear error on widget update

      // Re-initialize
      _isYouTube = _checkIfYouTube(widget.videoUrl);
      _initializePlayer();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _ytMobileController?.dispose();
    super.dispose();
  }

  // --- Public Controls ---
  bool isPlaying = false;

  void play() {
    if (_isYouTube) {
      if (kIsWeb) {
        _ytWebController?.playVideo();
      } else {
        _ytMobileController?.play();
      }
    } else {
      _videoPlayerController?.play();
    }
    setState(() => isPlaying = true);
  }

  void pause() {
    if (_isYouTube) {
      if (kIsWeb) {
        _ytWebController?.pauseVideo();
      } else {
        _ytMobileController?.pause();
      }
    } else {
      _videoPlayerController?.pause();
    }
    setState(() => isPlaying = false);
  }

  void togglePlay() {
    if (isPlaying) {
      pause();
    } else {
      play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      if (_isYouTube) {
        if (_ytWebController == null) {
          return Container(
            color: Colors.black,
            child: const Center(
              child: Text(
                "Invalid YouTube URL",
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }
        return yt_web.YoutubePlayer(
          controller: _ytWebController!,
          aspectRatio: 16 / 9,
        );
      } else {
        // Direct mp4 uses the stub config HtmlElementView
        final uniqueId = 'vid-direct-${widget.videoUrl.hashCode}';
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black12)],
            ),
            child: HtmlElementView(key: ValueKey(uniqueId), viewType: uniqueId),
          ),
        );
      }
    }

    // Windows/Desktop Fallback for YouTube
    if (_isYouTube &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return _buildDesktopFallback();
    }

    // Mobile YouTube
    if (_isYouTube) {
      if (_ytMobileController == null) {
        return Container(
          color: Colors.black,
          child: const Center(
            child: Text(
              "Invalid YouTube URL",
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      }
      return yt_mobile.YoutubePlayer(
        controller: _ytMobileController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.deepPurple,
      );
    }

    // Chewie Direct Player
    if (_chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized) {
      return Chewie(controller: _chewieController!);
    }

    // Loading State
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text("Loading Video...", style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopFallback() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Thumbnail
          if (widget.thumbnailUrl != null)
            CachedNetworkImage(
              imageUrl: widget.thumbnailUrl!,
              fit: BoxFit.cover,
              color: Colors.black54,
              colorBlendMode: BlendMode.darken,
            )
          else
            Container(color: Colors.black87),

          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.play_circle_outline_rounded,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Watch on YouTube",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    "Video playback is externally handled on desktop.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    final Uri url = Uri.parse(widget.videoUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                      if (mounted) setState(() => _launchError = null);
                    } else {
                      if (mounted) {
                        setState(() => _launchError = 'Could not launch URL.');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text("Open in Browser"),
                ),
                if (_launchError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _launchError!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
