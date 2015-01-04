## Copyright (C) 2013,2014 Markus Bergholz
## Parts Copyright (C) 2013,2014 Philip Nienhuis
##
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with Octave; see the file COPYING.  If not, see
## <http://www.gnu.org/licenses/>.

## -*- texinfo -*- 
## @deftypefn {Function File} [ @var{raw}, @var{xls}, @var rstatus} ] = __OCT_xlsx2oct__ (@var{xlsx}, @var{wsh}, @var{range}, @spsh_opts)
## Internal function for reading data from an xlsx worksheet
##
## @seealso{}
## @end deftypefn

## Author: Markus Bergholz <markuman+xlsread@gmail.com>
## Created: 2013-10-04
## Updates:
## 2010-10-20 Transplanted & adapted section for text string worksheet names (PRN)
##     ''     Much code restyled into Octave coding conventions
## 2013-10-28 More fixes by Markus
## 2013-11-02 (PRN) Added rstatus return arg (needed by xlsread.m)
## 2013-11-04 (PRN) Adapted regexp search strings to include (numeric) formulas and booleans
##     ''     (PRN) Commented out code for only numeric data until contiguousness is checked
## 2013-11-08 (PRN) Fix reading date/time
##     ''     Rework code to keep cell array, not a numeric matrix
##     ''     Add reading formulas
## 2013-11-09 (PRN) Add reading strings & formulas
##     ''     Rearrange code
##     ''     Prepare for fast reading (still uncommented)
##     ''     Implement selected range (still rough ATM but for devs the easiest)
## 2013-11-10 (PRN) Fix typo preventing reading named worksheets instead of indices
## 2013-11-13 (PRN) Pretty text output
## 2013-11-15 (PRN) Catch empty sharedString.xml (means no fixed strings)
## 2013-11-16 (PRN) Replace fgetl calls by fread to cope with EOLs
## 2013-12-12 (PRN) Adapted regular expressions for formulas_as_text to cope with POI
##     ''     Adapted regular expression for shared strings to cope with empty strings
## 2013-12-14 (PRN) Adapt regexpr for values (include "n" as value type)
##     ''     Fix regexpr for strings ( <v>\d? => <v>\d+ )
##     ''     Add isfinite() check before attempt to process fixed strings
## 2013-12-19 (MB) Replace call to __col_str_to_number with __OCT_cc__
## 2014-03-18 (PRN) Fix regexp for reading strings from sharedStrings.xml
## 2014-04-26 Replace __OCT_cc__ by binary __char2num__
## 2014-06-15 (MB) Fix out-of-bounds error in string cell handling
## 2014_08_25 (PRN) Switch to col2num (.oct) for colstr->col conversion to allow
##            compilation on 64-bit MingW systems (mex won't compile int64_t)
## 2014_10_02 (MB) bugfix #43331

function [ raw, xls, rstatus ] = __OCT_xlsx2oct__ (xls, wsh, crange='', spsh_opts)

  ## spsh_opts is guaranteed to be filled by caller

  ## If a worksheet if given, check if it's given by a name (string) or a number
  if (ischar (wsh))
    # fid = fopen (sprintf ('%s/xl/workbook.xml', xls.workbook));
    # if (fid < 0)
      ## File open error
      # error ("xls2oct: file %s couldn't be opened for reading", filename);
    # else
      # xml = fread (fid, "char=>char").';;
      ## Close file
      # fclose (fid);

      ## Search for requested sheet name
      ## id = strmatch (wsh, xls.sheets.sh_names);
      ## strmatch is scheduled for deprecation.
      id = find(strcmp(xls.sheets.sh_names, wsh));
      if (isempty (id))
        error ("xls2oct: cannot find sheet '%s' in file %s", wsh, xls.filename);
      else
        wsh = xls.sheets.sheetid(id);
      endif
    # endif
  elseif (wsh > numel (xls.sheets.sh_names))
    error ("xls2oct: worksheet number %d > number of worksheets in file (%d)", wsh, numel (xls.sheets.sh_names));
  elseif (wsh < 1)
    warning ("xls2oct: illegal worksheet number (%d) - worksheet #1 assumed", wsh);
  endif

  ## Prepare to open requested worksheet file in subdir xl/ . Note: Win accepts forward slashes
  rawsheet = fopen (sprintf ('%s/xl/worksheets/sheet%d.xml', xls.workbook, wsh));
  if (rawsheet <= 0)
    # try to open sheet from r:id in worksheets.rels.xml
    wsh       = xls.sheets.rels( xls.sheets.rels(:,1) == id ,2);
    rawsheet  = fopen (sprintf ('%s/xl/worksheets/sheet%d.xml', xls.workbook, wsh));
    if (rawsheet <= 0)
      error ("Couldn't open worksheet xml file sheet%d.xml\n", wsh);
    endif
  else
    ## Get data
    rawdata = fread (rawsheet, "char=>char").';
    fclose (rawsheet);
    ## Strings
    try
      fid = fopen (sprintf ("%s/xl/sharedStrings.xml", xls.workbook));
      strings = fread (fid, "char=>char").';
      fclose (fid);
    catch
      ## No sharedStrings.xml; implies no "fixed" strings (computed strings can still be there)
      strings = "";
    end_try_catch
  endif
  rstatus = 0;

  ## Check if there are only numeric data (then no s="" or <f> r="s")
  ## FIXME contiguous data rectangles check needed!! so corresponding else clause below
  ##if (! (numel (strfind (rawdata, ' s="')) > 0 || numel (strfind (rawdata, '<f>')) > 0 || numel (strfind (rawdata, 't="s"')) > 0))

  ## if no s="...", nor <formular>, nor t="s" is found. good luck - it could be awesome fast (like example.xlsx)!
  ## FIXME This will break on the reshape below if the data are non-contiguous. Numeric formula results are skipped too
  raw = {};
  ##val = cell2mat (regexp (rawdata, '<c r="\w+"(?: t="b")?><v>(.*?)</v>', "tokens"));
  ##valraw = [];
  ##FIXME This reshape will break on non-contguous data
  ##try
  ##  matrows = size (strfind (rawdata, '</row>'), 2)
  ##  raw = reshape (val, [], matrows)';
  ##  raw = num2cell (raw);
  ##  ## Reshape didn't complain. Big chance we have contiguous data.
  ##  topleft = cell2mat (regexp (rawdata, '<c r="(\w+)"(?:t="b")?><v>.*?</v>', "tokens", "once"));
  ##  [~, ~, ~, trow, lcol] = parse_sp_range (topleft);
  ##  [nrows, ncols] = size (raw);
  ##  xls.limits = [lcol, lcol + ncols - 1; trow, trow + nrows - 1];
  ##  rstatus = 1;
  ##  return
  ##catch
  ##  raw = {};
  ##end_try_catch

  ## 'val' are the actual values. 'valraw' are the corresponding(!) cell positions (e.g. B3).
  if (isempty (raw))
    ## General note for tuning: '"([^"]*)"' (w/o single quotes) could be faster than '"(.*?)"'
    ## (http://stackoverflow.com/questions/2503413/regular-expression-to-stop-at-first-match comment #7)

    ## Below are loads of nested IFs. They're needed to catch empty previous results, even empty sheets

    ## 1. Get pure numbers, including booleans, double and boolean formula results, from cells w/o 's=""' tag
    val = cell2mat (regexp (rawdata, '<c r="\w+"(?: t="[bn]+")?>(?:<f.+?(?:</f>|/>))?<v>(.*?)</v>', "tokens"));
    if (! isempty (val))
      valraw = cell2mat (regexp (rawdata, '<c r="(\w+)"(?: t="[bn]+")?>(?:<f.+?(?:</f>|/>))?<v>.*?</v>', "tokens"));
    endif

    ## If val is still empty, try another regexpression (PRN: will this ever work? haven't seen such cells)
    if (numel (val) == 0)
      val =      cell2mat (regexp (rawdata, '<c r="\w+" s="\d+"(?! t="s")><v>(.*?)</v>', "tokens"));
      if (! isempty (val))
        valraw = cell2mat (regexp (rawdata, '<c r="(\w+)" s="\d+"(?! t="s")><v>.*?</v>', "tokens"));
      endif
    endif

    ## If 'val' exist, check if there are tagged s="NUMBERS" values
    if (numel (regexp (rawdata, ' s="', "once")) > 0)
      ## Time/date values. Exclude formulas (having <f> </f>  of <f  /> tags),
      ## strings  ('t="s"') and error results ('t="e"')
      valp =            cell2mat (regexp (rawdata, '<c r="\w+" s="\d+"(?: t="[^se]*")?><v>(.*?)</v>', "tokens"));
      if (! isempty (valp))
        valrawp = cell2mat(regexp (rawdata, '<c r="(\w+)" s="\d+"(?: t="[^se]*")?><v>.*?</v>', "tokens"));
        if (! isempty (val))
          val =    [val    valp];
          valraw = [valraw valrawp];
        else
          val = valp;
          valraw = valrawp;
          clear valp valrawp ;
        endif
      endif
    endif
    ## Turn strings into numbers
    if (! isempty (val))
      val = num2cell (str2double (val));
    endif

    ## 2. String / text formulas (cached results are in this sheet; fixed strings in <sharedStrings.xml>)
    ## Formulas
    if (spsh_opts.formulas_as_text)

      ## Get formulas themselves as text strings. Formulas have no 't="s"' attribute. Keep starting '>' for next line
      valf1 = cell2mat (regexp (rawdata,     '<c r="\w+"(?: s="\d+")?(?: t="\w+")?><f(?: .*?)*(>.*?)</f>(?:<v>.*?</v>)?', "tokens"));
      if (! isempty (valf1))
        valf1 = regexprep (valf1, '^>', '=');
        ## Pretty text output
        valf1 = strrep (valf1, "&quot;", '"');
        valf1 = strrep (valf1, "&lt;", "<");
        valf1 = strrep (valf1, "&gt;", ">");
        valf1 = strrep (valf1, "&amp;", "&");
        valrawf1 = cell2mat(regexp (rawdata, '<c r="(\w+)"(?: s="\d+")?(?: t="\w+")?><f(?: .*?)*>.*?</f>(?:<v>.*?</v>)?', "tokens"));
        if (isempty (val))
          val = valf1;
        else
          ##  Formulas start with '=' so:
          val = [val valf1];
          valraw = [valraw valrawf1];
        endif
      endif
      clear valf1 valrawf1 ;
    else
      ## Get (cached) formula results. Watch out! as soon as a "t" attibute equals "b" or is missing it is a number
      ## First the non-numeric formula results
      valf2 = cell2mat (regexp (rawdata, '<c r="\w+" s="\d+" t="(?:[^sb]?|str)">(?:<f.+?(?:</f>|/>))<v>(.*?)</v>', "tokens"));
      if (! isempty (valf2))
        ## Pretty text output
        valf2 = strrep (valf2, "&quot;", '"');
        valf2 = strrep (valf2, "&lt;", "<");
        valf2 = strrep (valf2, "&gt;", ">");
        valf2 = strrep (valf2, "&amp;", "&");
        valrawf2 = cell2mat(regexp (rawdata, '<c r="(\w+)" s="\d+" t="(?:[^sb]?|str)">(?:<f.+?(?:</f>|/>))<v>.*?</v>', "tokens"));
        if (isempty (val))
          val = valf2;
          valraw = valrawf2;
        else
          val = [val valf2];
          valraw = [valraw valrawf2];
        endif
      endif
      clear valf2 valrawf2 ;
      ## Next the numeric formula results. These need additional conversion
      valf3 = cell2mat (regexp (rawdata, '<c r="\w+" s="\d+"(?: t="b")?>(?:<f.+?(?:</f>|/>))<v>(.*?)</v>', "tokens"));
      if (! isempty (valf3))
        valrawf3 = cell2mat(regexp (rawdata, '<c r="(\w+)" s="\d+"(?: t="b")?>(?:<f.+?(?:</f>|/>))<v>.*?</v>', "tokens"));
        if (isempty (val))
          val = num2cell(str2double (valf3));
          valraw = valrawf3;
        else
          val = [val num2cell(str2double (valf3))];
          valraw = [valraw valrawf3];
        endif
      endif
      clear valf3 valrawf3 ;
    endif

    ## 3. Strings
    if (! isempty (strings))
      ## Extract string values. May be much more than present in current sheet
			 strings=regexp(strings,'<si[^>]*>.*?</si>','match');
			 for n = 1:columns(strings)
				ctext{1,n}=cell2mat(cell2mat(regexp(strings{1,n},'<t[^>]*>(.*?)</t>','tokens')));
			 end
      ## Pointers into sharedStrings.xml. "Hard" (fixed) strings have 't="s"' attribute
      ## For reasons known only to M$ those pointers are zero-based, so:
      vals = str2double (cell2mat (regexp (rawdata, '<c r="\w+"(?: s="\d+")? t="s"><v>(\d+)</v>', "tokens"))) + 1;
      if (! isempty (vals) && isfinite (vals))
        ## Get actual values
        vals = ctext(vals);
        ## Pretty text output
        vals = strrep (vals, "&quot;", '"');
        vals = strrep (vals, "&lt;", "<");
        vals = strrep (vals, "&gt;", ">");
        vals = strrep (vals, "&amp;", "&");
         ## Cell addresses
        valraws = cell2mat (regexp (rawdata, '<c r="(\w+)"(?: s="\d+")? t="s"><v>\d+</v>', "tokens"));
        if (isempty (val))
          val = vals;
          valraw = valraws;
        else
          val = [val vals];
          valraw = [valraw valraws];
        endif
      endif
      clear vals valraws ;
    endif

    ## If val is empty, sheet is empty
    if (isempty (val))
      xls.limits = [];
      raw = {};
      return
    endif

    ## 4. Prepare
    ## Get the row number (currently supported from 1 to 999999)
    vi.row = str2double (cell2mat (regexp (valraw, '(\d+|\d+\d+|\d+\d+\d+|\d+\d+\d+\d+|\d+\d+\d+\d+\+d|\d+\d+\d+\d+\d+\d+)?', "match"))')';

    ## Get the column character (A to ZZZ) (that are more than 18k supported columns atm)
    vi.alph = cell2mat (regexp (valraw, '([A-Za-z]+|[A-Za-z]+[A-Za-z]+|[A-Za-z]+[A-Za-z]+[A-Za-z]+)?', "match"));

    ## Free memory; might be useful while reading huge files
    clear valraw ;

    ## If missed formular indices
    idx.all = cell2mat (regexp (rawdata, '<c r="(\w+)"[^>]*><f', "tokens"));
    if (0 < numel (idx.all))
      idx.num = str2double (cell2mat (regexp (idx.all, '(\d+|\d+\d+|\d+\d+\d+|\d+\d+\d+\d+|\d+\d+\d+\d+\+d|\d+\d+\d+\d+\d+\d+)?', "match"))')';
      idx.alph = cell2mat (regexp (idx.all, '([A-Za-z]+|[A-Za-z]+[A-Za-z]+|[A-Za-z]+[A-Za-z]+[A-Za-z]+)?', "match"));
      idx.alph = double (cell2mat (cellfun (@col2num, vi.alph, "UniformOutput", 0)));
    else
      ## To prevent warnings or errors while calculating corresponding NaN matrix
      idx.num = [];
      idx.alph = [];
    end
    ## Transform column character to column number
    ## A -> 1; C -> 3, AB -> 28 ...
    vi.col = double (cell2mat (cellfun (@col2num, vi.alph, "UniformOutput", 0)));

    ## Find data rectangle limits
    idx.mincol = min ([idx.alph vi.col]);
    idx.minrow = min ([idx.num  vi.row]);
    idx.maxrow = max ([idx.num  vi.row]);
    idx.maxcol = max ([idx.alph vi.col]);

    ## Convey limits of data rectangle to xls2oct. Must be done here
    xls.limits = [idx.mincol, idx.maxcol; idx.minrow, idx.maxrow];

    ## column adjustment when first number or formula don't begin in the first column
    if (1 < idx.mincol)
          vi.col = vi.col - (idx.mincol - 1);
    endif
    ## row adjustment when first number or formular don't begin in the first row
    if (1 < idx.minrow)
          vi.row = vi.row - (idx.minrow - 1);
    endif
    ## Initialize output cell array
    raw = cell (idx.maxrow - idx.minrow + 1, idx.maxcol - idx.mincol + 1);

    ## get logical indices for 'val' from 'valraw' positions in NaN matrix
    vi.idx = sub2ind (size (raw), (vi.row), (vi.col));
    ## set values to the corresponding indizes in final cell matrix
    raw(vi.idx) = val;

  endif

  ## FIXME maybe reading parts of the data can be done faster above by better regexps
  if (! isempty (crange))
    ## We'll do it the easy way: just read all data, then return only the requested part
    [~, nr, nc, tr, lc] = parse_sp_range (crange);
    xls.limits = [max(idx.mincol, lc), min(idx.maxcol, lc+nc-1); max(idx.minrow, tr), min(idx.maxrow, tr+nr-1)];
    ## Correct spreadsheet locations for lower right shift or raw
    rc = idx.minrow - 1;
    cc = idx.mincol - 1;
    raw = raw(xls.limits(2, 1)-rc : xls.limits(2, 2)-rc, xls.limits(1, 1)-cc : xls.limits(1, 2)-cc);
  endif

  if (! isempty (val))
    rstatus = 1;
  endif

endfunction
