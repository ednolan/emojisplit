import Foundation
import Commander

enum SplitFileMode {
    case removeExtension
    case emojiExtension
}

func splitFile(_ infile: URL, _ selectedEmoji: Character, _ index: [Character], _ mode: SplitFileMode) {

    let outfilePath:URL = {
        switch mode {
        case .removeExtension: return infile.deletingPathExtension()
        case .emojiExtension: return infile.deletingPathExtension().appendingPathExtension(String(selectedEmoji))
        }
    }()

    let wildcardEmoji : Character = "✴️"

    enum FSMState {
        case copyToOutput;
        case readEmojiSequence;
        case omitFromOutput;
        case readEmojiSequenceContainingSelected;
    }

    do {
        let infileText = try String(contentsOf: infile, encoding: String.Encoding.utf8)
        var outbuf = ""
        var state = FSMState.copyToOutput
        for char in infileText {
            if (state == FSMState.copyToOutput) {
                if index.contains(char) {
                    if char == wildcardEmoji || char == selectedEmoji {
                        state = FSMState.readEmojiSequenceContainingSelected;
                    } else {
                        state = FSMState.readEmojiSequence;
                    }
                } else {
                    outbuf += String(char)
                }
            } else if (state == FSMState.readEmojiSequence) {
                if index.contains(char) {
                    if char == wildcardEmoji || char == selectedEmoji {
                        state = FSMState.readEmojiSequenceContainingSelected;
                    }
                }
                else {
                    state = FSMState.omitFromOutput;
                }
            } else if (state == FSMState.omitFromOutput) {
                if index.contains(char) {
                    if char == wildcardEmoji || char == selectedEmoji {
                        state = FSMState.readEmojiSequenceContainingSelected;
                    } else {
                        state = FSMState.readEmojiSequence;
                    }
                }
            } else if (state == FSMState.readEmojiSequenceContainingSelected) {
                if !index.contains(char) {
                    state = FSMState.copyToOutput;
                    outbuf += String(char)
                }
            }
        }
        if (!outbuf.isEmpty) {
            print("Processed: ", infile, " -> ", outfilePath)
            try outbuf.write(to: outfilePath, atomically: false, encoding: String.Encoding.utf8)
        }
    } catch {
        print(error)
    }
}

let main = command(
  Option("emoji", default: "✴️"),
  Flag("split", description:"Produce an outfile for every emoji in index"),
  Argument<String>("INFILE", description:"File template to process")
) { emoji, split, infile in
    //let parser = ArgumentParser(usage: "INFILE -e 🙂",
    //                            overview: "Split up a template config file based on sections delinated by emojis")

    struct EmojiOpts {
        enum OutputMode {
            case selectedEmoji(Character)
            case everyEmoji
        }
        var mode : OutputMode
        var infile : URL
        init (_ emoji: String, _ split: Bool, _ infile: String) {
            self.mode = split ? EmojiOpts.OutputMode.everyEmoji
                              : EmojiOpts.OutputMode.selectedEmoji(emoji[emoji.startIndex])
            self.infile = URL(fileURLWithPath:infile)
        }
    }
    let opts = EmojiOpts(emoji, split, infile)

    print("Processing: ", opts.infile)

    var emojiIndexPath = URL(fileURLWithPath: NSString(string: "~").expandingTildeInPath)
    emojiIndexPath.appendPathComponent("/.config/emojisplit/emoji.index")
    let emojiIndex : [Character] = try String(contentsOf: emojiIndexPath, encoding: String.Encoding.utf8).split(separator: "\n").map { $0[$0.startIndex] }

    switch opts.mode {
    case let .selectedEmoji(selectedEmoji):
        splitFile(opts.infile, selectedEmoji, emojiIndex, SplitFileMode.removeExtension)
    case .everyEmoji:
        for indexedEmoji in emojiIndex {
            splitFile(opts.infile, indexedEmoji, emojiIndex, SplitFileMode.emojiExtension)
        }
    }
}

main.run()
