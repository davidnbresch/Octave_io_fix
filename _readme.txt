this folder contains the CRUDE work-around for cases where the Octave package io-2.2.6.tar can not be installed by a call like

 pkg install -forge io -local -auto

neither with

 pkg install {local_doenload}/io-2.2.6.tar -local -auto

where io-2.2.6.tar has been fetched from http://octave.sourceforge.net

Please note that this approach, i.e. to ‘mock install’ a package as a climada module, should be avoided by all means, only to be resorted to in case pkg fails, as it did on OS X Yosemite (Version 10.10.1) as per 3 Jan 2015.

Please re-check regularly for proper installation of io and then remove this local patch.

david.bresch@gmail.com
