# Third-party data

## TV-B-Gone / Arduino-TV-B-Gone

The application uses the TV-B-Gone infrared power-code database from the
Arduino-TV-B-Gone project by Ken Shirriff, based on TV-B-Gone firmware by
Mitch Altman and Limor Fried.

The upstream source identifies the TV-B-Gone code/data as distributed under
Creative Commons Attribution-ShareAlike 2.5 (CC BY-SA 2.5).

Upstream:
https://github.com/shirriff/Arduino-TV-B-Gone

## Flipper-IRDB

The expanded television, air-conditioner and projector POWER/OFF database is
generated from Lucaslhm/Flipper-IRDB.

The repository's LICENSE file applies CC0 1.0 Universal to that database.

This project currently pins Flipper-IRDB commit:

d126fb1b6f1e114c52b4a8c19839ea65e3a9c24d

Upstream:
https://github.com/Lucaslhm/Flipper-IRDB

The generator preserves RAW signals exactly and converts only a conservative
set of common parsed protocols. Unsupported parsed protocols are skipped rather
than approximated.
