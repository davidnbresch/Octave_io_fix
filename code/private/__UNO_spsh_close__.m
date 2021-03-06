## Copyright (C) 2012,2013 Philip Nienhuis
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

## __UNO_spsh_close__ - internal function: close a spreadsheet file using UNO

## Author: Philip Nienhuis <prnienhuis@users.sf.net>
## Created: 2012-10-12
## Updates:
## 2012-10-23 Style fixes
## 2013-01-20 Adapted to ML-compatible Java calls
## 2013-12-06 Updated copyright strings
## 2014-01-01 Fixed bug ignoring xls.nfilename
##     ''     Simplified filename/nfilename code
##     ''     First throw at output file type filters
##     ''     Add ";" to suppress debug output
## 2014-08-25 Add a little delay before terminating LO/OOo to allow
##            zip finish low-level I/O

function [ xls ] = __UNO_spsh_close__ (xls, force)

  if (isfield (xls, "nfilename"))
    ## New filename specified
    if (strcmp (xls.xtype, 'UNO'))
      ## For UNO, turn filename into URL
      nfilename = xls.nfilename;
      if    (! isempty (strmatch ("file:///", nfilename))... 
          || ! isempty (strmatch ("http://",  nfilename))...
          || ! isempty (strmatch ("ftp://",   nfilename))...   
          || ! isempty (strmatch ("www://",   nfilename)))
        ## Seems in proper shape for OOo (at first sight)
      else
        ## Transform into URL form
        if (ispc)
          fname = canonicalize_file_name (strsplit (nfilename, filesep){end});
          if (isempty (fname))
            ## File doesn't exist yet? try make_absolute_filename()
            fname = make_absolute_filename (strsplit (filename, filesep){end});
          endif
        else
          fname = make_absolute_filename (strsplit (nfilename, filesep){end});
        endif
        ## On Windows, change backslash file separator into forward slash
        if (strcmp (filesep, "\\"))
          tmp = strsplit (fname, filesep);
          flen = numel (tmp);
          tmp(2:2:2*flen) = tmp;
          tmp(1:2:2*flen) = "/";
          filename = [ "file://" tmp{:} ];
        endif
      endif
    endif
  else
    filename = xls.filename;
  endif

  try
    if (xls.changed > 0 && xls.changed < 3)
      ## Workaround:
      unotmp = javaObject ("com.sun.star.uno.Type", "com.sun.star.frame.XModel");
      xModel = xls.workbook.queryInterface (unotmp);
      unotmp = javaObject ("com.sun.star.uno.Type", "com.sun.star.util.XModifiable");
      xModified = xModel.queryInterface (unotmp);
      if (xModified.isModified ())
        unotmp = ...
          javaObject ("com.sun.star.uno.Type", "com.sun.star.frame.XStorable");  # isReadonly() ?    
        xStore = xls.app.xComp.queryInterface (unotmp);
        if (xls.changed == 2)
          ## Some trickery as Octave Java cannot create non-numeric arrays
          lProps = javaArray ("com.sun.star.beans.PropertyValue", 2);
          ## Set file type property
          [ftype, filtnam] = __get_ftype__ (filename);
          if (isempty (filtnam))
            filtnam = "calc8";
          endif
          lProp = javaObject ...
            ("com.sun.star.beans.PropertyValue", "FilterName", 0, filtnam, []);
          lProps(1) = lProp;
          ## Set "Overwrite" property
          lProp = ...
            javaObject ("com.sun.star.beans.PropertyValue", "Overwrite", 0, true, []);
          lProps(2) = lProp;
          ## OK, store file
      #    if (isfield (xls, "nfilename"))
            ## Store in another file 
            ## FIXME check if we need to close the old file
      #      xStore.storeAsURL (xls.nfilename, lProps);
      #    else
      #      xStore.storeAsURL (xls.filename, lProps);
            xStore.storeAsURL (filename, lProps);
      #    endif
        else
          xStore.store ();
        endif
      endif
    endif
    xls.changed = -1;    ## Needed for check on properly shutting down OOo
    ## Workaround:
    unotmp = javaObject ("com.sun.star.uno.Type", "com.sun.star.frame.XModel");
    xModel = xls.app.xComp.queryInterface (unotmp);
    unotmp = javaObject ("com.sun.star.uno.Type", "com.sun.star.util.XCloseable");
    xClosbl = xModel.queryInterface (unotmp);
    xClosbl.close (true);
    unotmp = javaObject ("com.sun.star.uno.Type", "com.sun.star.frame.XDesktop");
    xDesk = xls.app.aLoader.queryInterface (unotmp);
    sleep (0.25);
    xDesk.terminate();
    xls.changed = 0;
  catch
    if (force)
      ## Force closing OOo
      unotmp = javaObject ("com.sun.star.uno.Type", "com.sun.star.frame.XDesktop");
      xDesk = xls.app.aLoader.queryInterface (unotmp);
      xDesk.terminate();
    else
      warning ("Error closing xls pointer (UNO)");
    endif
    return
  end_try_catch

endfunction
