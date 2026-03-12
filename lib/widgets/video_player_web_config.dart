// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

void registerWebVideoPlayer(
  String elementId,
  String videoUrl,
  String? thumbnailUrl,
) {
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(elementId, (int viewId) {
    final isYouTube =
        videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be');

    if (isYouTube) {
      // Extract video ID and use iframe for reliable playback
      String videoId = '';
      if (videoUrl.contains('watch?v=')) {
        videoId = videoUrl.split('watch?v=')[1].split('&')[0];
      } else if (videoUrl.contains('youtu.be/')) {
        videoId = videoUrl.split('youtu.be/')[1].split('?')[0];
      } else if (videoUrl.contains('embed/')) {
        videoId = videoUrl.split('embed/')[1].split('?')[0];
      }

      final iframe = html.IFrameElement()
        ..src = 'https://www.youtube.com/embed/$videoId?autoplay=1'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'autoplay; encrypted-media; picture-in-picture'
        ..setAttribute('allowfullscreen', 'true');

      return iframe;
    } else {
      // Direct mp4 implementation using standard HTML5 video tag
      final videoElement = html.VideoElement()
        ..src = videoUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'black'
        ..controls = true
        ..autoplay = true
        ..poster = thumbnailUrl ?? '';

      return videoElement;
    }
  });
}
