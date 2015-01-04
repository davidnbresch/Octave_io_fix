## Copyright (C) 2010,2011,2012,2013 Philip Nienhuis <prnienhuis -aT- users.sf.net>
##
## This program is free software; you can redistribute it and/or modify it under
## the terms of the GNU General Public License as published by the Free Software
## Foundation; either version 3 of the License, or (at your option) any later
## version.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
## FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License along with
## this program; if not, see <http://www.gnu.org/licenses/>.

## __JOD_getusedrange__

## Author: Philip <Philip@DESKPRN>
## Created: 2010-05-25
## Last updates:
## 2010-05-31 Fixed ignoring table-covered-cells; fixed count of sheets comprising just A1:A1
##            Added option for wsh being a string argument 
## 2010-08-12 Little textual adaptations
## 2010-11-13 Catched jOpenDocument bug (1.2bx) where string cells have no office:value-type
##     ''     attrb set (by JOD). Somehow OTK is more robust as it catches these cells
## 2012-04-09 Fixed rowrepcnt (str2num not applied to tablerow)
## 2012-04-18 Added getUsedRange() method for JOD 1.3x and above 
## 2012-10-12 Renamed & moved into ./private
## 2012-10-24 Style fixes
## 2013-01-20 Clarify internal code comments
## 2013-09-29 Split native Octave part into separate private/ function

function [ trow, brow, lcol, rcol ] = __JOD_getusedrange__ (ods, wsh)

  ## This function works for older jOpendocument (<= 1.2) by virtue of sheets
  ## in JOD actually being a Java string.
  ## It works outside of the Java memory/heap space which is an added benefit...
  ## (Read: it is one big dirty hack... prone to crash Java on BIG spreadsheets)
  ## For newer jOpenDocument 1.3b1+ there's a newer and much faster method.

  if (isnumeric (wsh))
    sh = char (ods.workbook.getSheet (wsh - 1));
  else
    sh = char (ods.workbook.getSheet (wsh));
  endif

  try
    ## Let's see if we have JOD v. 1.3x. If not, next call fails & we'll fall
    ## back to the old hack
    sh_rng = char (sh.getUsedRange ());
    if (isempty (sh_rng))
      ## Empty sheet
      trow = brow = lcol = rcol = 0;
    else
      ## Strip sheet name
      sh_rng = sh_rng(length (sh.getName) + 2 : end);
      ## Get rid of period
      sh_rng = strrep (sh_rng, ".", "");
      [~, nr, nc, trow, lcol] = parse_sp_range (sh_rng);
      brow = trow + nr - 1;
      rcol = lcol + nc - 1;
    endif
  
  catch
    ## Fall back to the old hack :-(    (now in private/ function)
    sh = char (sh);
    [trow, brow, lcol, rcol ] = __ods_get_sheet_dims__ (sh);

  end_try_catch

endfunction
