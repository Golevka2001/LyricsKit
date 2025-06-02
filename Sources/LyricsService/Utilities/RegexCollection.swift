import Foundation
import RegexBuilder

enum RegexCollection {
    static let id3Tag = Regex {
        /^/
        NegativeLookahead {
          Regex {
            "["
            Optionally(CharacterClass.anyOf("+-"))
            OneOrMore(.digit)
            ":"
            OneOrMore(.digit)
            Optionally {
              Regex {
                "."
                OneOrMore(.digit)
              }
            }
            "]"
          }
        }
        "["
        Capture {
          OneOrMore(.reluctant) {
            /./
          }
        }
        ":"
        Capture {
          OneOrMore {
            /./
          }
        }
        "]"
        /$/
      }
      .anchorsMatchLineEndings()

}
