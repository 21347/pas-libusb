unit usb.IDlist;

{Provides a simple way to parse a list of known USB Vendor/Device IDs. Will
read the data from
- a compiled list from memory (see usb.IDList.inc and tools/ dir)
- a user supplied file, usb.ids e.g. by setting USBDeviceDatabaseFile
  (can be downloaded at http://www.linux-usb.org/usb.ids)
- a file in the system (on linux, typically at /usr/share/misc/usb.ids}

{$mode objfpc}{$H+}

//In Windows or MacOS, there's no way to read /usr/share/misc/usb.ids, so we will
//allways have to include the list here. However, you may change this and
//provide a usb.ids file instead.
{$if defined(WINDOWS) OR defined(DARWIN)}
  {$DEFINE INCLUDE_USB_IDS}
{$ENDIF}

{!$DEFINE INCLUDE_USB_IDS}

interface

uses
  Classes, SysUtils;

{Defines needed if a list is loaded from memory.}
type
  TUSBDeviceListEntry = record
    vendorID, deviceID, interfaceID: word;
    name: string;
  end;
  PUSBDeviceListEntry = ^TUSBDeviceListEntry;

  TUSBVendorEntry = record
    vendorID: word;
    name: string;
  end;
  PUSBVendorEntry = ^TUSBVendorEntry;

var
  {Memory based list of USB device names}
  MemoryDeviceList:array of TUSBDeviceListEntry;
  {Memory based list of USB vendor names}
  MemoryVendorList:array of TUSBVendorEntry;
  {Number if device names in memory}
  MemoryDeviceListSize:cardinal=0;
  {Number of USB vendor names in memory}
  MemoryVendorListSize:cardinal=0;
  {Path of the (system) supplied USB device/vendor database file}
  USBDeviceDatabaseFile:string;

const
  CompileTimeUSBListExists = {$IFDEF INCLUDE_USB_IDS}true{$ELSE}false{$ENDIF};

{Return a vendor name string from memory}
function LookupVendorFromMemory(venID:word):string;

{Return a devide or interface from memory. Usually, intID is set to 0 (the USB
device list currently does not feature any USB interface names) to return
the device name. If intID is non-zero, it will search for the interfaceName.}
function LookupDeviceFromMemory(venID:integer; devID:integer; intID:integer=-1):string;

{Load the given or default (if dbFile = '') database file into memory. Return true
on success, false if the file was not found or could not be parsed.}
function LoadDatabaseToMemory(dbFile:string=''):boolean;

{Discard the loaded list from memory. Successive calls to any *FromMemory functions
will then fail except a table was compiled in using INCLUDE_USB_IDS}
procedure DiscardMemoryDatabase;

{Return a vendor, devide or interface from the database file. Usually, intID is set to -1
(the USB device list currently does not feature any USB interface names). This function
will walk through the (sorted) database file and thus can provide vendor, device and
interface name, if any, if any, and not much additional cost.
If intID is -1, the function will look for Vendor and Device. If Device is also below zero,
it will stop if it has found the VendorID.}
function LookupDeviceFromDatabase(venID:integer; devID:integer; intID:integer;
  out venName, devName, intName: string; dbFile:string=''):boolean;

{Which databases to search for USB names}
type
  TUSBDataDBSelection = set of (usbDataMemory, usbDataFile);

{Use any available method to get vendor name, device name or interface name for
the given IDs. Will search a memory list first, followed by a compiled-in table
and the database file of the OS (or user) last.
If intID is set below zero, the function will serach for vendor and device. If
venID is also below zero, it will ignore deviceID and interfaceID and only return
the vendor name.}
function LookupUSBNames(venID:integer; devID:integer; intID:integer;
  out venName, devName, intName: string;
  whereToSearch:TUSBDataDBSelection=[usbDataMemory, usbDataFile]):boolean;

{Set USBDeviceDatabaseFile to the system's default location of that file, if any.}
procedure SetDefaultUSBDatabaseLocation;
                                          
{Ensure that some database is available from memory. That is, if a table was
compiled in, the function will do nothing. If not, it will try to load the
database from USBDeviceDatabaseFile. If both is not possible, it will return
false.}
function EnsureMemoryDatabaseAvailable:boolean;

implementation     

{$IFDEF INCLUDE_USB_IDS}
//Include the pre-made list of USB device and vendor IDs
{$I usb.IDList.inc}
{$ENDIF}

{Return a vendor name string from memory}
function LookupVendorFromMemory(venID:word):string;
var
  i:integer;
begin  
  result:='';
  if MemoryVendorListSize > 0 then begin
    for i:=0 to MemoryVendorListSize-1 do
      if MemoryVendorList[i].vendorID = venID then begin
        result:=MemoryVendorList[i].name;
        break;
      end;
  end
  {$IFDEF INCLUDE_USB_IDS}
  else begin
    for i:=0 to USBVendorCount-1 do
      if USBVendorList[i].vendorID = venID then begin
        result:=USBVendorList[i].name;
        break;
      end;
  end
  {$ENDIF}
end;

{Return a devide or interface from memory. Usually, intID is set to 0 (the USB
device list currently does not feature any USB interface names) to return
the device name. If intID is non-zero, it will search for the interfaceName.}
function LookupDeviceFromMemory(venID:integer; devID:integer; intID:integer=-1):string;
var
  i:integer;
begin
  result:='';
  if MemoryDeviceListSize > 0 then begin
    for i:=0 to MemoryDeviceListSize-1 do
      if (MemoryDeviceList[i].vendorID = venID) and
         (MemoryDeviceList[i].deviceID = devID) and
         ((MemoryDeviceList[i].interfaceID = intID) or (intID < 0)) then begin
        result:=MemoryDeviceList[i].name;
        break;
      end;
  end
  {$IFDEF INCLUDE_USB_IDS}
  else begin
    for i:=0 to USBDeviceNamesCount-1 do
      if (USBDeviceNamesList[i].vendorID = venID) and
         (USBDeviceNamesList[i].deviceID = devID) and
         ((USBDeviceNamesList[i].interfaceID = intID) or (intID < 0)) then begin
        result:=USBDeviceNamesList[i].name;
        break;
      end;
  end
  {$ENDIF}
end;

{Load the given or default (if dbFile = '') database file into memory. Return true
on success, false if the file was not found or could not be parsed.}
function LoadDatabaseToMemory(dbFile:string=''):boolean;
var
  line, part1, part2:string;
  inFile: TextFile;
  lastVendorID:word;
  lastDeviceID:word;
  lastInterfaceID:word;
  venCount, devCount: integer;
  venPos, devPos:integer;

  {Advance devPos and ensure that the list is long enough}
  function NextDev:PUSBDeviceListEntry;
  begin
    Inc(devPos);
    Inc(MemoryDeviceListSize);
    if devPos = devCount then begin
      //Increase the list size by a larger amount to avoid memCopy to often
      Inc(devCount, 32);
      SetLength(MemoryDeviceList, devCount);
    end;
    result:=@MemoryDeviceList[devPos];
  end;

  {Advance venPos and ensure that the list is long enough}
  function NextVen:PUSBVendorEntry;
  begin
    Inc(venPos);
    Inc(MemoryVendorListSize);
    if venPos = venCount then begin
      //Increase the list size by a larger amount to avoid memCopy to often
      Inc(venCount, 32);
      SetLength(MemoryVendorList, venCount);
    end;
    result:=@MemoryVendorList[venPos];
  end;
begin
  DiscardMemoryDatabase;
  result:=true;
  try
    //Prepare
    lastVendorID:=0;
    lastDeviceID:=0;
    lastInterfaceID:=0;
    venCount:=2500;  //set some reasonable starting number for each list.
    devCount:=15000; //last time, it was 3020 vendors and more than 17000 devices!
    SetLength(MemoryDeviceList, devCount);
    SetLength(MemoryVendorList, venCount);
    venPos:=-1;
    devPos:=-1;
    //Open database file
    if dbFile<>'' then
      AssignFile(inFile, dbFile)
    else
      AssignFile(inFile, USBDeviceDatabaseFile);
    Reset(inFile);
    while not eof(inFile) do begin
      ReadLn(inFile, line);
      //Check if we reached the end of the device list
      if line.StartsWith('# List of known device classes') then break;

      //Skip any comments and empty lines
      if line.IsEmpty or line.StartsWith('#') then Continue;

      //Parse line. Format:
      // vendor  vendor_name
      //	device  device_name				<-- single tab
      //		interface  interface_name		<-- two tabs
      if line.StartsWith(#9#9) then begin
        //Add interface
        line:=Trim(line);
        part1:=Copy(line, 1, 4);
        part2:=Copy(line, 7, Length(line)-6);
        if not Word.TryParse('$'+part1, lastInterfaceID) then continue;
        with NextDev^ do begin
          vendorID:=lastVendorID;
          deviceID:=lastDeviceID;
          interfaceID:=lastInterfaceID;
          name:=part2;
        end;
      end
      else if line.StartsWith(#9) then begin
        //Add device
        line:=Trim(line);
        part1:=Copy(line, 1, 4);
        part2:=Copy(line, 7, Length(line)-6);
        if not Word.TryParse('$'+part1, lastDeviceID) then continue;
        with NextDev^ do begin
          vendorID:=lastVendorID;
          deviceID:=lastDeviceID;
          interfaceID:=0;
          name:=part2;
        end;
      end
      else begin
        //Add vendor
        line:=Trim(line);
        part1:=Copy(line, 1, 4);
        part2:=Copy(line, 7, Length(line)-6);
        if not Word.TryParse('$'+part1, lastVendorID) then continue;
        with NextVen^ do begin
          vendorID:=lastVendorID;
          name:=part2;
        end;
      end
    end;
    CloseFile(inFile);

    //Adjust sizes of the arrays
    SetLength(MemoryVendorList, MemoryVendorListSize);
    SetLength(MemoryDeviceList, MemoryDeviceListSize);

    result:=(MemoryVendorListSize > 0) and (MemoryDeviceListSize > 0);
  except
    DiscardMemoryDatabase;
  end;
end;


{Discard the loaded list from memory. Successive calls to any *FromMemory functions
will then fail except a table was compiled in using INCLUDE_USB_IDS}
procedure DiscardMemoryDatabase;
begin
  SetLength(MemoryDeviceList, 0);
  SetLength(MemoryVendorList, 0);
  MemoryDeviceListSize:=0;
  MemoryVendorListSize:=0;
end;

{Return a vendor name string in the configured database file (see USBDeviceDatabaseFile)}
function LookupVendorFromDatabase(venID:word):string;
var
  line, part1, part2:string;
  inFile: TextFile;
  lastVendorID:word;
begin
  result:='';
  try
    //Open database file
    AssignFile(inFile, USBDeviceDatabaseFile);
    Reset(inFile);
    while not eof(inFile) do begin
      ReadLn(inFile, line);
      //Check if we reached the end of the device list
      if line.StartsWith('# List of known device classes') then break;

      //Skip any comments and empty lines
      if line.IsEmpty or line.StartsWith('#') then Continue;

      //Parse line. Format:
      // vendor  vendor_name
      //	device  device_name				<-- single tab
      //		interface  interface_name		<-- two tabs
      if (not line.StartsWith(#9#9)) and (not line.StartsWith(#9)) then begin
        //In a vendor line
        line:=Trim(line);
        part1:=Copy(line, 1, 4);
        part2:=Copy(line, 7, Length(line)-6);
        if not Word.TryParse('$'+part1, lastVendorID) then continue;
        if lastVendorID = venID then begin
          result:=part2;
          break;
        end;
      end
    end;
    CloseFile(inFile);
  except
    DiscardMemoryDatabase;
  end;
end;

{Return a devide or interface from the database file. Usually, intID is set to -1
(the USB device list currently does not feature any USB interface names). This function
will walk through the (sorted) database file and thus can provide vendor, device and
interface name, if any, and not much additional cost.
If intID is -1, the function will look for Vendor and Device. If Device is also below zero,
it will stop if it has found the VendorID.}
function LookupDeviceFromDatabase(venID:integer; devID:integer; intID:integer;
  out venName, devName, intName: string; dbFile:string=''):boolean;
var
  line, part1, part2:string;
  inFile: TextFile;
  lastVendorID:word;
  lastDeviceID:word;
  lastInterfaceID:word;
  lastVendorName, lastDeviceName:string;
begin
  DiscardMemoryDatabase;
  result:=false;
  try
    //Prepare
    lastVendorID:=0;
    lastVendorName:='';
    lastDeviceID:=0;
    lastDeviceName:='';
    lastInterfaceID:=0;
    //Open database file
    if not dbFile.IsEmpty then
      AssignFile(inFile, dbFile)
    else
      AssignFile(inFile, USBDeviceDatabaseFile);
    Reset(inFile);
    while not eof(inFile) do begin
      ReadLn(inFile, line);
      //Check if we reached the end of the device list
      if line.StartsWith('# List of known device classes') then break;

      //Skip any comments and empty lines
      if line.IsEmpty or line.StartsWith('#') then Continue;

      //Parse line. Format:
      // vendor  vendor_name
      //	device  device_name				<-- single tab
      //		interface  interface_name		<-- two tabs
      if line.StartsWith(#9#9) and (intID<>0) then begin
        //In an interface line (not that I've seen any lately)
        line:=Trim(line);
        part1:=Copy(line, 1, 4);
        part2:=Copy(line, 7, Length(line)-6);
        if not Word.TryParse('$'+part1, lastInterfaceID) then continue;
        if (lastVendorID = venID) and (lastDeviceID = devID) and (lastInterfaceID = intID) then begin
          result:=true;
          venName:=lastVendorName;
          devName:=lastDeviceName;
          intName:=part2;
          break;
        end;
      end
      else if line.StartsWith(#9) then begin
        //A device line
        line:=Trim(line);
        part1:=Copy(line, 1, 4);
        part2:=Copy(line, 7, Length(line)-6);
        if not Word.TryParse('$'+part1, lastDeviceID) then continue;
        if devID = lastDeviceID then begin
          //found the device. If no interface is given, that's it!
          lastDeviceName:=part2;
          if intID < 0 then begin
            result:=true;
            venName:=lastVendorName;
            devName:=lastDeviceName;
            intName:='';
            break;
          end;
        end;
      end
      else begin
        //Vendor line.
        line:=Trim(line);
        part1:=Copy(line, 1, 4);
        part2:=Copy(line, 7, Length(line)-6);
        if not Word.TryParse('$'+part1, lastVendorID) then continue;
        if venID = lastVendorID then begin
          //Found the Vendor, if no device is requested than that's it!
          lastVendorName:=part2;
          if devID < 0 then begin
            result:=true;
            venName:=lastVendorName;
            devName:='';
            intName:='';
            break;
          end;
        end;
      end
    end;
    CloseFile(inFile);
  except
    DiscardMemoryDatabase;
  end;
end;

{Use any available method to get vendor name, device name or interface name for
the given IDs. Will search a memory list first, followed by a compiled-in table
and the database file of the OS (or user) last.
If intID is set below zero, the function will serach for vendor and device. If
venID is also below zero, it will ignore deviceID and interfaceID and only return
the vendor name.}
function LookupUSBNames(venID:integer; devID:integer; intID:integer;
  out venName, devName, intName: string;
  whereToSearch:TUSBDataDBSelection=[usbDataMemory, usbDataFile]):boolean;
begin
  //Only vendor requested? Easy...
  if (devID < 0) and (intID < 0) then begin
    venName:='';
    if (usbDataMemory in whereToSearch) and
       ((MemoryVendorListSize > 0) or CompileTimeUSBListExists) then
      venName:=LookupVendorFromMemory(venID);
    if (usbDataFile in whereToSearch) and venName.IsEmpty then
      venName:=LookupVendorFromDatabase(venID);
    result:=not venName.IsEmpty;
  end
  else begin
    venName:='';
    //Try memory first.
    if (usbDataMemory in whereToSearch) and
       ((MemoryVendorListSize > 0) or CompileTimeUSBListExists) then begin
      venName:=LookupVendorFromMemory(venID);
      if venName.IsEmpty then begin
        //As both databases (vendors and devices) are built from the same file,
        //searching for the device if the vendor was not found will most probably
        //not work. Thus, advance to the next option instead (don't even try to
        //load the rest from  memory)
        if (usbDataFile in whereToSearch) then
          result:=LookupDeviceFromDatabase(venID, devID, intID, venName, devName, intName)
        else
          result:=false;
      end
      else begin
        //Load rest
        devName:=LookupDeviceFromMemory(venID, devID, -1);
        if intID >= 0 then
          intName:=LookupDeviceFromMemory(venID, devID, intID)
        else
          intName:='';
        result:=(not devName.IsEmpty) and ((not intName.IsEmpty) or (intID < 0));
        //Still not found? try db again
        if not result and (usbDataFile in whereToSearch) then
          result:=LookupDeviceFromDatabase(venID, devID, intID, venName, devName, intName);
      end;
    end
    else if (usbDataFile in whereToSearch) then begin
      //Simply call the database function:
      result:=LookupDeviceFromDatabase(venID, devID, intID, venName, devName, intName);
    end;
  end;
end;       

{Set USBDeviceDatabaseFile to the system's default location of that file, if any.}
procedure SetDefaultUSBDatabaseLocation;
begin
  {$if defined(UNIX)}
  if FileExists('/usr/share/misc/usb.ids') then
    USBDeviceDatabaseFile:='/usr/share/misc/usb.ids'
  else if FileExists('/usr/share/hwdata/usb.ids') then
    USBDeviceDatabaseFile:='/usr/share/hwdata/usb.ids'
  else if FileExists('/var/lib/usbutils/usb.ids') then
    USBDeviceDatabaseFile:='/var/lib/usbutils/usb.ids'
  else
    USBDeviceDatabaseFile:='';
  {$else}
  USBDeviceDatabaseFile:='';
  {$endif}
end;

{Ensure that some database is available from memory. That is, if a table was
compiled in, the function will do nothing. If not, it will try to load the
database from USBDeviceDatabaseFile. If both is not possible, it will return
false.}
function EnsureMemoryDatabaseAvailable:boolean;
begin
  if CompileTimeUSBListExists or
    ((MemoryDeviceListSize > 0) and (MemoryVendorListSize > 0)) then result:=true
  else result:=LoadDatabaseToMemory;
end;

initialization
  SetDefaultUSBDatabaseLocation;
end.

