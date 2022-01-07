use anyhow::*;
use dirs::home_dir;
use std::collections::HashSet;
use std::fs::{read_to_string, write};
use std::path::PathBuf;
use structopt::StructOpt;
use unicode_segmentation::UnicodeSegmentation;

enum SplitFileMode {
    RemoveExtension,
    EmojiExtension,
}

#[derive(Clone)]
struct EmojiIndex(HashSet<String>);

impl EmojiIndex {
    pub fn new(file_path: PathBuf) -> Result<Self> {
        let mut result = HashSet::<String>::new();
        for line in read_to_string(file_path)?.split('\n') {
            if !line.is_empty() {
                result.insert(
                    UnicodeSegmentation::graphemes(line, true).collect::<Vec<&str>>()[0]
                        .to_string(),
                );
            }
        }
        Ok(Self(result))
    }
}

fn split_file(
    infile_path: PathBuf,
    selected_emoji: &str,
    index: &EmojiIndex,
    mode: SplitFileMode,
) -> Result<()> {
    let outfile_path = infile_path.with_extension(match mode {
        SplitFileMode::RemoveExtension => "",
        SplitFileMode::EmojiExtension => selected_emoji,
    });

    let wildcard_emoji = "✴️";

    #[derive(PartialEq, Eq)]
    enum FsmState {
        CopyToOutput,
        ReadEmojiSequence,
        OmitFromOutput,
        ReadEmojiSequenceContainingSelected,
    }

    let infile_text = read_to_string(infile_path.clone())?;
    let mut outbuf = String::new();
    let mut state = FsmState::CopyToOutput;
    for grapheme_cluster in UnicodeSegmentation::graphemes(infile_text.as_str(), true) {
        if state == FsmState::CopyToOutput {
            if index.0.contains(grapheme_cluster) {
                if grapheme_cluster == wildcard_emoji || grapheme_cluster == selected_emoji {
                    state = FsmState::ReadEmojiSequenceContainingSelected;
                } else {
                    state = FsmState::ReadEmojiSequence;
                }
            } else {
                outbuf += grapheme_cluster;
            }
        } else if state == FsmState::ReadEmojiSequence {
            if index.0.contains(grapheme_cluster) {
                if grapheme_cluster == wildcard_emoji || grapheme_cluster == selected_emoji {
                    state = FsmState::ReadEmojiSequenceContainingSelected;
                }
            } else {
                state = FsmState::OmitFromOutput;
            }
        } else if state == FsmState::OmitFromOutput {
            if index.0.contains(grapheme_cluster) {
                if grapheme_cluster == wildcard_emoji || grapheme_cluster == selected_emoji {
                    state = FsmState::ReadEmojiSequenceContainingSelected;
                } else {
                    state = FsmState::ReadEmojiSequence;
                }
            }
        } else if state == FsmState::ReadEmojiSequenceContainingSelected
            && !index.0.contains(grapheme_cluster)
        {
            state = FsmState::CopyToOutput;
            outbuf += grapheme_cluster;
        }
    }
    if !outbuf.is_empty() {
        println!(
            "Processed: {} -> {}",
            infile_path.display(),
            outfile_path.display()
        );
        write(outfile_path, outbuf)?;
    }
    Ok(())
}

#[derive(StructOpt)]
#[structopt(
    name = "emojisplit",
    about = "Split up a template config file based on sections delineated by emojis."
)]
struct Cli {
    #[structopt(long, default_value = "✴️")]
    emoji: String,
    #[structopt(long)]
    split: bool,
    #[structopt(name = "FILE", parse(from_os_str))]
    infile: PathBuf,
}

enum OutputMode {
    SelectedEmoji(String),
    EveryEmoji,
}

struct EmojiOpts {
    mode: OutputMode,
    infile: PathBuf,
}

impl EmojiOpts {
    pub fn new(cli: &Cli) -> Self {
        Self {
            mode: if cli.split {
                OutputMode::EveryEmoji
            } else {
                OutputMode::SelectedEmoji(cli.emoji.clone())
            },
            infile: cli.infile.clone(),
        }
    }
}

fn main() -> Result<()> {
    let args = Cli::from_args();
    let opts = EmojiOpts::new(&args);
    println!("Processing: {}", opts.infile.display());
    let emoji_index_path = home_dir().unwrap().join(".config/emojisplit/emoji.index");
    let emoji_index = EmojiIndex::new(emoji_index_path)?;
    match opts.mode {
        OutputMode::SelectedEmoji(selected_emoji) => split_file(
            opts.infile,
            &selected_emoji,
            &emoji_index,
            SplitFileMode::RemoveExtension,
        )?,
        OutputMode::EveryEmoji => {
            for indexed_emoji in emoji_index.0.clone().into_iter() {
                split_file(
                    opts.infile.clone(),
                    &indexed_emoji,
                    &emoji_index,
                    SplitFileMode::EmojiExtension,
                )?
            }
        }
    };
    Ok(())
}
