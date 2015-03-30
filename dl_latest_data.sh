#!/bin/sh
# This script downloads the latest tzdata files from www.iana.org and puts them
# in the source_data directory, overwriting the existing ones.
# We do not need all the files, so we delete the ones we do not use.
#
# Using grep, the first release line is extracted from the NEWS file and
# put in the file RELEASE_LINE_FROM_NEWS. This way we know which release
# the tzdata is from.
mkdir -p source_data/       \
  && cd source_data/        \
  && wget 'https://www.iana.org/time-zones/repository/tzdata-latest.tar.gz' \
  && tar -zxvf tzdata-latest.tar.gz                    \
  && rm tzdata-latest.tar.gz                           \
  && rm factory leap-seconds.* leapseconds leapseconds.* Makefile iso3166.tab README systemv yearistype.sh zone.tab backzone checktab.awk checklinks.awk CONTRIBUTING Theory zoneinfo2tdf.pl \
  && grep -o 'Release [0-9]\{4\}.*' NEWS | head -1 > RELEASE_LINE_FROM_NEWS \
  && rm NEWS
