Octave_io_fix - a special climada module
=============

Fix for io in Octave if problems with installing properly (using pkg)

This climada module contains the CRUDE work-around for cases where the Octave package io-2.2.6.tar can not be installed by a call like

 pkg install -forge io -local -auto

neither with

 pkg install {local_download}/io-2.2.6.tar -local -auto

where io-2.2.6.tar has been fetched from http://octave.sourceforge.net and stored locally to {local_download}/io-2.2.6.tar

Just put this climada module into climada_modules (on the same level as core climada) or into climada/modules (within core climada). See climada manual about climada modules in general.

Please note that this approach, i.e. to ‘mock install’ a package as a climada module, should be avoided by all means, only to be resorted to in case pkg fails, as it did on OS X Yosemite (Version 10.10.1) as per 3 Jan 2015.

Please re-check regularly for proper installation of io and then remove this local patch.

david.bresch@gmail.com

Notre: As soon as no known issues with Octave io exist any more, this module will be removed and support discontinued.
