//
//  Service.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation

extension LyricsProviders {
    
    public enum Service {
        case netease
        case qq
        case kugou
        case gecimi
        case syair
        case lrclib
        case spotify(accessToken: String)

        public var displayName: String {
            switch self {
            case .netease: return "Netease"
            case .qq: return "QQMusic"
            case .kugou: return "Kugou"
            case .gecimi: return "Gecimi"
            case .syair: return "Syair"
            case .lrclib: return "LRCLIB"
            case .spotify: return "Spotify"
            }
        }
        
        public static var noAuthenticationRequiredServices: [Service] {
            [
                .netease,
                .qq,
                .kugou,
                .lrclib,
            ]
        }
    }
}

extension LyricsProviders.Service {
    
    func create() -> LyricsProvider {
        switch self {
        case .netease:  return LyricsProviders.NetEase()
        case .qq:       return LyricsProviders.QQMusic()
        case .kugou:    return LyricsProviders.Kugou()
        case .gecimi:   return LyricsProviders.Gecimi()
        case .spotify(let accessToken): return LyricsProviders.Spotify(accessToken: accessToken)
        #if canImport(Darwin)
        case .syair:    return LyricsProviders.Syair()
        #endif
        default:        return LyricsProviders.Unsupported()
        }
    }
}
