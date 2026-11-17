//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import geolocator_apple
import package_info_plus
import record_darwin
import shared_preferences_foundation
import sqflite_darwin
import video_player_avfoundation

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  GeolocatorPlugin.register(with: registry.registrar(forPlugin: "GeolocatorPlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  RecordDarwinPlugin.register(with: registry.registrar(forPlugin: "RecordDarwinPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  SqflitePlugin.register(with: registry.registrar(forPlugin: "SqflitePlugin"))
  VideoPlayerPlugin.register(with: registry.registrar(forPlugin: "VideoPlayerPlugin"))
}
