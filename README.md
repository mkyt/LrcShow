# LrcShow

<img src="https://raw.github.com/wiki/mkyt/LrcShow/images/ss.jpg" width="340px">

## What is this?
LrcShow displays synchronized lyrics for iTunes songs on macOS.


## Usage

### Lyrics file specifications
Lyrics files are plain text encoded in UTF-8. LrcShow supports three types of lyrics files, namely, **karaoke-sync** (timecodes added to the fragments of lyrics; suffix `.kra`), **line-sync** (timecodes only at the beginning of the lines; suffix `.lrc`) and **unsynchronized** (plain text with no timecodes; suffix `.txt`).

Timecodes are formatted as `[mm:ss:cc]` (2-digits each for minutes, seconds and centiseconds).

#### Example of karaoke-sync file

```
...
[01:11:09]And [01:11:43]that's [01:11:70]what [01:12:01]they [01:12:22]don't [01:12:36]see
...
```

In karaoke-sync (`.kra`) files, timecodes are added not only at the beginning but also in the middle of the lines. In the above example, timecode `[01:11:70]` corresponds to the beginning of the phrase 'what'.

#### Example of line-sync file

```
...
[00:40:39]Surely not what you thought it
...
```

In line-sync (`.lrc`) files, timecodes are added only at the beginning of the lines.


### Lyrics file search location
Lyrics files must be placed in the same directory and basenames (names without suffix) must be the same as the corresponding music file (e.g. when playing `.../Music/Fastball/All The Pain Money Can Buy/01 The Way.mp3`, files `01 The Way.kra`, `01 The Way.lrc` and `01 The Way.txt` inside the directory `.../Music/Fastball/All The Pain Money Can Buy` are candidate paths for the lyrics files).

Loading lyrics data from metadata (ID3v2, APE, MP4, etc) embedded in music files is not supported.


## License
MIT
