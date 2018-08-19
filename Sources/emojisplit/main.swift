import Foundation
import Utility

// The first argument is always the executable, ArgumentParser complains if not dropped
let arguments = Array(ProcessInfo.processInfo.arguments.dropFirst())

let parser = ArgumentParser(usage: "INFILE -e 🙂",
                            overview: "Split up a template config file based on sections delinated by emojis")
let emojiArgParse: OptionArgument<String> = parser.add(option: "--emoji", shortName: "-e", kind: String.self, usage: "Selected emoji")
let infileArgParse : PositionalArgument<String> = parser.add(positional: "INFILE", kind: String.self, usage: "Config file template to process")

let parsedArguments = try parser.parse(arguments)
let emojiArgument = parsedArguments.get(emojiArgParse)
let emoji : Character = emojiArgument![emojiArgument!.startIndex]
let infile = parsedArguments.get(infileArgParse)

enum FSMState {
    case copyToOutput;
    case readEmojiSequence;
    case omitFromOutput;
    case readEmojiSequenceContainingSelected;
}

do {
    let emojiIndex : [Character] = try String(contentsOfFile: "/home/eddie/.config/emojisplit/emoji.index", encoding: String.Encoding.utf8).split(separator: "\n").map { $0[$0.startIndex] }
    let infileText = try String(contentsOfFile: infile!, encoding: String.Encoding.utf8)
    var outbuf = ""
    var state = FSMState.copyToOutput
    for char in infileText {
        if (state == FSMState.copyToOutput) {
            if emojiIndex.contains(char) {
                if char == emoji {
                    state = FSMState.readEmojiSequenceContainingSelected;
                } else {
                    state = FSMState.readEmojiSequence;
                }
            } else {
                outbuf += String(char)
            }
        } else if (state == FSMState.readEmojiSequence) {
            if emojiIndex.contains(char) {
                if char == emoji {
                    state = FSMState.readEmojiSequenceContainingSelected;
                }
            }
            else {
                state = FSMState.omitFromOutput;
            }
        } else if (state == FSMState.omitFromOutput) {
            if emojiIndex.contains(char) {
                if char == emoji {
                    state = FSMState.readEmojiSequenceContainingSelected;
                } else {
                    state = FSMState.readEmojiSequence;
                }
            }
        } else if (state == FSMState.readEmojiSequenceContainingSelected) {
            if !emojiIndex.contains(char) {
                state = FSMState.copyToOutput;
                outbuf += String(char)
            }
        }
        let outfilePath = URL(fileURLWithPath: infile!).deletingPathExtension()
        try outbuf.write(to: outfilePath, atomically: false, encoding: String.Encoding.utf8)
    }
} catch {
}
