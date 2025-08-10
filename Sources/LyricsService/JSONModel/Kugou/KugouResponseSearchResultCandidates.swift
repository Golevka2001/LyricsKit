//
//  KugouResponseSearchResult.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation

struct KugouResponseSearchResultCandidates: Decodable {
    let candidates: [Item]
    
    /*
    let info: String
    let status: Int
    let proposal: String
    let keyword: String
     */
    
    struct Item: Decodable {
        let id: String
        let accesskey: String
        let song: String
        let singer: String
        let duration: Int // in msec
        
        /*
        let adjust: Int
        let hitlayer: Int
        let krctype: Int
        let language: String
        let nickname: String
        let originame: String
        let origiuid: String
        let score: Int
        let soundname: String
        let sounduid: String
        let transname: String
        let transuid: String
        let uid: String
         */
        
        // let parinfo: [Any]
    }
}
import Foundation

struct KugouResponseSearchResult: Codable {
    struct Data: Codable {
        struct Info: Codable {
            struct TransParam: Codable {
                struct Classmap: Codable {
                    let attr0: Int
                }

                struct Qualitymap: Codable {
                    let attr0: Date
                    let attr1: Int
                }

                struct Ipmap: Codable {
                    let attr0: Date
                }

                struct HashOffset: Codable {
                    let clipHash: String
                    let startByte: Int
                    let endMs: Int
                    let endByte: Int
                    let fileType: Int
                    let startMs: Int
                    let offsetHash: String

                    private enum CodingKeys: String, CodingKey {
                        case clipHash = "clip_hash"
                        case startByte = "start_byte"
                        case endMs = "end_ms"
                        case endByte = "end_byte"
                        case fileType = "file_type"
                        case startMs = "start_ms"
                        case offsetHash = "offset_hash"
                    }
                }

                let cpyGrade: Int?
                let classmap: Classmap
                let language: String
                let cpyAttr0: Int
                let musicpackAdvance: Int
                let ogg128Filesize: Int?
                let displayRate: Int
                let ogg320Filesize: Int?
                let qualitymap: Qualitymap
                let unionCover: URL?
                let ogg128Hash: String?
                let cid: Int
                let ogg320Hash: String?
                let display: Int
                let ipmap: Ipmap
                let hashOffset: HashOffset?
                let hashMultitrack: String?
                let payBlockTpl: Int
                let cpyLevel: Int?
                let songnameSuffix: String?
                let allQualityFree: Int?
                let freeForAd: Int?

                private enum CodingKeys: String, CodingKey {
                    case cpyGrade = "cpy_grade"
                    case classmap
                    case language
                    case cpyAttr0 = "cpy_attr0"
                    case musicpackAdvance = "musicpack_advance"
                    case ogg128Filesize = "ogg_128_filesize"
                    case displayRate = "display_rate"
                    case ogg320Filesize = "ogg_320_filesize"
                    case qualitymap
                    case unionCover = "union_cover"
                    case ogg128Hash = "ogg_128_hash"
                    case cid
                    case ogg320Hash = "ogg_320_hash"
                    case display
                    case ipmap
                    case hashOffset = "hash_offset"
                    case hashMultitrack = "hash_multitrack"
                    case payBlockTpl = "pay_block_tpl"
                    case cpyLevel = "cpy_level"
                    case songnameSuffix = "songname_suffix"
                    case allQualityFree = "all_quality_free"
                    case freeForAd = "free_for_ad"
                }
            }

            let hash: String
            let sqfilesize: Int
            let sourceid: Int
            let payTypeSq: Int
            let bitrate: Int
            let ownercount: Int
            let pkgPriceSq: Int
            let songname: String
            let albumName: String
            let songnameOriginal: String
            let accompany: Int
            let sqhash: String
            let failProcess: Int
            let payType: Int
            let rpType: String
            let albumID: String
            let othernameOriginal: String
            let mvhash: String
            let extname: String
            let price320: Int
            let _320hash: String
            let topic: String
            let othername: String
            let isnew: Int
            let foldType: Int
            let oldCpy: Int
            let srctype: Int
            let singername: String
            let albumAudioID: Int
            let duration: Int
            let _320filesize: Int
            let pkgPrice320: Int
            let audioID: Int
            let feetype: Int
            let price: Int
            let filename: String
            let source: String
            let priceSq: Int
            let failProcess320: Int
            let transParam: TransParam
            let pkgPrice: Int
            let payType320: Int
            let topicURL: String
            let m4afilesize: Int
            let rpPublish: Int
            let privilege: Int
            let filesize: Int
            let isoriginal: Int
            let _320privilege: Int
            let sqprivilege: Int
            let failProcessSq: Int

            private enum CodingKeys: String, CodingKey {
                case hash
                case sqfilesize
                case sourceid
                case payTypeSq = "pay_type_sq"
                case bitrate
                case ownercount
                case pkgPriceSq = "pkg_price_sq"
                case songname
                case albumName = "album_name"
                case songnameOriginal = "songname_original"
                case accompany = "Accompany"
                case sqhash
                case failProcess = "fail_process"
                case payType = "pay_type"
                case rpType = "rp_type"
                case albumID = "album_id"
                case othernameOriginal = "othername_original"
                case mvhash
                case extname
                case price320 = "price_320"
                case _320hash = "320hash"
                case topic
                case othername
                case isnew
                case foldType = "fold_type"
                case oldCpy = "old_cpy"
                case srctype
                case singername
                case albumAudioID = "album_audio_id"
                case duration
                case _320filesize = "320filesize"
                case pkgPrice320 = "pkg_price_320"
                case audioID = "audio_id"
                case feetype
                case price
                case filename
                case source
                case priceSq = "price_sq"
                case failProcess320 = "fail_process_320"
                case transParam = "trans_param"
                case pkgPrice = "pkg_price"
                case payType320 = "pay_type_320"
                case topicURL = "topic_url"
                case m4afilesize
                case rpPublish = "rp_publish"
                case privilege
                case filesize
                case isoriginal
                case _320privilege = "320privilege"
                case sqprivilege
                case failProcessSq = "fail_process_sq"
            }
        }

        let timestamp: Date
        let tab: String
        let forcecorrection: Int
        let correctiontype: Int
        let total: Int
        let istag: Int
        let allowerr: Int
        let info: [Info]
        let correctiontip: String
        let istagresult: Int
    }

    let status: Int
    let errcode: Int
    let data: Data
    let error: String
}
