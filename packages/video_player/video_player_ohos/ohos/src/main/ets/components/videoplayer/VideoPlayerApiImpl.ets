/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import { FlutterPlugin, FlutterPluginBinding} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import { AbilityPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityPluginBinding';
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import BasicMessageChannel, { Reply } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BasicMessageChannel';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';
import { FlutterRenderer } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/renderer/FlutterRenderer';
import { SurfaceTextureEntry } from '@ohos/flutter_ohos/src/main/ets/view/TextureRegistry';
import { VideoPlayer } from './VideoPlayer';
import { VideoPlayerApi } from './VideoPlayerApi';
import { CreateMessage, LoopingMessage,
  MixWithOthersMessage,
  PlaybackSpeedMessage,
  PositionMessage,
  TextureMessage, VolumeMessage,
  wrapError } from './Messages';
import { PlayerModel } from './PlayerModel';
import HashMap from '@ohos.util.HashMap';
import { VideoPlayerApiCodec } from './VideoPlayerApiCodec';
import { FlutterState } from './VideoPlayerPlugin';
import resourceManager from '@ohos.resourceManager';
import common from '@ohos.app.ability.common';
import { media } from '@kit.MediaKit';
import { EventChannel } from '@ohos/flutter_ohos';

const TAG: string = "VideoPlayerApiImpl";
export class VideoPlayerApiImpl {
  private videoPlayers: HashMap<String, VideoPlayer> = new HashMap<String, VideoPlayer>();
  private flutterState: FlutterState | null = null;
  private binding: AbilityPluginBinding | null = null;
  private AudioFocus: Boolean = false;

  constructor(flutterState: FlutterState | null, binding: AbilityPluginBinding | null) {
    this.flutterState = flutterState;
    this.binding = binding;
  }

  private disposeAllPlayers(): void {
    this.videoPlayers.forEach(videoPlayer => videoPlayer?.release());
    this.videoPlayers.clear();
  }

  initialize(): void {
    Log.i(TAG, "enter initialize")
    this.disposeAllPlayers();
  }

  getContext(): common.UIAbilityContext {
    if (this.binding == null) {
      throw Error("Illegal binding or context state.");
    }
    return this.binding.getAbility().context;
  }

  async create(arg: CreateMessage): Promise<TextureMessage> {
    Log.i(TAG, "enter create");
    if (this.flutterState == null) {
      throw new Error("Illegal flutterState null.");
    }
    let playerModel = new PlayerModel();
    let flutterRenderer = this.flutterState.getTextureRegistry();
    let uri: string = arg.getUri();
    let asset: string = arg.getAsset();
    let textureId: number = flutterRenderer.getTextureId();
    Log.i(TAG, "enter getRawFd, textureId=" + textureId);
    let surfaceTextureEntry: SurfaceTextureEntry  = flutterRenderer.registerTexture(textureId);
    let eventChannel: EventChannel = new EventChannel(this.flutterState.getBinaryMessenger(), "flutter.io/videoPlayer/videoEvents" + textureId.toString());
    if (asset != null) {
      let rawFileDescriptor: resourceManager.RawFileDescriptor = await this.getContext().resourceManager.getRawFd("flutter_assets/" + asset);
      let videoPlayer = new VideoPlayer(playerModel, surfaceTextureEntry, rawFileDescriptor, null, eventChannel, this.AudioFocus);
      await videoPlayer.createAVPlayer();
      this.videoPlayers.set(textureId.toString(), videoPlayer);
    } else if (uri != null) {
      let videoPlayer = new VideoPlayer(playerModel, surfaceTextureEntry, null, uri, eventChannel, this.AudioFocus);
      await videoPlayer.createAVPlayer();
      this.videoPlayers.set(textureId.toString(), videoPlayer);
    }

    let textureMessage = new TextureMessage();
    textureMessage.setTextureId(textureId);
    return textureMessage;
  }

  dispose(arg: TextureMessage): void {
    let videoPlayer = this.videoPlayers.get(arg.getTextureId().toString());
    videoPlayer?.release();
    this.flutterState?.getTextureRegistry().unregisterTexture(arg.getTextureId().valueOf());
    this.videoPlayers.remove(arg.getTextureId().toString());
  }

  setLooping(arg: LoopingMessage) {
    let videoPlayer = this.videoPlayers.get(arg.getTextureId().toString());
    Log.d(TAG, "setLooping, id=" + arg.getTextureId() + ", videoPlayer=" + videoPlayer);
    videoPlayer?.setLooping(arg.getIsLooping());
  }

  setVolume(arg: VolumeMessage) {
    let videoPlayer = this.videoPlayers.get(arg.getTextureId().toString());
    Log.d(TAG, "setVolume, id=" + arg.getTextureId() + ", videoPlayer=" + videoPlayer);
    videoPlayer?.setVolume(arg.getVolume().valueOf());
  }

  setPlaybackSpeed(arg: PlaybackSpeedMessage) {
    let videoPlayer = this.videoPlayers.get(arg.getTextureId().toString());
    Log.d(TAG, "setPlaybackSpeed, id=" + arg.getTextureId() + ", videoPlayer=" + videoPlayer);
    let speed: media.PlaybackSpeed | null = arg.getSpeed();
    if (speed != null) {
      videoPlayer?.setSpeed(speed);
    } else {
      Log.w(TAG, "unsupported playBackSpeed!");
    }
  }

  play(arg: TextureMessage) {
    let videoPlayer = this.videoPlayers.get(arg.getTextureId().toString());
    Log.d(TAG, "play, id=" + arg.getTextureId() + ", videoPlayer=" + videoPlayer);
    if (videoPlayer != null) {
      videoPlayer.play();
    } else {
      Log.e(TAG, "play  videoPlayer is null");
    }

  }

  position(arg: TextureMessage): PositionMessage {
    let videoPlayer = this.videoPlayers.get(arg.getTextureId().toString());
    Log.d(TAG, "position, id=" + arg.getTextureId() + ", videoPlayer=" + videoPlayer);
    let positionMessage = new PositionMessage();
    positionMessage.setTextureId(arg.getTextureId());
    positionMessage.setPosition(videoPlayer?.getPosition() ?? 0);
    return positionMessage;
  }

  seekTo(arg: PositionMessage) {
    let videoPlayer = this.videoPlayers.get(arg.getTextureId().toString());
    Log.d(TAG, "seekTo, id=" + arg.getTextureId() + ", videoPlayer=" + videoPlayer);
    videoPlayer?.seekTo(arg.getPosition().valueOf());
  }

  pause(arg: TextureMessage) {
    let videoPlayer = this.videoPlayers.get(arg.getTextureId().toString());
    Log.d(TAG, "pause, id=" + arg.getTextureId() + ", videoPlayer=" + videoPlayer);
    videoPlayer?.pause();
  }

  setMixWithOthers(arg: MixWithOthersMessage) {
    Log.d(TAG, "set MixWithOthers:" + arg.getMixWithOthers());
    this.AudioFocus = arg.getMixWithOthers();
  }

  setup(binaryMessenger: BinaryMessenger): void {
    let api = this;
    if (this.flutterState == null) {
      return;
    }
    {
      const channel: BasicMessageChannel<Object> = new BasicMessageChannel<Object>(
        binaryMessenger, "dev.flutter.pigeon.OhosVideoPlayerApi.initialize", VideoPlayerApiCodec.INSTANCE);
      channel.setMessageHandler({
        onMessage(msg: Object, reply: Reply<Object>): void {
          let wrapped = new Array<Object>();
          try {
            api.initialize();
            wrapped.push(new TextureMessage());
            reply.reply(wrapped);
          } catch (err) {
            let wrappedError = wrapError(err);
            reply.reply(wrappedError);
          }
        }
      });
    }
    {
      const channel: BasicMessageChannel<Object> = new BasicMessageChannel<Object>(
        binaryMessenger, "dev.flutter.pigeon.OhosVideoPlayerApi.create", VideoPlayerApiCodec.INSTANCE);
      channel.setMessageHandler({
        onMessage(msg: Object, reply: Reply<Object>): void {
          let wrapped = new Array<Object>();
          let args = msg as Array<Object>;
          let createMsg = args[0] as CreateMessage;
          try {
            api.create(createMsg).then((textureMessage: TextureMessage) => {
              wrapped.push(textureMessage);
              reply.reply(wrapped);
            });
          } catch (err) {
            let wrappedError = wrapError(err);
            reply.reply(wrappedError);
          }
        }
      });
    }
    {
      const channel: BasicMessageChannel<Object> = new BasicMessageChannel<Object>(
        binaryMessenger, "dev.flutter.pigeon.OhosVideoPlayerApi.dispose", VideoPlayerApiCodec.INSTANCE);
      channel.setMessageHandler({
        onMessage(msg: Object, reply: Reply<Object>): void {
          let wrapped = new Array<Object>();
          let args = msg as Array<Object>;
          let textureMsg = args[0] as TextureMessage;
          try {
            api.dispose(textureMsg);
            wrapped.push(new TextureMessage());
            reply.reply(wrapped);
          } catch (err) {
            let wrappedError = wrapError(err);
            reply.reply(wrappedError);
          }
        }
      });
    }
    {
      const channel: BasicMessageChannel<Object> = new BasicMessageChannel<Object>(
        binaryMessenger, "dev.flutter.pigeon.OhosVideoPlayerApi.setLooping", VideoPlayerApiCodec.INSTANCE);
      channel.setMessageHandler({
        onMessage(msg: Object, reply: Reply<Object>): void {
          let wrapped = new Array<Object>();
          let args = msg as Array<Object>;
          let loopMsg = args[0] as LoopingMessage;
          try {
            api.setLooping(loopMsg);
            wrapped.push(new TextureMessage());
            reply.reply(wrapped);
          } catch (err) {
            let wrappedError = wrapError(err);
            reply.reply(wrappedError);
          }
        }
      });
    }
    {
      const channel: BasicMessageChannel<Object> = new BasicMessageChannel<Object>(
        binaryMessenger, "dev.flutter.pigeon.OhosVideoPlayerApi.setVolume", VideoPlayerApiCodec.INSTANCE);
      channel.setMessageHandler({
        onMessage(msg: Object, reply: Reply<Object>): void {
          let wrapped = new Array<Object>();
          let args = msg as Array<Object>;
          let volumeMsg = args[0] as VolumeMessage;
          try {
            api.setVolume(volumeMsg);
            wrapped.push(new TextureMessage());
            reply.reply(wrapped);
          } catch (err) {
            let wrappedError = wrapError(err);
            reply.reply(wrappedError);
          }
        }
      });
    }
    {
      const channel: BasicMessageChannel<Object> = new BasicMessageChannel<Object>(
        binaryMessenger, "dev.flutter.pigeon.OhosVideoPlayerApi.setPlaybackSpeed", VideoPlayerApiCodec.INSTANCE);
      channel.setMessageHandler({
        onMessage(msg: Object, reply: Reply<Object>): void {
          let wrapped = new Array<Object>();
          let args = msg as Array<Object>;
          let playbackSpeedMsg = args[0] as PlaybackSpeedMessage;
          try {
            api.setPlaybackSpeed(playbackSpeedMsg);
            wrapped.push(new TextureMessage());
            reply.reply(wrapped);
          } catch (err) {
            let wrappedError = wrapError(err);
            reply.reply(wrappedError);
          }
        }
      });
    }
    {
      const channel: BasicMessageChannel<Object> = new BasicMessageChannel<Object>(
        binaryMessenger, "dev.flutter.pigeon.OhosVideoPlayerApi.play", VideoPlayerApiCodec.INSTANCE);
      channel.setMessageHandler({
        onMessage(msg: Object, reply: Reply<Object>): void {
          let wrapped = new Array<Object>();
          let args = msg as Array<Object>;
          let textureMsg = args[0] as TextureMessage;
          try {
            api.play(textureMsg);
            wrapped.push(new TextureMessage());
            reply.reply(wrapped);
          } catch (err) {
            let wrappedError = wrapError(err);
            reply.reply(wrappedError);
          }
        }
      });
    }
    {
      const channel: BasicMessageChannel<Object> = new BasicMessageChannel<Object>(
        binaryMessenger, "dev.flutter.pigeon.OhosVideoPlayerApi.position", VideoPlayerApiCodec.INSTANCE);
      channel.setMessageHandler({
        onMessage(msg: Object, reply: Reply<Object>): void {
          let wrapped = new Array<Object>();
          let args = msg as Array<Object>;
          let textureMsg = args[0] as TextureMessage;
          try {
            let positionMessage: PositionMessage = api.position(textureMsg);
            wrapped.push(positionMessage);
            reply.reply(wrapped);
          } catch (err) {
            let wrappedError = wrapError(err);
            reply.reply(wrappedError);
          }
        }
      });
    }
    {
      const channel: BasicMessageChannel<Object> = new BasicMessageChannel<Object>(
        binaryMessenger, "dev.flutter.pigeon.OhosVideoPlayerApi.seekTo", VideoPlayerApiCodec.INSTANCE);
      channel.setMessageHandler({
        onMessage(msg: Object, reply: Reply<Object>): void {
          let wrapped = new Array<Object>();
          let args = msg as Array<Object>;
          let positionMsg = args[0] as PositionMessage;
          try {
            api.seekTo(positionMsg);
            wrapped.push(new TextureMessage());
            reply.reply(wrapped);
          } catch (err) {
            let wrappedError = wrapError(err);
            reply.reply(wrappedError);
          }
        }
      });
    }
    {
      const channel: BasicMessageChannel<Object> = new BasicMessageChannel<Object>(
        binaryMessenger, "dev.flutter.pigeon.OhosVideoPlayerApi.pause", VideoPlayerApiCodec.INSTANCE);
      channel.setMessageHandler({
        onMessage(msg: Object, reply: Reply<Object>): void {
          let wrapped = new Array<Object>();
          let args = msg as Array<Object>;
          let textureMsg = args[0] as TextureMessage;
          try {
            api.pause(textureMsg);
            wrapped.push(new TextureMessage());
            reply.reply(wrapped);
          } catch (err) {
            let wrappedError = wrapError(err);
            reply.reply(wrappedError);
          }
        }
      });
    }
    {
      const channel: BasicMessageChannel<Object> = new BasicMessageChannel<Object>(
        binaryMessenger, "dev.flutter.pigeon.OhosVideoPlayerApi.setMixWithOthers", VideoPlayerApiCodec.INSTANCE);
      channel.setMessageHandler({
        onMessage(msg: Object, reply: Reply<Object>): void {
          let wrapped = new Array<Object>();
          let args = msg as Array<Object>;
          let mixWithOthersMsg = args[0] as MixWithOthersMessage;
          try {
            api.setMixWithOthers(mixWithOthersMsg);
            wrapped.push(new TextureMessage());
            reply.reply(wrapped);
          } catch (err) {
            let wrappedError = wrapError(err);
            reply.reply(wrappedError);
          }
        }
      });
    }
  }

}