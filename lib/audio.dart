// Core Packages
import 'dart:async';
import 'dart:convert';

// External Packages
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audioplayers/audioplayers.dart';

/// Launch the audio background service
void backgroundTaskEntrypoint() {
  AudioServiceBackground.run(() => AudioPlayerTask());
}

/// Audio Background service implementation
class AudioPlayerTask extends BackgroundAudioTask {
  AudioPlayer           audioPlayer = AudioPlayer();
  StreamSubscription    _audioPlayerStateChangeSubscription;
  StreamSubscription    _audioPlayerErrorSubscription;
  StreamSubscription    _audioPlayerSeekCompleteSubscription;
  AudioSession          _audioSession;

  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    try {
      print('on start params');
      print(params);

      if (_audioSession == null) {
        _audioSession = await AudioSession.instance;
        await _audioSession.configure(AudioSessionConfiguration.speech());
      }

      if (!(await _audioSession.setActive(true)))
        return;

      if (params == null) return;

      await _clearRessources();

      AudioServiceBackground.setState(
        controls: [MediaControl.pause, MediaControl.stop],
        playing: true,
        processingState: AudioProcessingState.connecting,
        position: Duration(seconds: 0),
      );

      await audioPlayer.setUrl(params['episodeUrl']);
      int fetchedDuration = await audioPlayer.getDuration();

      MediaItem mediaItem = MediaItem(
        id: params['episodeId'],
        album: params['episodeThumbnail'],
        title: params['episodeTitle'],
        displaySubtitle: params['showTitle'],
        duration: Duration(seconds: fetchedDuration),
        extras: {
          'media_info': jsonEncode(params),
        }
      );

      // Set current media item to UI
      AudioServiceBackground.setMediaItem(mediaItem);

      _audioPlayerStateChangeSubscription = audioPlayer.onPlayerStateChanged.listen(
        _mapAudioStateEventToUIState,
        onError: (error) => print("On error: $error"),
      );

      _audioPlayerErrorSubscription = audioPlayer.onPlayerError.listen((error) {
        print('-> onPlayerError:');
        print(error);
      });

      _audioPlayerSeekCompleteSubscription = audioPlayer.onSeekComplete.listen((event) {
        print('-> onSeekComplete');
        AudioServiceBackground.setState(
          controls: [MediaControl.play, MediaControl.stop],
          playing: true,
          processingState: AudioProcessingState.ready,
        );
      });

      audioPlayer.resume();

      _audioSession.interruptionEventStream.listen((event) {
        print('-> interruptionEventStream');
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              if (audioPlayer != null)
                audioPlayer.setVolume(0.5);
              break;
            case AudioInterruptionType.pause:
              this.onPause();
              break;
            case AudioInterruptionType.unknown:
              this.onPause();
              break;
          }
        } else {
          switch (event.type) {
            // The interruption ended and we should unduck.
            case AudioInterruptionType.duck:
              if (audioPlayer != null)
                  audioPlayer.setVolume(1);
              break;
            // The interruption ended and we should resume.
            case AudioInterruptionType.pause:
              this.onPlay();
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });

      print('end of onstart');
    } catch (e) {
      print('On Start error');
      print(e);
    }
    return super.onStart(params);
  }


  @override
  Future<void> onPlay() async {
    print('-> onPlay');
    if (audioPlayer != null)
      audioPlayer.resume();
    return super.onPlay();
  }

  @override
  Future<void> onPause() async {
    print('-> onPause');
    if (audioPlayer != null)
      audioPlayer.pause();
    return super.onPause();
  }

  @override
  Future onCustomAction(String name, dynamic arguments) async {
    print('-> onCustomAction');

    if (name == 'set_audio') {
      Map<String, dynamic> mediaInfo = Map<String, dynamic>.from(arguments['media_info']);
      this.onStart(mediaInfo);
    }

    return super.onCustomAction(name, arguments);
  }

  @override
  Future<void> onSeekTo(Duration position) {
    print('-> onSeekTo');

    try {
      if (audioPlayer != null) {
        AudioServiceBackground.setState(
          controls: [MediaControl.stop],
          playing: false,
          processingState: AudioProcessingState.buffering,
          position: position,
        );
        audioPlayer.seek(position);
        // audioPlayer.resume();
      }
    } catch (error) {
      print('onSeekTo error');
      print(error);
    }

    return super.onSeekTo(position);
  }

  @override
  Future<void> onStop() async {
    print('-> onStop');
    await audioPlayer.stop();
    await _clearRessources();

    return super.onStop();
  }

  @override
  Future<void> onTaskRemoved() async {
    print('-> onTaskRemoved');
    await this.onStop();
    return super.onTaskRemoved();
  }

  Future<void> _clearRessources() async {
    print('-> _clearRessources');

    // Clear stream subscription.
    if (_audioPlayerStateChangeSubscription != null) {
      await _audioPlayerStateChangeSubscription.cancel();
      _audioPlayerStateChangeSubscription = null;
    }

    if (_audioPlayerErrorSubscription != null) {
      await _audioPlayerErrorSubscription.cancel();
      _audioPlayerErrorSubscription = null;
    }

    if (_audioPlayerSeekCompleteSubscription != null) {
      await _audioPlayerSeekCompleteSubscription.cancel();
      _audioPlayerSeekCompleteSubscription = null;
    }
  }

  void _mapAudioStateEventToUIState(AudioPlayerState state) {
    print('_mapAudioStateEventToUIState state: $state');

    if (state == AudioPlayerState.STOPPED) {
      AudioServiceBackground.setState(
        controls: [],
        playing: false,
        processingState: AudioProcessingState.stopped,
      );
    }

    if (state == AudioPlayerState.COMPLETED) {
      AudioServiceBackground.setState(
        controls: [],
        playing: false,
        processingState: AudioProcessingState.completed,
      );
    }

    if (state == AudioPlayerState.PAUSED) {
      AudioServiceBackground.setState(
        controls: [MediaControl.play, MediaControl.stop],
        playing: false,
        processingState: AudioProcessingState.ready,
      );
    }

    if (state == AudioPlayerState.PLAYING) {
      AudioServiceBackground.setState(
        controls: [MediaControl.pause, MediaControl.stop],
        playing: true,
        processingState: AudioProcessingState.ready,
      );
    }
  }
}