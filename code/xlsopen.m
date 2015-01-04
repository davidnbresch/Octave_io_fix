## Copyright (C) 2009,2010,2011,2012,2013,2014 Philip Nienhuis
## 
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
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
## @deftypefn {Function File} @var{xls} = xlsopen (@var{filename})
## @deftypefnx {Function File} @var{xls} = xlsopen (@var{filename}, @var{readwrite})
## @deftypefnx {Function File} @var{xls} = xlsopen (@var{filename}, @var{readwrite}, @var{reqintf})
## Get a pointer to an Excel spreadsheet in the form of return argument
## (file pointer struct) @var{xls}. After processing the spreadsheet,
## the file pointer must be explicitly closed by calling xlsclose().
##
## Calling xlsopen without specifying a return argument is fairly useless!
##
## xlsopen works with interfaces, which are links to external software.
## For I/O from/to OOXML (Excel 2007 and up), ODS 1.2 and Gnumeric, no
## additional software is required when the OCT interface is used (see below).
## For all other spreadsheet formats, you need one or more of MS-Excel
## (95 - 2013), or a Java JRE plus Apache POI >= 3.5 and/or JExcelAPI
## and/or OpenXLS and/or OpenOffice.org (or clones) installed on your computer
## + proper javaclasspath set. These interfaces are referred to as COM, POI,
## JXL, OXS, and UNO, resp., and are preferred in that order by default
## (depending on their presence). Currently the OCT interface has the lowest
## priority as it is still experimental.
## For OOXML read/write support in principle no additional SW is needed.
## However, the COM, POI and UNO interfaces may provide better OOXML write
## performance and/or more flexibility.
## Excel'95 spreadsheets (BIFF5) can only be read using the COM (Excel-ActiveX),
## JXL (JExcelAPI), and UNO (Open-/LibreOffice) interfaces.
##
## @var{filename} should be a valid .xls or xlsx Excel file name (including
## extension). But if you use the COM interface you can specify any extension
## that your installed Excel version can read AND write; the same goes for UNO
## (OpenOffice.org). Using the other Java interfaces, only .xls or .xlsx are
## allowed. If @var{filename} does not contain any directory path, the file
## is saved in the current directory.
##
## If @var{readwrite} is set to 0 (default value) or omitted, the spreadsheet
## file is opened for reading. If @var{readwrite} is set to true or 1, a
## spreadsheet file is opened (or created) for reading & writing.
##
## Optional input argument @var{reqintf} can be used to override the Excel
## interface that otherwise is automatically selected by xlsopen. Currently
## implemented interfaces (in order of preference) are 'COM' (Excel/COM),
## 'POI' (Java/Apache POI), 'JXL' (Java/JExcelAPI), 'OXS' (Java/OpenXLS),
## 'UNO' (Java/OpenOffice.org - EXPERIMENTAL!), or 'OCT' (native Octave).
## In most situations this parameter is unneeded as xlsopen automatically
## selects the most useful interface present.
##
## Beware: Excel invocations may be left running invisibly in case of COM
## errors or forgetting to close the file pointer. Similarly for OpenOffice.org
## which may even prevent Octave from being closed.
##
## Examples:
##
## @example
##   xls = xlsopen ('test1.xls');
##   (get a pointer for reading from spreadsheet test1.xls)
##
##   xls = xlsopen ('test2.xls', 1, 'POI');
##   (as above, indicate test2.xls will be written to; in this case using Java
##    and the Apache POI interface are requested)
## @end example
##
## @seealso {xlsclose, xlsread, xlswrite, xls2oct, oct2xls, xlsfinfo}
##
## @end deftypefn

## Author: Philip Nienhuis <prnienhuis at users.sf.net>
## Created: 2009-11-29
## Updates:
## 2010-01-03 Added OOXML support
## 2010-01-10 Changed (java) interface preference order to COM->POI->JXL
## 2010-01-16 Removed echoeing debug info in POI stanza
## 2010-03-01 Removed javaclasspath check for rt.jar
## 2010-03-14 Fixed check on xwrite flag lines 204+, if xlsopen fails xls ptr
##            should be []
## 2010-08-25 Improved help text
## 2010-09-27 Improved POI help message for unrecognized .xls format to hint for BIFF5/JXL
## 2010-10-20 Improved code for tracking changes to new/existing files
##     ''     Lots of code cleanup, improved error checking and catching
##     ''     Implemented fallback to JXL if POI can't read a file.
## 2010-10-30 More fine-grained file existence/writable checks
## 2010-11-01 Added <COM>.Application.DisplayAlerts=0 in COM section to avoid Excel pop-ups
## 2010-11-05 Option for multiple requested interface types (cell array)
##     ''     Bug fix: JXL fallback from POI for BIFF5 is only useful for reading
## 2010-11-05 Slight change to reporting to screen
## 2010-11-08 Tested with POI 3.7 (OK)
## 2010-11-10 Texinfo header updated
## 2010-12-01 Small bugfix - reset xlssupport in l. 102
## 2010-12-06 Textual changes to info header 
## 2011-03-26 OpenXLS support added
## 2011-05-18 Experimental UNO support added, incl. creating new spreadsheets
## 2011-05-22 Textual changes in header
## 2011-05-29 Cleanup of comments & messages
## 2011-09-03 Reset chkintf to [] if no xls support was discovered (to allow
##            rediscovery of interfaces between xlsopen calls, e.g. javaclasspath changes)
## 2011-09-08 Minor code cleanup
## 2012-01-26 Fixed "seealso" help string
## 2012-06-06 Improved interface detection logic. No more messages if same interface is
##            requested & used consecutively
## 2012-06-07 Fixed mixed-up lastintf assignments for POI and JXL
## 2012-09-02 (in UNO section) web adresses need only two consecutive slashes
## 2012-09-03 (in UNO section) replace canonicalize_file_name on non-Windows to
##            make_absolute_filename (see bug #36677)
## 2012-10-07 Moved subfunc getxlsinterfaces to ./private
##     ''     Moved all interface-specific file open stanzas to separate ./private funcs
## 2012-10-24 Style fixes
## 2012-12-18 Improved warning/error messages
## 2013-02-24 Temporarily disabled OXS and UNO
## 2013-05-16 Fix fallback to JXL for OOXML files
## 2013-06-18 Re-enabled OXS and UNO
## 2013-09-01 Allow input of filename w/o suffix for Excel files
## 2013-09-02 Better fix for undue fallback to JXL for OOXML files
##     ''     Fixed wrong error message about OXS and UNO not being supported
## 2013-09-30 Native Octave interface ("OCT") for reading .xlsx
##     ''     Adapted header to OCT (also Excel 2013 is supported)
## 2013-10-01 Some adaptations for gnumeric
## 2013-10-20 Overhauled file extension detection logic
## 2013-11-03 Improved interface selection (fix a.o., fallback to JXL for xlsx)
## 2013-11-04 Catch attempts to write with only OCT interface
## 2013-12-01 Add support for ODS (Excel 2007+ and OpenOffice.org/LibreOffice support it)
## 2013-12-27 Use one variable for processed file type
##     ''     Style fixes
## 2013-12-28 Allow OOXML support for OpenXLS
## 2014-01-01 Add .csv to supported file extensions
##     ''     Add warning that UNO will write ODS f. unsupported file extensions
##     ''     Copyright string update
## 2014-02-02 Allow write support for OCT interface
## 2014-04-13 Updated texinfo header
## 2014-04-26 Fix error messages (no more traceback)
## 2014-04-30 Allow gnumeric write support (remove catch)

function [ xls ] = xlsopen (filename, xwrite=0, reqinterface=[])

  persistent xlsinterfaces; persistent chkintf; persistent lastintf;
  ## xlsinterfaces.<intf> = [] (not yet checked), 0 (found to be unsupported) or 1 (OK)
  if (isempty (chkintf));
      chkintf = 1;
      xlsinterfaces = struct ('COM', [], 'POI', [], 'JXL', [], 'OXS', [], 'UNO', [], "OCT", 1);
  endif
  if (isempty (lastintf))
    lastintf = "---";
  endif
  xlsintf_cnt = 1;

  xlssupport = 0;

  if (nargout < 1)
      usage ("XLS = xlsopen (Xlfile [, Rw] [, reqintf]). But no return argument specified!"); 
  endif

  if (! (islogical (xwrite) || isnumeric (xwrite)))
      usage ("xlsopen.m: numerical or logical value expected for arg ## 2 (readwrite)")
  endif

  if (! isempty (reqinterface))
    if (! (ischar (reqinterface) || iscell (reqinterface)))
      usage ("Arg ## 3 (interface) not recognized - character value required"); 
    endif
    ## Turn arg3 into cell array if needed
    if (! iscell (reqinterface))
      reqinterface = {reqinterface}; 
    endif
    ## Check if previously used interface matches a requested interface
    if (isempty (regexpi (reqinterface, lastintf, 'once'){1}) ||
        ! xlsinterfaces.(upper (reqinterface{1})))
      ## New interface requested
      xlsinterfaces.COM = 0; xlsinterfaces.POI = 0; xlsinterfaces.JXL = 0;
      xlsinterfaces.OXS = 0; xlsinterfaces.UNO = 0; xlsinterfaces.OCT = 0;
      for ii=1:numel (reqinterface)
        reqintf = toupper (reqinterface {ii});
        ## Try to invoke requested interface(s) for this call. Check if it
        ## is supported anyway by emptying the corresponding var.
        if     (strcmpi (reqintf, 'COM'))
          xlsinterfaces.COM = [];
        elseif (strcmpi (reqintf, 'POI'))
          xlsinterfaces.POI = [];
        elseif (strcmpi (reqintf, 'JXL'))
          xlsinterfaces.JXL = [];
        elseif (strcmpi (reqintf, 'OXS'))
          xlsinterfaces.OXS = [];
        elseif (strcmpi (reqintf, 'UNO'))
          xlsinterfaces.UNO = [];
        elseif (strcmpi (reqintf, 'OCT'))
          xlsinterfaces.OCT = [];
        else 
          usage (sprintf (["xlsopen.m: unknown .xls interface \"%s\" requested.\n" 
                 "Only COM, POI, JXL, OXS, UNO, or OCT) supported\n"], reqinterface{}));
        endif
      endfor
      printf ("Checking requested interface(s):\n");
      xlsinterfaces = getxlsinterfaces (xlsinterfaces);
      ## Well, is/are the requested interface(s) supported on the system?
      xlsintf_cnt = 0;
      for ii=1:numel (reqinterface)
        if (! xlsinterfaces.(toupper (reqinterface{ii})))
          ## No it aint
          printf ("%s is not supported.\n", upper (reqinterface{ii}));
        else
          ++xlsintf_cnt;
        endif
      endfor
      ## Reset interface check indicator if no requested support found
      if (! xlsintf_cnt)
        chkintf = [];
        xls = [];
        return
      endif
    endif
  endif

  ## Check if Excel file exists. First check for (supported) file name suffix:
  ftype = 0;
  has_suffix = 1;
  [sfxpos, ~, ~, ext] = regexpi (filename, '(\.xlsx?|\.gnumeric|\.ods|\.csv)');
  if (! isempty (sfxpos))
    ext = lower (ext{end});
    ## .xls or .xls[x,m,b] or .gnumeric is there, but at the right(most) position?
    if (sfxpos(end) <= length (filename) - length (ext))
      ## Apparently not, or it is an unrecognized extension
      ## If xwrite = 0, check file suffix, else add .xls
      has_suffix = 0;
    else
      switch ext
        case ".xls"                               ## Regular (binary) BIFF
          ftype = 1;
        case {".xlsx", ".xlsm", ".xlsb"}          ## Zipped XML / OOXML. Catches xlsx, xlsb, xlsm
          ftype = 2;
        case "ods"                                ## ODS 1.2 (Excel 2007+ & OOo/LO can read ODS)
          ftype = 3;
        case ".gnumeric"                          ## Zipped XML / gnumeric
          ftype = 5;
        case ".csv"                               ## csv. Detected for xlsread afficionados
          ftype = 6;
        otherwise
          warning ("xlsopen: file type ('%s' extension) not supported", ext);
      endswitch
    endif
  else
    has_suffix = 0;
  endif

  ## Var readwrite is really used to avoid creating files when wanting to read,
  ## or not finding not-yet-existing files when wanting to write a new one.
  
  ## Adapt file open mode for readwrite argument
  if (xwrite)
%    ## Catch attempts to write gnumeric
%    if (ftype == 5)
%      error ("xlsopen: there's only read support for gnumeric files\n");
%    endif
    fmode = 'r+b';
    if (! has_suffix)
      ## Add .xls suffix to filename (all Excel versions can write this)
      filename = [filename ".xls"];
    endif
  else
    fmode = 'rb';
    if (! has_suffix)
      ## Try to find find existing file name. We ignore .gnumeric
        filnm = dir ([filename ".xls*"]);
        if (! isempty (filnm))
          ## Simply choose the first one
          if (isstruct (filnm))
            filename = filnm(1).name;
          else
            filename = filnm;
          endif
        endif
    endif
  endif
  fid = fopen (filename, fmode);
  if (fid < 0)                      ## File doesn't exist...
    if (! xwrite)                   ## ...which obviously is fatal for reading...
      ## FIXME process open apps (Excel, LibreOffice, etc) before hard crash
      error ( sprintf ("xlsopen.m: file %s not found\n", filename));
    else                            ## ...but for writing, we need more info:
      fid = fopen (filename, 'rb'); ## Check if it exists at all...
      if (fid < 0)                  ## File didn't exist yet. Simply create it
        printf ("Creating file %s\n", filename);
        xwrite = 3;
      else                          ## File exists, but isn't writable => Error
        fclose (fid);  ## Do not forget to close the handle neatly
        error (sprintf ("xlsopen.m: write mode requested but file %s is not writable\n", filename))
      endif
    endif
  else
    ## Close file anyway to avoid COM or Java errors
    fclose (fid);
  endif
  
  ## Check for the various Excel interfaces. No problem if they've already
  ## been checked, getxlsinterfaces (far below) just returns immediately then.
  xlsinterfaces = getxlsinterfaces (xlsinterfaces);
  
  ## Initialize file ptr struct
  xls = struct ("xtype",    'NONE', 
                "app",      [], 
                "filename", [], 
                "workbook", [], 
                "changed",  0, 
                "limits",   []);

  ## Keep track of which interface is selected
  xlssupport = 0;

  ## Interface preference order is defined below: currently COM -> POI -> JXL -> OXS -> UNO -> OCT
  ## ftype (file type) is conveyed depending on interface capabilities

  if ((! xlssupport) && xlsinterfaces.COM && (ftype != 5))
    ## Excel functioning has been tested above & file exists, so we just invoke it.
    [ xls, xlssupport, lastintf ] = __COM_spsh_open__ (xls, xwrite, filename, xlssupport);
  endif

  if ((! xlssupport) && xlsinterfaces.POI && (ftype <= 2))
    [ xls, xlssupport, lastintf ] = __POI_spsh_open__ (xls, xwrite, filename, xlssupport, ftype, xlsinterfaces);
  endif

  if ((! xlssupport) && xlsinterfaces.JXL && ftype == 1)
    [ xls, xlssupport, lastintf ] = __JXL_spsh_open__ (xls, xwrite, filename, xlssupport, ftype);
  endif

  if ((! xlssupport) && xlsinterfaces.OXS && ftype <= 2)
    [ xls, xlssupport, lastintf ] = __OXS_spsh_open__ (xls, xwrite, filename, xlssupport, ftype);
  endif

  if ((! xlssupport) && xlsinterfaces.UNO && (ftype != 5))
    ## Warn for LO / OOo stubbornness
    if (ftype == 0 || ftype == 5 || ftype == 6)
      warning ("UNO interface will write ODS format for unsupported file extensions\n")
    endif
    [ xls, xlssupport, lastintf ] = __UNO_spsh_open__ (xls, xwrite, filename, xlssupport);
  endif

  if ((! xlssupport) && xlsinterfaces.OCT && ...
      (ftype == 2 || ftype == 3 || ftype == 5))
    [ xls, xlssupport, lastintf ] = __OCT_spsh_open__ (xls, xwrite, filename, xlssupport, ftype);
  endif

  ## if 
  ##  ---- other interfaces
  ## endif

  ## Rounding up. If none of the xlsinterfaces is supported we're out of luck.
  if (! xlssupport)
    if (isempty (reqinterface))
      ## If no suitable interface was detected (COM or UNO can read .csv), handle
      ## .csv in xlsread (as that's where Matlab n00bs would expect .csv support)
      if (ftype != 6)
        ## This message is appended after message from getxlsinterfaces()
        printf ("None.\n");
        warning ("xlsopen.m: no support for spreadsheet I/O\n");
      endif
    else
      ## No match between filte type & interface found
      warning ("xlsopen.m: file type not supported by %s %s %s %s %s %s\n", reqinterface{:});
    endif
    xls = [];
    ## Reset found interfaces for re-testing in the next call. Add interfaces if needed.
    chkintf = [];
  else
    ## From here on xwrite is tracked via xls.changed in the various lower
    ## level r/w routines
    xls.changed = xwrite;

    ## xls.changed = 0 (existing/only read from), 1 (existing/data added), 2 (new,
    ## data added) or 3 (pristine, no data added).
    ## Until something was written to existing files we keep status "unchanged".
    if (xls.changed == 1)
      xls.changed = 0; 
    endif
  endif

endfunction
