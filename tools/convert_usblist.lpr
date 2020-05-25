program convert_usblist;

uses SysUtils, Classes, Process, usb.IDlist;

{Download current version of usb.ids from http://www.linux-usb.org/usb.ids using
curl}
function DownloadUsbIds:boolean;
var
  AProcess: TProcess;
begin
  AProcess := TProcess.Create(nil);
  AProcess.Executable:= 'curl';
  AProcess.Parameters.Add('http://www.linux-usb.org/usb.ids');
  AProcess.Parameters.Add('--output');
  AProcess.Parameters.Add('/tmp/usb.ids');
  AProcess.Options := AProcess.Options + [poWaitOnExit, poStderrToOutPut];
  AProcess.Execute;
  result:=AProcess.ExitCode = 0;
  AProcess.Free;
end;

function EscapeStr(inStr:string):string;
begin
  result:=inStr.Replace('''','''''', [rfReplaceAll]);
end;

var
  outFile: TextFile;
  i:integer;
begin
  if DownloadUsbIds then begin
    LoadDatabaseToMemory('/tmp/usb.ids');
    DeleteFile('/tmp/usb.ids');

    //Write stuff
    AssignFile(outFile, 'usb.IDList.inc');
    ReWrite(outFile);
    Writeln(outFile, '//data converted on ', DateTimeToStr(Now), ' from http://www.linux-usb.org/usb.ids');
    Writeln(outfile);                  
    Writeln(outFile, 'const');
    Writeln(outFile, '  {Number of known USB vendors in USBVendorList}');
    Writeln(outFile, '  USBVendorCount = ',MemoryVendorListSize,';');
    Writeln(outFile);
    Writeln(outFile, '  {List of registered USB vendor IDs}');
    Writeln(outFile, '  USBVendorList:array [0..', MemoryVendorListSize-1, '] of TUSBVendorEntry = (');
    for i:=0 to MemoryVendorListSize-2 do           
      with  MemoryVendorList[i] do
      Writeln(outFile, Format('    (vendorID: $%0.4x; name: ''%s''),', [vendorID, EscapeStr(name)]));
    with MemoryVendorList[MemoryVendorListSize-1] do      
      Writeln(outFile, Format('    (vendorID: $%0.4x; name: ''%s'')', [vendorID, EscapeStr(name)]));
    Writeln(outFile, '  );');   
    Writeln(outFile);
    Writeln(outFile);
    Writeln(outFile, '  {Number of known USB interfaces and devices in USBDeviceNamesList}');
    Writeln(outFile, '  USBDeviceNamesCount = ',MemoryDeviceListSize,';');
    Writeln(outFile);
    Writeln(outFile, '  {List of registered USB interface, device and vendor IDs}');
    Writeln(outFile, '  USBDeviceNamesList:array [0..', MemoryDeviceListSize-1, '] of TUSBDeviceListEntry = (');
    for i:=0 to MemoryDeviceListSize-2 do     
      with MemoryDeviceList[i] do
        Writeln(outFile, Format('    (vendorID: $%0.4x; deviceID: $%0.4x; interfaceID: $%0.4x; name: ''%s''),',
          [vendorID, deviceID, interfaceID, EscapeStr(name)]));
    with  MemoryDeviceList[MemoryDeviceListSize-1] do
      Writeln(outFile, Format('    (vendorID: $%0.4x; deviceID: $%0.4x; interfaceID: $%0.4x; name: ''%s'')',
        [vendorID, deviceID, interfaceID, EscapeStr(name)]));
    Writeln(outFile, '  );');
    CloseFile(outFile);
  end;
end.

