## Copyright (C) 2013,2014 Philip Nienhuis
## Copyright (C) 2013 Markus Bergholz (.xlsx & archive unzip stuff)
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
## @deftypefn {Function File} {@var{retval} =} __OCT_spsh_open__ (@var{x} @var{y})
##
## @seealso{}
## @end deftypefn

## Author: Philip Nienhuis <prnienhuis at users.sf.net>
## File open stuff by Markus Bergholz
## Created: 2013-09-08
## Updates:
## 2013-09-09 Wipe temp dir after opening as all content is in memory
##            FIXME this needs to be adapted for future OOXML support
## 2013-09-23 Fix copyright messages
## 2013-10-02 More comments
## 2013-10-20 Adapted parts of Markus' .xlxs code
## 2013-11-10 (MB) Compacted sheet names & rid code in xlsx section
## 2013-11-12 Rely on private/__unpack (patched unpack.m from core Octave)
## 2013-11-16 Replace fgetl calls by fread to cope with EOLs
## 2013-12-13 Fix sheet names parsing regexpr
## 2013-12-14 Fix sheet names parsing regexpr # 2 (attrib order can change =>
##            that's why an XML parser is superior over regular expressions)
## 2013-12-27 Use one variable for processed file type
##     ''     Shuffled code around to file type order
## 2014-01-22 Open new files from template directory in io script directory
## 2014-01-23 Move confirm_recursive_rmdir to __OCT_spsh_close__.m
## 2014-01-29 Support for xlsx and gnumeric
## 2014-02-08 Fix wrong function name in error msg (couldn't be unzipped)
## 2014-03-17 Simplify sheet names discovery
##     ''     Ignore SheetId (nowhere used)
## 2014-03-18 Reinstate SheetId (was used somewhere after all)
## 2014-04-30 Close file handle for gnumeric files
## 2014-08-25 Precautions to make sure we get back to original work dir
## 2014-10-02 (MB) extended by reading worksheet.xml.rels relationship target

function [ xls, xlssupport, lastintf] = __OCT_spsh_open__ (xls, xwrite, filename, xlssupport, ftype)

  ## Open and unzip file to temp location (code by Markus Bergholz)
  ## create current work folder
  tmpdir = tmpnam;

  ## Get template if a new file is created
  if (xwrite == 3)
    if (ftype == 2)
      ext = ".xlsx";
    elseif (ftype == 3)
      ext = ".ods";
    elseif (ftype == 5)
      ext = ".gnumeric";
    endif
    ## New file, get it from template. Use odsopen.m to find it
    templ = strrep (which ("odsopen"), "odsopen.m", ["templates" filesep "template" ext]);
  else
    templ = filename;
  endif

  ## zip operations sometimes transfer to temp dir; make sure we get back
  opwd = pwd;
  if (ftype == 5)
    ## Gnumeric xml files are gzipped
    system (sprintf ("gzip -d -c -S=gnumeric %s > %s", templ, tmpdir));
    fid = fopen (tmpdir, 'r');
    xml = fread (fid, "char=>char").';
    ## Close file handle, don't delete file
    fclose (fid);
  else
    ## xlsx and ods are zipped
    try
      unpack (templ, tmpdir, "unzip");
      ## Allow unpack dust to settle down (lazy write file I/O)
      sleep (0.2);
    catch
      printf ("file %s couldn't be unpacked. Is it the proper file format?\n", filename);
      xls = [];
      return
    end_try_catch
  endif
  ## Make sure we get back to original work dir
  cd (opwd);

  ## Set up file pointer struct
  if (ftype == 2)
    ## =======================  XLSX ===========================================
    ## From xlsxread by Markus Bergholz <markuman+xlsread@gmail.com>
    ## https://github.com/markuman/xlsxread

    ## Get sheet names. Speeds up other functions a lot if we can do it here
    fid = fopen (sprintf ('%s/xl/workbook.xml', tmpdir));
    if (fid < 0)
      ## File open error
      warning ("xls2open: file %s couldn't be unzipped", filename);
      xls = [];
      return
    else
      ## Fill xlsx pointer 
      xls.workbook          = tmpdir;       # subdir containing content.xml
      xls.xtype             = "OCT";        # OCT is fall-back interface
      xls.app               = 'xlsx';       # must NOT be an empty string!
      xls.filename = filename;              # spreadsheet filename
      xls.changed = 0;                      # Dummy

      ## Get content.xml
      xml = fread (fid, "char=>char").';
      ## Close file
      fclose (fid);

      ## Get sheet names and indices
      sheets = getxmlnode (xml, "sheets", [], 1);
      xls.sheets.sh_names = cell2mat (regexp (sheets, '<sheet name="(.*?)"', "tokens"));
      xls.sheets.rid = str2double (cell2mat (regexp (sheets, ' r:id="rId(\d+)"', "tokens")));
      xls.sheets.sheetid = str2double (cell2mat (regexp (sheets, ' sheetId="(\d+)"', "tokens")));
      
      ## read worksheet.xml.rels
      fid = fopen (sprintf ("%s/xl/_rels/workbook.xml.rels", tmpdir));
      if (fid > 0)
        str = fread (fid, "char=>char").';
        xls.sheets.rels = ...
         regexp (str, ['<Relationship Id="rId(\d+)" ' ...
                       'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" ' ...
                       'Target="worksheets/sheet(\d+).xml"[^/>]*/>'], "tokens");
        xls.sheets.rels = reshape (str2double (cell2mat (xls.sheets.rels)), [], columns(xls.sheets.rels))';
      else
        xls.sheets.rels = reshape([xls.sheets.rid xls.sheets.rid], [], columns (xls.sheets.rid));
      endif

    endif

  elseif (ftype == 3)
    ## ============== ODS. Read the actual data part in content.xml ============
    fid = fopen (sprintf ("%s/content.xml", tmpdir), "r");
    if (fid < 0)
      ## File open error
      error ("file %s couldn't be opened for reading", filename);
    else
      ## Read file contents
      xml = fread (fid, "char=>char").';
      ## Close file but keep it around, store file name in struct pointer
      fclose (fid);

      ## To speed things up later on, get sheet names and starting indices
      shtidx = strfind (xml, "<table:table table:name=");
      nsheets = numel (shtidx);
      ## Find end (+1) of very last sheet, marked by either one of below tags
      sht_end = strfind (xml, "<table:named-expressions");
      if (isempty (sht_end))
        sht_end = strfind (xml, "</office:spreadsheet>");
      endif
      shtidx = [ shtidx sht_end ];
      ## Get sheet names
      sh_names = cell (1, nsheets);
      for ii=1:nsheets
        sh_names(ii) = xml(shtidx(ii)+25 : shtidx(ii)+23+index (xml(shtidx(ii)+25:end), '"'));
      endfor

      ## Fill ods pointer.
      xls.workbook        = tmpdir;         # subdir containing content.xml
      xls.sheets.sh_names = sh_names;       # sheet names
      xls.sheets.shtidx   = shtidx;         # start & end indices of sheets
      xls.xtype           = "OCT";          # OCT is fall-back interface
      xls.app             = 'ods';          # must NOT be an empty string!
      xls.filename = filename;              # spreadsheet filename
      xls.changed = 0;                      # Dummy

    endif

  elseif (ftype == 5)
    ## ====================== Gnumeric =========================================
    xls.workbook = tmpdir;                  # location of unzipped files
    xls.xtype    = "OCT";                   # interface
    xls.app      = 'gnumeric';              #
    xls.filename = filename;                # file name
    xls.changed  = 0;                       # Dummy

    ## Get nr of sheets & pointers to start of Sheet nodes & end of Sheets node
    shtidx = strfind (xml, "<gnm:Sheet ");
    xls.sheets.shtidx = [ shtidx index(xml, "</gnm:Sheets>") ];
    xls.sheets.sh_names = cell (1, numel (shtidx));
    sh_names = getxmlnode (xml, "gnm:SheetNameIndex");
    jdx = 1;
    for ii=1:numel (shtidx)
      [xls.sheets.sh_names(ii), ~, jdx] = getxmlnode (sh_names, "gnm:SheetName", jdx, 1);
    endfor

  endif  

  xlssupport += 1;
  lastintf = "OCT";

endfunction
